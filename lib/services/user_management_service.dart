import 'dart:convert';

import '../models/access_request.dart';
import '../models/user_management_models.dart';
import 'api_client.dart';
import 'auth_service.dart';

class UserManagementService {
  UserManagementService() : _apiClient = ApiClient(AuthService());

  final ApiClient _apiClient;

  Future<UserManagementOverview> fetchOverview() async {
    final response = await _apiClient.get('/users/management');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load user management: ${response.body}');
    }
    return UserManagementOverview.fromJson(_apiClient.decodeObject(response));
  }

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

  Future<void> bulkApproveRequests(
    List<Map<String, String>> items,
  ) async {
    final response = await _apiClient.post(
      '/users/requests/bulk-approve',
      body: jsonEncode({'items': items}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to bulk approve requests: ${response.body}');
    }
  }

  Future<void> bulkDeleteRequests(List<String> requestIds) async {
    final response = await _apiClient.post(
      '/users/requests/bulk-delete',
      body: jsonEncode({'requestIds': requestIds}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to bulk delete requests: ${response.body}');
    }
  }

  Future<void> addStaff({
    required String email,
    required String name,
    required String role,
  }) async {
    final response = await _apiClient.post(
      '/users/staff',
      body: jsonEncode({
        'email': email,
        'name': name,
        'role': role,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to save staff member: ${response.body}');
    }
  }

  Future<void> updateStaffRole({
    required String userId,
    required String role,
  }) async {
    final response = await _apiClient.patch(
      '/users/staff/$userId',
      body: jsonEncode({'role': role}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to update staff role: ${response.body}');
    }
  }

  Future<void> deleteStaff(String userId) async {
    final response = await _apiClient.delete('/users/staff/$userId');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to delete staff member: ${response.body}');
    }
  }
}
