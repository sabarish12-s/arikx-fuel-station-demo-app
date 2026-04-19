import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../utils/user_facing_errors.dart';
import 'api_response_cache.dart';
import 'auth_service.dart';

enum ApiCachePolicy { cacheFirst, networkFirst }

class ApiClient {
  ApiClient(this._authService, {http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final AuthService _authService;
  final http.Client _httpClient;

  Future<Map<String, String>> authorizedHeaders() async {
    final String? token = await _authService.readJwtToken();
    return <String, String>{
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> get(
    String path, {
    bool useCache = false,
    bool forceRefresh = false,
    ApiCachePolicy cachePolicy = ApiCachePolicy.cacheFirst,
  }) async {
    final Uri uri = Uri.parse('$backendBaseUrl$path');
    final headers = await authorizedHeaders();
    final cacheKey =
        useCache
            ? await ApiResponseCache.scopedKey(
              authService: _authService,
              path: path,
            )
            : null;

    if (cacheKey != null &&
        !forceRefresh &&
        cachePolicy == ApiCachePolicy.cacheFirst) {
      final cached = await ApiResponseCache.read(cacheKey);
      if (cached != null) {
        unawaited(_refreshCachedGet(uri, path, headers, cacheKey));
        return http.Response(
          cached.body,
          cached.statusCode,
          headers: {...cached.headers, 'x-rk-cache': 'hit'},
        );
      }
    }

    late final http.Response response;
    try {
      response = await _httpClient.get(uri, headers: headers);
    } catch (_) {
      if (cacheKey != null &&
          !forceRefresh &&
          cachePolicy == ApiCachePolicy.networkFirst) {
        final cached = await ApiResponseCache.read(cacheKey);
        if (cached != null) {
          return http.Response(
            cached.body,
            cached.statusCode,
            headers: {...cached.headers, 'x-rk-cache': 'fallback'},
          );
        }
      }
      rethrow;
    }
    if (cacheKey != null && _isSuccess(response)) {
      await ApiResponseCache.write(
        key: cacheKey,
        path: path,
        statusCode: response.statusCode,
        body: response.body,
        headers: response.headers,
      );
    }
    return response;
  }

  Future<http.Response> post(String path, {Object? body}) async {
    final Uri uri = Uri.parse('$backendBaseUrl$path');
    final response = await _httpClient.post(
      uri,
      headers: await authorizedHeaders(),
      body: body,
    );
    await _clearCacheAfterMutation(response);
    return response;
  }

  Future<http.Response> patch(String path, {Object? body}) async {
    final Uri uri = Uri.parse('$backendBaseUrl$path');
    final response = await _httpClient.patch(
      uri,
      headers: await authorizedHeaders(),
      body: body,
    );
    await _clearCacheAfterMutation(response);
    return response;
  }

  Future<http.Response> put(String path, {Object? body}) async {
    final Uri uri = Uri.parse('$backendBaseUrl$path');
    final response = await _httpClient.put(
      uri,
      headers: await authorizedHeaders(),
      body: body,
    );
    await _clearCacheAfterMutation(response);
    return response;
  }

  Future<http.Response> delete(String path) async {
    final Uri uri = Uri.parse('$backendBaseUrl$path');
    final response = await _httpClient.delete(
      uri,
      headers: await authorizedHeaders(),
    );
    await _clearCacheAfterMutation(response);
    return response;
  }

  Map<String, dynamic> decodeObject(http.Response response) {
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  String errorMessage(http.Response response, {String? fallback}) {
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
      // Fall through to plain text cleanup below.
    }

    candidate ??= response.body.trim();
    if (candidate.isEmpty) {
      candidate =
          fallback ?? 'Request failed with status ${response.statusCode}.';
    }
    return userFacingErrorMessage(candidate);
  }

  bool _isSuccess(http.Response response) =>
      response.statusCode >= 200 && response.statusCode < 300;

  Future<void> _refreshCachedGet(
    Uri uri,
    String path,
    Map<String, String> headers,
    String cacheKey,
  ) async {
    try {
      final response = await _httpClient.get(uri, headers: headers);
      if (_isSuccess(response)) {
        await ApiResponseCache.write(
          key: cacheKey,
          path: path,
          statusCode: response.statusCode,
          body: response.body,
          headers: response.headers,
          background: true,
        );
      }
    } catch (_) {
      // Cached pages should not fail just because a silent refresh failed.
    }
  }

  Future<void> _clearCacheAfterMutation(http.Response response) async {
    if (_isSuccess(response)) {
      await ApiResponseCache.clearScoped(_authService);
    }
  }
}
