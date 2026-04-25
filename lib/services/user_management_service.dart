import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/access_request.dart';
import '../models/user_management_models.dart';
import 'api_client.dart';
import 'auth_service.dart';

class UserManagementService {
  UserManagementService() : _apiClient = ApiClient(AuthService());

  final ApiClient _apiClient;

  bool get _usesAuthBackend => authBackendBaseUrl.trim().isNotEmpty;

  Future<UserManagementOverview> fetchOverview({
    bool forceRefresh = false,
  }) async {
    if (_usesAuthBackend) {
      final response = await _authBackendGet('/users/management');
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
    if (_usesAuthBackend) {
      final response = await _authBackendGet('/users/requests');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          _apiClient.errorMessage(
            response,
            fallback: 'Failed to load requests.',
          ),
        );
      }
      final json = _apiClient.decodeObject(response);
      return (json['requests'] as List<dynamic>? ?? const [])
          .map((item) => AccessRequest.fromJson(item as Map<String, dynamic>))
          .toList();
    }

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
    if (_usesAuthBackend) {
      await _ensureOk(
        await _authBackendPost(
          '/users/requests/$requestId/approve',
          body: jsonEncode({'role': role}),
        ),
        'Failed to approve request.',
      );
      return;
    }

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
    if (_usesAuthBackend) {
      await _ensureOk(
        await _authBackendPost(
          '/users/requests/$requestId/reject',
          body: jsonEncode({'reason': reason}),
        ),
        'Failed to reject request.',
      );
      return;
    }

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
    if (_usesAuthBackend) {
      await _ensureOk(
        await _authBackendPost(
          '/users/requests/bulk-approve',
          body: jsonEncode({'items': items}),
        ),
        'Failed to bulk approve requests.',
      );
      return;
    }

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
    if (_usesAuthBackend) {
      await _ensureOk(
        await _authBackendPost(
          '/users/requests/bulk-delete',
          body: jsonEncode({'requestIds': requestIds}),
        ),
        'Failed to bulk delete requests.',
      );
      return;
    }

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
    if (_usesAuthBackend) {
      await _ensureOk(
        await _authBackendPost(
          '/users/staff',
          body: jsonEncode({'email': email, 'name': name, 'role': role}),
        ),
        'Failed to save staff member.',
      );
      return;
    }

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
    if (_usesAuthBackend) {
      await _ensureOk(
        await _authBackendPatch(
          '/users/staff/$userId',
          body: jsonEncode({'role': role}),
        ),
        'Failed to update staff role.',
      );
      return;
    }

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
    if (_usesAuthBackend) {
      await _ensureOk(
        await _authBackendDelete('/users/staff/$userId'),
        'Failed to delete staff member.',
      );
      return;
    }

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

  Future<http.Response> _authBackendGet(String path) async {
    return http.get(
      Uri.parse('${authBackendBaseUrl.trim()}$path'),
      headers: await _apiClient.authorizedHeaders(),
    );
  }

  Future<http.Response> _authBackendPost(String path, {Object? body}) async {
    return http.post(
      Uri.parse('${authBackendBaseUrl.trim()}$path'),
      headers: await _apiClient.authorizedHeaders(),
      body: body,
    );
  }

  Future<http.Response> _authBackendPatch(String path, {Object? body}) async {
    return http.patch(
      Uri.parse('${authBackendBaseUrl.trim()}$path'),
      headers: await _apiClient.authorizedHeaders(),
      body: body,
    );
  }

  Future<http.Response> _authBackendDelete(String path) async {
    return http.delete(
      Uri.parse('${authBackendBaseUrl.trim()}$path'),
      headers: await _apiClient.authorizedHeaders(),
    );
  }

  Future<void> _ensureOk(http.Response response, String fallback) async {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_apiClient.errorMessage(response, fallback: fallback));
    }
  }
}
