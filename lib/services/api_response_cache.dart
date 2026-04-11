import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import 'auth_service.dart';

class CachedApiResponse {
  const CachedApiResponse({
    required this.statusCode,
    required this.body,
    required this.headers,
    required this.cachedAt,
  });

  final int statusCode;
  final String body;
  final Map<String, String> headers;
  final DateTime cachedAt;
}

class ApiResponseCacheUpdate {
  const ApiResponseCacheUpdate({
    required this.key,
    required this.path,
    required this.background,
  });

  final String key;
  final String path;
  final bool background;
}

class ApiResponseCache {
  ApiResponseCache._();

  static const Duration ttl = Duration(hours: 24);
  static const String _prefix = 'api_response_cache_v1::';
  static final StreamController<ApiResponseCacheUpdate> _updates =
      StreamController<ApiResponseCacheUpdate>.broadcast();

  static Stream<ApiResponseCacheUpdate> get updates => _updates.stream;

  static Future<String?> scopedKey({
    required AuthService authService,
    required String path,
  }) async {
    final user = await authService.readCurrentUser();
    if (user == null || user.id.trim().isEmpty) {
      return null;
    }
    return '$_prefix$backendBaseUrl::${user.id}::${user.stationId}::$path';
  }

  static Future<CachedApiResponse?> read(String key, {DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final cachedAtMs = json['cachedAtMs'] as int? ?? 0;
      final cachedAt = DateTime.fromMillisecondsSinceEpoch(cachedAtMs);
      if ((now ?? DateTime.now()).difference(cachedAt) > ttl) {
        await prefs.remove(key);
        return null;
      }
      final headersJson = json['headers'] as Map<String, dynamic>? ?? const {};
      return CachedApiResponse(
        statusCode: json['statusCode'] as int? ?? 200,
        body: json['body']?.toString() ?? '',
        headers: headersJson.map(
          (key, value) => MapEntry(key, value?.toString() ?? ''),
        ),
        cachedAt: cachedAt,
      );
    } catch (_) {
      await prefs.remove(key);
      return null;
    }
  }

  static Future<void> write({
    required String key,
    required String path,
    required int statusCode,
    required String body,
    required Map<String, String> headers,
    bool background = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getString(key);
    final payload = jsonEncode({
      'statusCode': statusCode,
      'body': body,
      'headers': headers,
      'cachedAtMs': DateTime.now().millisecondsSinceEpoch,
    });
    await prefs.setString(key, payload);
    if (background && previous != null) {
      try {
        final previousJson = jsonDecode(previous) as Map<String, dynamic>;
        if (previousJson['body'] != body ||
            previousJson['statusCode'] != statusCode) {
          _updates.add(
            ApiResponseCacheUpdate(
              key: key,
              path: path,
              background: background,
            ),
          );
        }
      } catch (_) {
        _updates.add(
          ApiResponseCacheUpdate(key: key, path: path, background: background),
        );
      }
    }
  }

  static Future<void> clearScoped(AuthService authService) async {
    final user = await authService.readCurrentUser();
    if (user == null || user.id.trim().isEmpty) {
      return clearAll();
    }
    final scopedPrefix =
        '$_prefix$backendBaseUrl::${user.id}::${user.stationId}::';
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith(scopedPrefix));
    await Future.wait(keys.map(prefs.remove));
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith(_prefix));
    await Future.wait(keys.map(prefs.remove));
  }
}
