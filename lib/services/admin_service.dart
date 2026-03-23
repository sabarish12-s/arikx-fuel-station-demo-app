import 'dart:convert';

import '../models/access_request.dart';
import 'api_client.dart';
import 'auth_service.dart';

class AdminService {
  AdminService() : _apiClient = ApiClient(AuthService());

  final ApiClient _apiClient;

  Future<List<AccessRequest>> fetchPendingRequests() async {
    final response = await _apiClient.get('/admin/requests');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load requests: ${response.body}');
    }
    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;
    final List<dynamic> data = json['requests'] as List<dynamic>? ?? [];
    return data
        .map((item) => AccessRequest.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> approveRequest(String requestId) async {
    final response = await _apiClient.post(
      '/admin/requests/$requestId/approve',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Approval failed: ${response.body}');
    }
  }
}
