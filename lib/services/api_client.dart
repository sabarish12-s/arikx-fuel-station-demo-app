import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../utils/user_facing_errors.dart';
import 'auth_service.dart';

class ApiClient {
  ApiClient(this._authService);

  final AuthService _authService;

  Future<Map<String, String>> authorizedHeaders() async {
    final String? token = await _authService.readJwtToken();
    return <String, String>{
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> get(String path) async {
    final Uri uri = Uri.parse('$backendBaseUrl$path');
    return http.get(uri, headers: await authorizedHeaders());
  }

  Future<http.Response> post(String path, {Object? body}) async {
    final Uri uri = Uri.parse('$backendBaseUrl$path');
    return http.post(uri, headers: await authorizedHeaders(), body: body);
  }

  Future<http.Response> patch(String path, {Object? body}) async {
    final Uri uri = Uri.parse('$backendBaseUrl$path');
    return http.patch(uri, headers: await authorizedHeaders(), body: body);
  }

  Future<http.Response> put(String path, {Object? body}) async {
    final Uri uri = Uri.parse('$backendBaseUrl$path');
    return http.put(uri, headers: await authorizedHeaders(), body: body);
  }

  Future<http.Response> delete(String path) async {
    final Uri uri = Uri.parse('$backendBaseUrl$path');
    return http.delete(uri, headers: await authorizedHeaders());
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
}
