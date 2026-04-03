import 'dart:convert';

import '../models/domain_models.dart';
import 'api_client.dart';
import 'auth_service.dart';

class SalesService {
  SalesService() : _apiClient = ApiClient(AuthService());

  final ApiClient _apiClient;

  Future<SalesDashboardModel> fetchDashboard() async {
    final response = await _apiClient.get('/sales/dashboard');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load sales dashboard: ${response.body}');
    }
    return SalesDashboardModel.fromJson(_apiClient.decodeObject(response));
  }

  Future<List<ShiftEntryModel>> fetchEntries({String? month}) async {
    final String suffix = month == null ? '' : '?month=$month';
    final response = await _apiClient.get('/sales/entries$suffix');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load entries: ${response.body}');
    }
    final json = _apiClient.decodeObject(response);
    return (json['entries'] as List<dynamic>? ?? const [])
        .map((item) => ShiftEntryModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<DailySummaryModel> fetchDailySummary({String? date}) async {
    final String suffix = date == null ? '' : '?date=$date';
    final response = await _apiClient.get('/sales/summary/daily$suffix');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load daily summary: ${response.body}');
    }
    return DailySummaryModel.fromJson(_apiClient.decodeObject(response));
  }

  Future<ShiftEntryModel> submitEntry({
    required String date,
    required String shift,
    required Map<String, PumpReadings> closingReadings,
  }) async {
    final response = await _apiClient.post(
      '/sales/entries',
      body: jsonEncode({
        'date': date,
        'shift': shift,
        'closingReadings': closingReadings.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to submit entry: ${response.body}');
    }
    final json = _apiClient.decodeObject(response);
    return ShiftEntryModel.fromJson(json['entry'] as Map<String, dynamic>);
  }
}
