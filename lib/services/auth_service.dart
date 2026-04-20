import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/auth_models.dart';
import '../utils/user_facing_errors.dart';
import 'api_response_cache.dart';
import 'native_config_service.dart';
import 'notification_service.dart';

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

    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        (_resolvedServerClientId == null || _resolvedServerClientId!.isEmpty)) {
      throw Exception(
        'Google Sign-In is not configured in Firebase for Android. Add Google Sign-In, add the Android SHA1, and download a fresh google-services.json.',
      );
    }

    _googleSignIn = GoogleSignIn(
      clientId: _resolvedClientId,
      serverClientId: _resolvedServerClientId,
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

  String _extractBackendError(http.Response response) {
    String? candidate;
    try {
      final Object? decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final String message = decoded['message']?.toString().trim() ?? '';
        final String error = decoded['error']?.toString().trim() ?? '';

        if (message.isNotEmpty && error.isNotEmpty) {
          candidate = '$message: $error';
        } else if (message.isNotEmpty) {
          candidate = message;
        } else if (error.isNotEmpty) {
          candidate = error;
        }
      }
    } catch (_) {
      // Fall back to the raw response body below.
    }

    candidate ??= response.body.trim();
    if (candidate.isEmpty) {
      candidate = 'Authentication failed with status ${response.statusCode}.';
    }
    return userFacingErrorMessage(candidate);
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
    final GoogleSignInAccount? account = await freshGoogleSignIn.signIn();
    if (account == null) {
      throw Exception('Google Sign-In was cancelled.');
    }

    final GoogleSignInAuthentication authentication =
        await account.authentication;
    final String? idToken = authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw Exception(
        'Google ID token is empty. Check Firebase Google Sign-In OAuth setup.',
      );
    }

    final String? fcmToken = await NotificationService.instance.getFcmToken();

    final Map<String, dynamic> payload = {
      'idToken': idToken,
      'fcmToken': fcmToken,
    }..removeWhere((key, value) => value == null);

    final Uri uri = Uri.parse('$backendBaseUrl/auth/google');
    final http.Response response = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractBackendError(response));
    }

    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;
    final AuthResponse authResponse = AuthResponse.fromJson(json);
    await _persistAuth(authResponse);
    return authResponse;
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
    final String? token = await readJwtToken();
    if (token == null || token.isEmpty) {
      return null;
    }

    final Uri uri = Uri.parse('$backendBaseUrl/auth/me');
    final http.Response response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 401) {
      await signOut();
      return null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractBackendError(response));
    }

    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;
    final AuthUser user = AuthUser.fromJson(
      json['user'] as Map<String, dynamic>? ?? const {},
    );
    final SharedPreferences prefs = await _prefs();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
    return user;
  }
}
