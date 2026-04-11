import 'dart:convert';

import '../models/access_request.dart';
import '../models/user_management_models.dart';
import 'api_client.dart';
import 'auth_service.dart';

class UserManagementService {
  UserManagementService() : _apiClient = ApiClient(AuthService());

  final ApiClient _apiClient;

  Future<UserManagementOverview> fetchOverview({
    bool forceRefresh = false,
  }) async {
    final response = await _apiClient.get(
      '/users/management',
      useCache: true,
      forceRefresh: forceRefresh,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(
          response,
          fallback: 'Failed to load user management.',
        ),
      );
    }
    return UserManagementOverview.fromJson(_apiClient.decodeObject(response));
  }

  Future<List<AccessRequest>> fetchRequests({bool forceRefresh = false}) async {
    final response = await _apiClient.get(
      '/users/requests',
      useCache: true,
      forceRefresh: forceRefresh,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(response, fallback: 'Failed to load requests.'),
      );
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
      throw Exception(
        _apiClient.errorMessage(
          response,
          fallback: 'Failed to approve request.',
        ),
      );
    }
  }

  Future<void> rejectRequest(String requestId, {String reason = ''}) async {
    final response = await _apiClient.post(
      '/users/requests/$requestId/reject',
      body: jsonEncode({'reason': reason}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(
          response,
          fallback: 'Failed to reject request.',
        ),
      );
    }
  }

  Future<void> bulkApproveRequests(List<Map<String, String>> items) async {
    final response = await _apiClient.post(
      '/users/requests/bulk-approve',
      body: jsonEncode({'items': items}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(
          response,
          fallback: 'Failed to bulk approve requests.',
        ),
      );
    }
  }

  Future<void> bulkDeleteRequests(List<String> requestIds) async {
    final response = await _apiClient.post(
      '/users/requests/bulk-delete',
      body: jsonEncode({'requestIds': requestIds}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(
          response,
          fallback: 'Failed to bulk delete requests.',
        ),
      );
    }
  }

  Future<void> addStaff({
    required String email,
    required String name,
    required String role,
  }) async {
    final response = await _apiClient.post(
      '/users/staff',
      body: jsonEncode({'email': email, 'name': name, 'role': role}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(
          response,
          fallback: 'Failed to save staff member.',
        ),
      );
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
      throw Exception(
        _apiClient.errorMessage(
          response,
          fallback: 'Failed to update staff role.',
        ),
      );
    }
  }

  Future<void> deleteStaff(String userId) async {
    final response = await _apiClient.delete('/users/staff/$userId');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(
          response,
          fallback: 'Failed to delete staff member.',
        ),
      );
    }
  }
}
