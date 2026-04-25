import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/auth_models.dart';
import 'api_response_cache.dart';
import 'native_config_service.dart';

class AuthService {
  static const String _jwtKey = 'jwt_token';
  static const String _userKey = 'auth_user';

  static GoogleSignIn? _googleSignIn;
  static String? _resolvedServerClientId;
  static String? _resolvedClientId;

  static bool get isGoogleSignInSupported {
    if (kIsWeb) {
      return true;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => true,
      TargetPlatform.iOS => true,
      TargetPlatform.macOS => true,
      _ => false,
    };
  }

  Future<SharedPreferences> _prefs() {
    return SharedPreferences.getInstance();
  }

  Future<GoogleSignIn> _getGoogleSignIn() async {
    if (_googleSignIn != null) {
      return _googleSignIn!;
    }

    _resolvedServerClientId = googleWebClientId.isNotEmpty
        ? googleWebClientId
        : await NativeConfigService.defaultWebClientId();
    _resolvedClientId = kIsWeb
        ? (_resolvedServerClientId?.isNotEmpty ?? false)
              ? _resolvedServerClientId
              : null
        : (googleClientId.isEmpty ? null : googleClientId);

    _googleSignIn = GoogleSignIn(
      clientId: _resolvedClientId,
      serverClientId: _resolvedServerClientId,
      scopes: const ['email', 'profile'],
    );
    return _googleSignIn!;
  }

  Future<void> _persistAuth(AuthResponse authResponse) async {
    if (authResponse.token.isEmpty) {
      throw Exception('JWT token missing in backend response.');
    }
    final SharedPreferences prefs = await _prefs();
    await prefs.setString(_jwtKey, authResponse.token);
    await prefs.setString(_userKey, jsonEncode(authResponse.user.toJson()));
  }

  Future<void> _clearGoogleSession({bool revoke = false}) async {
    final GoogleSignIn? googleSignIn = _googleSignIn;
    if (googleSignIn == null) {
      return;
    }

    if (revoke) {
      try {
        await googleSignIn.disconnect();
      } catch (_) {
        // Ignore disconnect failures and still try signOut below.
      }
    }

    try {
      await googleSignIn.signOut();
    } catch (_) {
      if (kDebugMode) {
        print('Google sign out ignored.');
      }
    }

    _googleSignIn = null;
  }

  Future<AuthResponse> signInWithGoogle() async {
    if (!isGoogleSignInSupported) {
      throw Exception(
        'Google Sign-In is not available on Windows desktop in this app. Use the web version in Chrome or Edge.',
      );
    }

    await _getGoogleSignIn();
    await _clearGoogleSession();
    final GoogleSignIn freshGoogleSignIn = await _getGoogleSignIn();
    final GoogleSignInAccount? account;
    try {
      account = await freshGoogleSignIn.signIn();
    } catch (error) {
      if (authBackendBaseUrl.trim().isEmpty) {
        rethrow;
      }
      final AuthResponse authResponse = await _signInWithDeviceGoogleAccount(
        cause: error,
      );
      await _persistAuth(authResponse);
      return authResponse;
    }
    if (account == null) {
      throw Exception('Google Sign-In was cancelled.');
    }

    final GoogleSignInAuthentication authentication =
        await account.authentication;
    final String? idToken = authentication.idToken;
    final String? accessToken = authentication.accessToken;
    if ((idToken == null || idToken.isEmpty) &&
        (accessToken == null || accessToken.isEmpty)) {
      throw Exception(
        'Google credentials are empty. Check Firebase Google Sign-In setup.',
      );
    }

    UserCredential? firebaseCredential;
    FirebaseAuthException? firebaseAuthError;
    try {
      final credential = GoogleAuthProvider.credential(
        idToken: idToken?.isNotEmpty == true ? idToken : null,
        accessToken: accessToken?.isNotEmpty == true ? accessToken : null,
      );
      firebaseCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
    } on FirebaseAuthException catch (error) {
      firebaseAuthError = error;
    }

    final User? firebaseUser = firebaseCredential?.user;
    if (firebaseUser == null && authBackendBaseUrl.trim().isEmpty) {
      Error.throwWithStackTrace(
        firebaseAuthError ??
            Exception('Firebase did not return a signed-in Google user.'),
        StackTrace.current,
      );
    }

    if (firebaseUser == null) {
      late AuthResponse authResponse;
      try {
        authResponse = await _signInWithApprovedGoogleUser(
          idToken: idToken,
          accessToken: accessToken,
          account: account,
        );
      } catch (error) {
        authResponse = await _signInWithDeviceGoogleAccount(
          email: account.email,
          name: account.displayName,
          cause: error,
        );
      }
      await _persistAuth(authResponse);
      return authResponse;
    }

    final String token = await firebaseUser.getIdToken(true) ?? '';
    if (token.isEmpty) {
      throw Exception('Firebase ID token missing after Google sign-in.');
    }

    final AuthUser user = authBackendBaseUrl.trim().isEmpty
        ? _localDemoUser(
            id: firebaseUser.uid,
            name: firebaseUser.displayName ?? account.displayName ?? '',
            email: firebaseUser.email ?? account.email,
          )
        : await _fetchApprovedUser(token);
    final AuthResponse authResponse = AuthResponse(user: user, token: token);
    await _persistAuth(authResponse);
    return authResponse;
  }

  Future<AuthResponse> _signInWithDeviceGoogleAccount({
    String? email,
    String? name,
    Object? cause,
  }) async {
    final selectedEmail = email?.trim().isNotEmpty == true
        ? email!.trim()
        : await NativeConfigService.pickGoogleAccountEmail();
    if (selectedEmail == null || selectedEmail.trim().isEmpty) {
      throw Exception(
        cause == null
            ? 'No Google account was selected.'
            : 'Google Sign-In could not open the native account picker.',
      );
    }

    final Uri uri = Uri.parse(
      '${authBackendBaseUrl.trim()}/auth/device-account',
    );
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (deviceAccountAuthKey.trim().isNotEmpty)
          'X-Arikx-Demo-Auth': deviceAccountAuthKey.trim(),
      },
      body: jsonEncode({
        'email': selectedEmail.trim(),
        'name': name?.trim().isNotEmpty == true
            ? name!.trim()
            : selectedEmail.split('@').first,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _authBackendError(response, 'Device Google account approval failed.'),
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final String customToken = json['customToken']?.toString() ?? '';
    if (customToken.isEmpty) {
      throw Exception('Approval service did not return a Firebase token.');
    }
    final credential = await FirebaseAuth.instance.signInWithCustomToken(
      customToken,
    );
    final User? firebaseUser = credential.user;
    final String firebaseIdToken = await firebaseUser?.getIdToken(true) ?? '';
    if (firebaseIdToken.isEmpty) {
      throw Exception('Firebase ID token missing after approved sign-in.');
    }
    final AuthUser user = AuthUser.fromJson(
      json['user'] as Map<String, dynamic>? ?? const {},
    );
    return AuthResponse(user: user, token: firebaseIdToken);
  }

  Future<AuthResponse> _signInWithApprovedGoogleUser({
    required String? idToken,
    required String? accessToken,
    required GoogleSignInAccount account,
  }) async {
    final Uri uri = Uri.parse('${authBackendBaseUrl.trim()}/auth/google');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'idToken': idToken,
        'accessToken': accessToken,
        'googleUserId': account.id,
        'email': account.email,
        'name': account.displayName,
        'photoUrl': account.photoUrl,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_authBackendError(response, 'Access approval failed.'));
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final String customToken = json['customToken']?.toString() ?? '';
    if (customToken.isEmpty) {
      throw Exception('Approval service did not return a Firebase token.');
    }
    final credential = await FirebaseAuth.instance.signInWithCustomToken(
      customToken,
    );
    final User? firebaseUser = credential.user;
    final String firebaseIdToken = await firebaseUser?.getIdToken(true) ?? '';
    if (firebaseIdToken.isEmpty) {
      throw Exception('Firebase ID token missing after approved sign-in.');
    }
    final AuthUser user = AuthUser.fromJson(
      json['user'] as Map<String, dynamic>? ?? const {},
    );
    return AuthResponse(user: user, token: firebaseIdToken);
  }

  Future<AuthUser> _fetchApprovedUser(String token) async {
    final Uri uri = Uri.parse('${authBackendBaseUrl.trim()}/auth/me');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _authBackendError(response, 'Access approval check failed.'),
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return AuthUser.fromJson(json['user'] as Map<String, dynamic>? ?? const {});
  }

  String _authBackendError(http.Response response, String fallback) {
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return decoded['message']?.toString() ?? fallback;
    } catch (_) {
      return response.body.trim().isEmpty ? fallback : response.body.trim();
    }
  }

  AuthUser _localDemoUser({
    required String id,
    required String name,
    required String email,
  }) {
    final normalizedEmail = email.trim().toLowerCase();
    final isSuperadmin = normalizedEmail == 'sabarish9911@gmail.com';
    return AuthUser(
      id: id.isEmpty ? 'demo-user' : id,
      name: name.trim().isEmpty ? 'Station User' : name.trim(),
      email: email.trim().isEmpty ? 'station.user@fuelstation.local' : email,
      role: isSuperadmin ? 'superadmin' : 'sales',
      status: isSuperadmin ? 'approved' : 'pending',
      stationId: 'station-demo-01',
    );
  }

  Future<bool> hasJwtToken() async {
    final SharedPreferences prefs = await _prefs();
    final String? token = prefs.getString(_jwtKey);
    return token != null && token.isNotEmpty;
  }

  Future<String?> readJwtToken() async {
    final SharedPreferences prefs = await _prefs();
    return prefs.getString(_jwtKey);
  }

  Future<void> signOut() async {
    await ApiResponseCache.clearAll();
    final SharedPreferences prefs = await _prefs();
    await prefs.remove(_jwtKey);
    await prefs.remove(_userKey);
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      // Unit tests and desktop previews may not initialize Firebase Auth.
    }
    await _clearGoogleSession(revoke: true);
  }

  Future<AuthUser?> readCurrentUser() async {
    final SharedPreferences prefs = await _prefs();
    final String? raw = prefs.getString(_userKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
      return AuthUser.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<AuthUser?> refreshCurrentUser() async {
    final bool hasToken = await hasJwtToken();
    if (!hasToken) {
      return null;
    }

    final AuthUser? cachedUser = await readCurrentUser();
    final User? firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      return cachedUser;
    }

    final SharedPreferences prefs = await _prefs();
    final String token = await firebaseUser.getIdToken(true) ?? '';
    final AuthUser user = authBackendBaseUrl.trim().isEmpty || token.isEmpty
        ? _localDemoUser(
            id: firebaseUser.uid,
            name: firebaseUser.displayName ?? cachedUser?.name ?? '',
            email: firebaseUser.email ?? cachedUser?.email ?? '',
          )
        : await _fetchApprovedUser(token);
    if (token.isNotEmpty) {
      await prefs.setString(_jwtKey, token);
    }
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
    return user;
  }
}
