import 'dart:convert';

import '../models/domain_models.dart';
import 'api_client.dart';
import 'auth_service.dart';

class SalesService {
  SalesService() : _apiClient = ApiClient(AuthService());

  final ApiClient _apiClient;

  Future<SalesDashboardModel> fetchDashboard({
    bool forceRefresh = false,
  }) async {
    return fetchDashboardForDate(forceRefresh: forceRefresh);
  }

  Future<SalesDashboardModel> fetchDashboardForDate({
    String? date,
    bool forceRefresh = false,
  }) async {
    final String suffix = date == null ? '' : '?date=$date';
    final response = await _apiClient.get(
      '/sales/dashboard$suffix',
      useCache: true,
      forceRefresh: forceRefresh,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(
          response,
          fallback: 'Failed to load sales dashboard.',
        ),
      );
    }
    return SalesDashboardModel.fromJson(_apiClient.decodeObject(response));
  }

  Future<List<ShiftEntryModel>> fetchEntries({
    String? month,
    String? fromDate,
    String? toDate,
    bool summary = false,
    bool forceRefresh = false,
  }) async {
    final params = <String, String>{
      if (month != null && month.isNotEmpty) 'month': month,
      if (fromDate != null && fromDate.isNotEmpty) 'from': fromDate,
      if (toDate != null && toDate.isNotEmpty) 'to': toDate,
      if (summary) 'view': 'summary',
    };
    final String suffix =
        params.isEmpty ? '' : '?${Uri(queryParameters: params).query}';
    final response = await _apiClient.get(
      '/sales/entries$suffix',
      useCache: true,
      forceRefresh: forceRefresh,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(response, fallback: 'Failed to load entries.'),
      );
    }
    final json = _apiClient.decodeObject(response);
    return (json['entries'] as List<dynamic>? ?? const [])
        .map((item) => ShiftEntryModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<DailySummaryModel> fetchDailySummary({
    String? date,
    bool forceRefresh = false,
  }) async {
    final String suffix = date == null ? '' : '?date=$date';
    final response = await _apiClient.get(
      '/sales/summary/daily$suffix',
      useCache: true,
      forceRefresh: forceRefresh,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(
          response,
          fallback: 'Failed to load daily summary.',
        ),
      );
    }
    return DailySummaryModel.fromJson(_apiClient.decodeObject(response));
  }

  Future<ShiftEntryModel> submitEntry({
    required String date,
    required Map<String, PumpReadings> closingReadings,
    required Map<String, String> pumpAttendants,
    required Map<String, PumpTestingModel> pumpTesting,
    required Map<String, PumpPaymentBreakdownModel> pumpPayments,
    required Map<String, double> pumpCollections,
    required PaymentBreakdownModel paymentBreakdown,
    required List<CreditEntryModel> creditEntries,
    required List<CreditCollectionModel> creditCollections,
    String mismatchReason = '',
  }) async {
    final response = await _apiClient.post(
      '/sales/entries',
      body: jsonEncode({
        'date': date,
        'closingReadings': closingReadings.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
        'pumpAttendants': pumpAttendants,
        'pumpTesting': pumpTesting.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
        'pumpPayments': pumpPayments.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
        'pumpCollections': pumpCollections,
        'paymentBreakdown': paymentBreakdown.toJson(),
        'creditEntries': creditEntries.map((entry) => entry.toJson()).toList(),
        'creditCollections':
            creditCollections.map((entry) => entry.toJson()).toList(),
        'mismatchReason': mismatchReason,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(response, fallback: 'Failed to submit entry.'),
      );
    }
    final json = _apiClient.decodeObject(response);
    return ShiftEntryModel.fromJson(json['entry'] as Map<String, dynamic>);
  }

  Future<ShiftEntryModel> updateEntry({
    required String entryId,
    required String date,
    required Map<String, PumpReadings> closingReadings,
    required Map<String, String> pumpAttendants,
    required Map<String, PumpTestingModel> pumpTesting,
    required Map<String, PumpPaymentBreakdownModel> pumpPayments,
    required Map<String, double> pumpCollections,
    required PaymentBreakdownModel paymentBreakdown,
    required List<CreditEntryModel> creditEntries,
    required List<CreditCollectionModel> creditCollections,
    String mismatchReason = '',
  }) async {
    final response = await _apiClient.patch(
      '/sales/entries/$entryId',
      body: jsonEncode({
        'date': date,
        'closingReadings': closingReadings.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
        'pumpAttendants': pumpAttendants,
        'pumpTesting': pumpTesting.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
        'pumpPayments': pumpPayments.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
        'pumpCollections': pumpCollections,
        'paymentBreakdown': paymentBreakdown.toJson(),
        'creditEntries': creditEntries.map((entry) => entry.toJson()).toList(),
        'creditCollections':
            creditCollections.map((entry) => entry.toJson()).toList(),
        'mismatchReason': mismatchReason,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(response, fallback: 'Failed to update entry.'),
      );
    }
    final json = _apiClient.decodeObject(response);
    return ShiftEntryModel.fromJson(json['entry'] as Map<String, dynamic>);
  }

  Future<ShiftEntryModel> previewEntry({
    required String date,
    required Map<String, PumpReadings> closingReadings,
    required Map<String, String> pumpAttendants,
    required Map<String, PumpTestingModel> pumpTesting,
    required Map<String, PumpPaymentBreakdownModel> pumpPayments,
    required Map<String, double> pumpCollections,
    required PaymentBreakdownModel paymentBreakdown,
    required List<CreditEntryModel> creditEntries,
    required List<CreditCollectionModel> creditCollections,
    String mismatchReason = '',
  }) async {
    final response = await _apiClient.post(
      '/sales/entries/preview',
      body: jsonEncode({
        'date': date,
        'closingReadings': closingReadings.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
        'pumpAttendants': pumpAttendants,
        'pumpTesting': pumpTesting.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
        'pumpPayments': pumpPayments.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
        'pumpCollections': pumpCollections,
        'paymentBreakdown': paymentBreakdown.toJson(),
        'creditEntries': creditEntries.map((entry) => entry.toJson()).toList(),
        'creditCollections':
            creditCollections.map((entry) => entry.toJson()).toList(),
        'mismatchReason': mismatchReason,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(response, fallback: 'Failed to preview entry.'),
      );
    }
    final json = _apiClient.decodeObject(response);
    return ShiftEntryModel.fromJson(json['entry'] as Map<String, dynamic>);
  }
}
