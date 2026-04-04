import 'dart:convert';

import '../models/domain_models.dart';
import 'api_client.dart';
import 'auth_service.dart';

class ManagementService {
  ManagementService() : _apiClient = ApiClient(AuthService());

  final ApiClient _apiClient;

  Future<ManagementDashboardModel> fetchDashboard() async {
    final response = await _apiClient.get('/management/dashboard');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load dashboard: ${response.body}');
    }
    return ManagementDashboardModel.fromJson(_apiClient.decodeObject(response));
  }

  Future<List<ShiftEntryModel>> fetchEntries({
    String? month,
    bool approvedOnly = false,
  }) async {
    final params = <String, String>{};
    if (month != null && month.isNotEmpty) {
      params['month'] = month;
    }
    if (approvedOnly) {
      params['approvedOnly'] = 'true';
    }
    final String suffix =
        params.isEmpty ? '' : '?${Uri(queryParameters: params).query}';
    final response = await _apiClient.get('/management/entries$suffix');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load management entries: ${response.body}');
    }
    final json = _apiClient.decodeObject(response);
    return (json['entries'] as List<dynamic>? ?? const [])
        .map((item) => ShiftEntryModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ShiftEntryModel> updateEntry({
    required String entryId,
    required Map<String, PumpReadings> closingReadings,
    required Map<String, String> pumpAttendants,
    required Map<String, bool> pumpTesting,
    required Map<String, PumpPaymentBreakdownModel> pumpPayments,
    required Map<String, double> pumpCollections,
    required PaymentBreakdownModel paymentBreakdown,
    required List<CreditEntryModel> creditEntries,
    String mismatchReason = '',
  }) async {
    final response = await _apiClient.patch(
      '/management/entries/$entryId',
      body: jsonEncode({
        'closingReadings': closingReadings.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
        'pumpAttendants': pumpAttendants,
        'pumpTesting': pumpTesting,
        'pumpPayments': pumpPayments.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
        'pumpCollections': pumpCollections,
        'paymentBreakdown': paymentBreakdown.toJson(),
        'creditEntries': creditEntries.map((entry) => entry.toJson()).toList(),
        'mismatchReason': mismatchReason,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to update entry: ${response.body}');
    }
    final json = _apiClient.decodeObject(response);
    return ShiftEntryModel.fromJson(json['entry'] as Map<String, dynamic>);
  }

  Future<ShiftEntryModel> approveEntry(String entryId) async {
    final response = await _apiClient.post(
      '/management/entries/$entryId/approve',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to approve entry: ${response.body}');
    }
    final json = _apiClient.decodeObject(response);
    return ShiftEntryModel.fromJson(json['entry'] as Map<String, dynamic>);
  }

  Future<MonthlyReportModel> fetchMonthlyReport({
    String? month,
    String? fromDate,
    String? toDate,
  }) async {
    final params = <String, String>{};
    if (month != null && month.isNotEmpty) {
      params['month'] = month;
    }
    if (fromDate != null && fromDate.isNotEmpty) {
      params['from'] = fromDate;
    }
    if (toDate != null && toDate.isNotEmpty) {
      params['to'] = toDate;
    }
    final String suffix =
        params.isEmpty ? '' : '?${Uri(queryParameters: params).query}';
    final response = await _apiClient.get('/management/reports/monthly$suffix');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load monthly report: ${response.body}');
    }
    return MonthlyReportModel.fromJson(_apiClient.decodeObject(response));
  }
}
