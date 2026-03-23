import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/auth_models.dart';
import 'notification_service.dart';

class AuthService {
  static const String _jwtKey = 'jwt_token';
  static const String _userKey = 'auth_user';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static bool _googleInitialized = false;

  Future<void> _initializeGoogle() async {
    if (_googleInitialized) {
      return;
    }
    await _googleSignIn.initialize(
      clientId: googleClientId.isEmpty ? null : googleClientId,
      serverClientId: googleWebClientId.isEmpty ? null : googleWebClientId,
    );
    _googleInitialized = true;
  }

  Future<AuthResponse> signInWithGoogle() async {
    await _initializeGoogle();
    final GoogleSignInAccount account = await _googleSignIn.authenticate();
    final String? idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw Exception(
        'Google ID token is empty. Check GOOGLE_WEB_CLIENT_ID setup.',
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
      throw Exception('Auth failed: ${response.statusCode} ${response.body}');
    }

    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;
    final AuthResponse authResponse = AuthResponse.fromJson(json);

    if (authResponse.token.isEmpty) {
      throw Exception('JWT token missing in backend response.');
    }
    await _storage.write(key: _jwtKey, value: authResponse.token);
    await _storage.write(
      key: _userKey,
      value: jsonEncode(authResponse.user.toJson()),
    );
    return authResponse;
  }

  Future<bool> hasJwtToken() async {
    final String? token = await _storage.read(key: _jwtKey);
    return token != null && token.isNotEmpty;
  }

  Future<String?> readJwtToken() async {
    return _storage.read(key: _jwtKey);
  }

  Future<void> signOut() async {
    await _storage.delete(key: _jwtKey);
    await _storage.delete(key: _userKey);
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      if (kDebugMode) {
        print('Google sign out ignored.');
      }
    }
  }

  Future<AuthUser?> readCurrentUser() async {
    final String? raw = await _storage.read(key: _userKey);
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
}
