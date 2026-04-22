import 'dart:convert';

import '../models/domain_models.dart';
import 'api_client.dart';
import 'auth_service.dart';

class ManagementService {
  ManagementService() : _apiClient = ApiClient(AuthService());

  final ApiClient _apiClient;

  String _entryPath(String entryId, [String suffix = '']) {
    return '/management/entries/${Uri.encodeComponent(entryId)}$suffix';
  }

  Future<ManagementDashboardModel> fetchDashboard({
    String? preset,
    String? fromDate,
    String? toDate,
    bool forceRefresh = false,
  }) async {
    final params = <String, String>{};
    if (preset != null && preset.isNotEmpty) {
      params['preset'] = preset;
    }
    if (fromDate != null && fromDate.isNotEmpty) {
      params['from'] = fromDate;
    }
    if (toDate != null && toDate.isNotEmpty) {
      params['to'] = toDate;
    }
    final suffix = params.isEmpty
        ? ''
        : '?${Uri(queryParameters: params).query}';
    final response = await _apiClient.get(
      '/management/dashboard$suffix',
      useCache: true,
      forceRefresh: forceRefresh,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(
          response,
          fallback: 'Failed to load dashboard.',
        ),
      );
    }
    return ManagementDashboardModel.fromJson(_apiClient.decodeObject(response));
  }

  Future<List<ShiftEntryModel>> fetchEntries({
    String? month,
    String? fromDate,
    String? toDate,
    bool approvedOnly = false,
    bool summary = true,
    bool forceRefresh = false,
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
    if (approvedOnly) {
      params['approvedOnly'] = 'true';
    }
    params['view'] = summary ? 'summary' : 'detail';
    final String suffix = params.isEmpty
        ? ''
        : '?${Uri(queryParameters: params).query}';
    final response = await _apiClient.get(
      '/management/entries$suffix',
      useCache: true,
      forceRefresh: forceRefresh,
      cachePolicy: forceRefresh
          ? ApiCachePolicy.networkFirst
          : ApiCachePolicy.cacheFirst,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(
          response,
          fallback: 'Failed to load management entries.',
        ),
      );
    }
    final json = _apiClient.decodeObject(response);
    return (json['entries'] as List<dynamic>? ?? const [])
        .map((item) => ShiftEntryModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ShiftEntryModel> fetchEntryDetail(
    String entryId, {
    bool forceRefresh = false,
  }) async {
    final response = await _apiClient.get(
      _entryPath(entryId),
      useCache: true,
      forceRefresh: forceRefresh,
      cachePolicy: ApiCachePolicy.networkFirst,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(
          response,
          fallback: 'Failed to load entry details.',
        ),
      );
    }
    final json = _apiClient.decodeObject(response);
    return ShiftEntryModel.fromJson(json['entry'] as Map<String, dynamic>);
  }

  Future<ShiftEntryModel> updateEntry({
    required String entryId,
    required Map<String, PumpReadings> closingReadings,
    required Map<String, PumpSalesmanModel> pumpSalesmen,
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
      _entryPath(entryId),
      body: jsonEncode({
        'closingReadings': closingReadings.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
        'pumpSalesmen': pumpSalesmen.map(
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
        'creditCollections': creditCollections
            .map((entry) => entry.toJson())
            .toList(),
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

  Future<ShiftEntryModel> approveEntry(String entryId) async {
    final response = await _apiClient.post(_entryPath(entryId, '/approve'));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(response, fallback: 'Failed to approve entry.'),
      );
    }
    final json = _apiClient.decodeObject(response);
    return ShiftEntryModel.fromJson(json['entry'] as Map<String, dynamic>);
  }

  Future<ShiftEntryModel> changeEntryDate(
    String entryId,
    String newDate,
  ) async {
    final response = await _apiClient.patch(
      _entryPath(entryId, '/date'),
      body: jsonEncode({'date': newDate}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(
          response,
          fallback: 'Failed to change entry date.',
        ),
      );
    }
    final json = _apiClient.decodeObject(response);
    return ShiftEntryModel.fromJson(json['entry'] as Map<String, dynamic>);
  }

  Future<void> deleteEntry(String entryId) async {
    final response = await _apiClient.delete(_entryPath(entryId));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(response, fallback: 'Failed to delete entry.'),
      );
    }
  }

  Future<MonthlyReportModel> fetchMonthlyReport({
    String? month,
    String? fromDate,
    String? toDate,
    bool forceRefresh = false,
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
    final String suffix = params.isEmpty
        ? ''
        : '?${Uri(queryParameters: params).query}';
    final response = await _apiClient.get(
      '/management/reports/monthly$suffix',
      useCache: true,
      forceRefresh: forceRefresh,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(
          response,
          fallback: 'Failed to load monthly report.',
        ),
      );
    }
    return MonthlyReportModel.fromJson(_apiClient.decodeObject(response));
  }
}
