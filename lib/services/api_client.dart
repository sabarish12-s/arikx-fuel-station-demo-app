import 'package:http/http.dart' as http;

import '../config/app_config.dart';
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
}
