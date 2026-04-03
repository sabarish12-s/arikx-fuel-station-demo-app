import 'dart:convert';

import '../models/access_request.dart';
import 'api_client.dart';
import 'auth_service.dart';

class UserManagementService {
  UserManagementService() : _apiClient = ApiClient(AuthService());

  final ApiClient _apiClient;

  Future<List<AccessRequest>> fetchRequests() async {
    final response = await _apiClient.get('/users/requests');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load requests: ${response.body}');
    }
    final json = _apiClient.decodeObject(response);
    return (json['requests'] as List<dynamic>? ?? const [])
        .map((item) => AccessRequest.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> approveRequest(String requestId, String role) async {
    final response = await _apiClient.post(
      '/users/requests/$requestId/approve',
      body: jsonEncode({'role': role}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to approve request: ${response.body}');
    }
  }

  Future<void> rejectRequest(String requestId, {String reason = ''}) async {
    final response = await _apiClient.post(
      '/users/requests/$requestId/reject',
      body: jsonEncode({'reason': reason}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to reject request: ${response.body}');
    }
  }
}
