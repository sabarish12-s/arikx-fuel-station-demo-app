import 'dart:convert';

import '../models/domain_models.dart';
import '../utils/formatters.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'management_service.dart';
import 'sales_service.dart';

class InventoryService {
  InventoryService()
    : _authService = AuthService(),
      _apiClient = ApiClient(AuthService());

  final AuthService _authService;
  final ApiClient _apiClient;
  final ManagementService _managementService = ManagementService();
  final SalesService _salesService = SalesService();

  Future<List<FuelTypeModel>> fetchFuelTypes({
    bool forceRefresh = false,
  }) async {
    final response = await _apiClient.get(
      '/inventory/fuel-types',
      useCache: true,
      forceRefresh: forceRefresh,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(
          response,
          fallback: 'Failed to load fuel types.',
        ),
      );
    }
    final json = _apiClient.decodeObject(response);
    return (json['fuelTypes'] as List<dynamic>? ?? const [])
        .map((item) => FuelTypeModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<DaySetupStateModel> fetchDaySetupState({
    bool forceRefresh = false,
  }) async {
    final response = await _apiClient.get(
      '/inventory/day-setup/state',
      useCache: true,
      forceRefresh: forceRefresh,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(
          response,
          fallback: 'Failed to load day setup state.',
        ),
      );
    }
    return DaySetupStateModel.fromJson(_apiClient.decodeObject(response));
  }

  Future<List<StationDaySetupModel>> fetchDaySetups({
    String? fromDate,
    String? toDate,
    bool deletedOnly = false,
    bool forceRefresh = false,
  }) async {
    final params = <String, String>{
      if (fromDate != null && fromDate.isNotEmpty) 'from': fromDate,
      if (toDate != null && toDate.isNotEmpty) 'to': toDate,
      if (deletedOnly) 'view': 'deleted',
    };
    final suffix = params.isEmpty
        ? ''
        : '?${Uri(queryParameters: params).query}';
    final response = await _apiClient.get(
      '/inventory/day-setup$suffix',
      useCache: true,
      forceRefresh: forceRefresh,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(
          response,
          fallback: 'Failed to load day setup history.',
        ),
      );
    }
    final json = _apiClient.decodeObject(response);
    return (json['setups'] as List<dynamic>? ?? const [])
        .map(
          (item) => StationDaySetupModel.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<StationDaySetupModel> saveDaySetup({
    required String effectiveDate,
    required Map<String, PumpReadings> openingReadings,
    required Map<String, double> startingStock,
    required Map<String, Map<String, double>> fuelPrices,
    String note = '',
  }) async {
    final response = await _apiClient.put(
      '/inventory/day-setup',
      body: jsonEncode({
        'effectiveDate': effectiveDate,
        'openingReadings': openingReadings.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
        'startingStock': startingStock,
        'fuelPrices': fuelPrices,
        'note': note,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(
          response,
          fallback: 'Failed to save day setup.',
        ),
      );
    }
    return StationDaySetupModel.fromJson(
      _apiClient.decodeObject(response)['setup'] as Map<String, dynamic>,
    );
  }

  Future<void> deleteDaySetup(String effectiveDate) async {
    final encoded = Uri.encodeComponent(effectiveDate);
    final response = await _apiClient.delete('/inventory/day-setup/$encoded');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(
          response,
          fallback: 'Failed to delete day setup.',
        ),
      );
    }
  }

  Future<FuelTypeModel> createFuelType(FuelTypeModel model) async {
    final response = await _apiClient.post(
      '/inventory/fuel-types',
      body: jsonEncode(model.toJson()),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(
          response,
          fallback: 'Failed to create fuel type.',
        ),
      );
    }
    return FuelTypeModel.fromJson(
      _apiClient.decodeObject(response)['fuelType'] as Map<String, dynamic>,
    );
  }

  Future<FuelTypeModel> updateFuelType(FuelTypeModel model) async {
    final response = await _apiClient.patch(
      '/inventory/fuel-types/${model.id}',
      body: jsonEncode(model.toJson()),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(
          response,
          fallback: 'Failed to update fuel type.',
        ),
      );
    }
    return FuelTypeModel.fromJson(
      _apiClient.decodeObject(response)['fuelType'] as Map<String, dynamic>,
    );
  }

  Future<void> deleteFuelType(String id) async {
    final response = await _apiClient.delete('/inventory/fuel-types/$id');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(
          response,
          fallback: 'Failed to delete fuel type.',
        ),
      );
    }
  }

  Future<List<FuelPriceModel>> fetchPrices({
    bool activeOnly = false,
    bool forceRefresh = false,
  }) async {
    final suffix = activeOnly ? '?view=active' : '';
    final response = await _apiClient.get(
      '/inventory/prices$suffix',
      useCache: true,
      forceRefresh: forceRefresh,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(response, fallback: 'Failed to load prices.'),
      );
    }
    final json = _apiClient.decodeObject(response);
    return (json['prices'] as List<dynamic>? ?? const [])
        .map((item) => FuelPriceModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteFuelPriceSet(String effectiveDate) async {
    final encoded = Uri.encodeComponent(effectiveDate);
    final response = await _apiClient.delete('/inventory/prices/sets/$encoded');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(
          response,
          fallback: 'Failed to delete fuel price history.',
        ),
      );
    }
  }

  Future<List<FuelPriceModel>> savePrices(List<FuelPriceModel> prices) async {
    final response = await _apiClient.put(
      '/inventory/prices',
      body: jsonEncode({
        'prices': prices.map((item) => item.toJson()).toList(),
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(response, fallback: 'Failed to save prices.'),
      );
    }
    final json = _apiClient.decodeObject(response);
    return (json['prices'] as List<dynamic>? ?? const [])
        .map((item) => FuelPriceModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<FuelPriceUpdateRequestModel>> fetchFuelPriceUpdateRequests({
    String status = '',
    bool forceRefresh = false,
  }) async {
    final params = <String, String>{
      if (status.trim().isNotEmpty) 'status': status.trim(),
    };
    final suffix = params.isEmpty
        ? ''
        : '?${Uri(queryParameters: params).query}';
    final response = await _apiClient.get(
      '/inventory/price-update-requests$suffix',
      useCache: true,
      forceRefresh: forceRefresh,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(
          response,
          fallback: 'Failed to load fuel price requests.',
        ),
      );
    }
    final json = _apiClient.decodeObject(response);
    return (json['requests'] as List<dynamic>? ?? const [])
        .map(
          (item) => FuelPriceUpdateRequestModel.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<FuelPriceUpdateRequestModel> createFuelPriceUpdateRequest({
    required String effectiveDate,
    required Map<String, Map<String, double>> fuelPrices,
    String note = '',
  }) async {
    final response = await _apiClient.post(
      '/inventory/price-update-requests',
      body: jsonEncode({
        'effectiveDate': effectiveDate,
        'fuelPrices': fuelPrices,
        'note': note,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(
          response,
          fallback: 'Failed to submit fuel price request.',
        ),
      );
    }
    return FuelPriceUpdateRequestModel.fromJson(
      _apiClient.decodeObject(response)['request'] as Map<String, dynamic>,
    );
  }

  Future<FuelPriceUpdateRequestModel> approveFuelPriceUpdateRequest(
    String requestId, {
    String note = '',
  }) async {
    final encoded = Uri.encodeComponent(requestId);
    final response = await _apiClient.post(
      '/inventory/price-update-requests/$encoded/approve',
      body: jsonEncode({'note': note}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(
          response,
          fallback: 'Failed to approve fuel price request.',
        ),
      );
    }
    return FuelPriceUpdateRequestModel.fromJson(
      _apiClient.decodeObject(response)['request'] as Map<String, dynamic>,
    );
  }

  Future<FuelPriceUpdateRequestModel> rejectFuelPriceUpdateRequest(
    String requestId, {
    String note = '',
  }) async {
    final encoded = Uri.encodeComponent(requestId);
    final response = await _apiClient.post(
      '/inventory/price-update-requests/$encoded/reject',
      body: jsonEncode({'note': note}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(
          response,
          fallback: 'Failed to reject fuel price request.',
        ),
      );
    }
    return FuelPriceUpdateRequestModel.fromJson(
      _apiClient.decodeObject(response)['request'] as Map<String, dynamic>,
    );
  }

  Future<StationConfigModel> fetchStationConfig({
    bool forceRefresh = false,
  }) async {
    final response = await _apiClient.get(
      '/inventory/station-config',
      useCache: true,
      forceRefresh: forceRefresh,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(
          response,
          fallback: 'Failed to load station config.',
        ),
      );
    }
    return StationConfigModel.fromJson(
      _apiClient.decodeObject(response)['station'] as Map<String, dynamic>,
    );
  }

  Future<InventoryDashboardModel> fetchInventoryDashboard({
    bool forceRefresh = false,
  }) async {
    final user = await _authService.readCurrentUser();
    final role = user?.role.trim().toLowerCase() ?? 'sales';

    final response = await _apiClient.get(
      '/inventory/dashboard',
      useCache: true,
      forceRefresh: forceRefresh,
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return InventoryDashboardModel.fromJson(
        _apiClient.decodeObject(response),
      );
    }
    if (_shouldUseLegacyInventoryFallback(response.body)) {
      if (role == 'sales') {
        try {
          return await _buildSalesInventoryDashboard(
            forceRefresh: forceRefresh,
          );
        } catch (_) {
          return _buildEmergencySalesInventoryDashboard(
            forceRefresh: forceRefresh,
          );
        }
      }
      return _buildLegacyInventoryDashboard(forceRefresh: forceRefresh);
    }
    throw Exception(
      _apiClient.errorMessage(
        response,
        fallback: 'Failed to load inventory dashboard.',
      ),
    );
  }

  Future<DailyFuelRecordModel> fetchDailyFuelRecord({
    String? date,
    bool forceRefresh = false,
  }) async {
    final suffix = date != null && date.isNotEmpty
        ? '?${Uri(queryParameters: {'date': date}).query}'
        : '';
    final response = await _apiClient.get(
      '/inventory/daily-fuel/current$suffix',
      useCache: true,
      forceRefresh: forceRefresh,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(
          response,
          fallback: 'Failed to load daily fuel register.',
        ),
      );
    }
    return DailyFuelRecordModel.fromJson(
      _apiClient.decodeObject(response)['record'] as Map<String, dynamic>,
    );
  }

  Future<List<DailyFuelRecordModel>> fetchDailyFuelHistory({
    String? fromDate,
    String? toDate,
    bool forceRefresh = false,
  }) async {
    final params = <String, String>{
      if (fromDate != null && fromDate.isNotEmpty) 'from': fromDate,
      if (toDate != null && toDate.isNotEmpty) 'to': toDate,
    };
    final suffix = params.isEmpty
        ? ''
        : '?${Uri(queryParameters: params).query}';
    final response = await _apiClient.get(
      '/inventory/daily-fuel$suffix',
      useCache: true,
      forceRefresh: forceRefresh,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(
          response,
          fallback: 'Failed to load daily fuel history.',
        ),
      );
    }
    final json = _apiClient.decodeObject(response);
    return (json['records'] as List<dynamic>? ?? const [])
        .map(
          (item) => DailyFuelRecordModel.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<DailyFuelRecordModel> saveDailyFuelRecord({
    required String date,
    required Map<String, double> density,
  }) async {
    final response = await _apiClient.put(
      '/inventory/daily-fuel',
      body: jsonEncode({'date': date, 'density': density}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(
          response,
          fallback: 'Failed to save daily fuel register.',
        ),
      );
    }
    return DailyFuelRecordModel.fromJson(
      _apiClient.decodeObject(response)['record'] as Map<String, dynamic>,
    );
  }

  Future<List<DeliveryReceiptModel>> fetchDeliveries({
    String? fromDate,
    String? toDate,
    bool forceRefresh = false,
  }) async {
    final params = <String, String>{
      'view': 'summary',
      if (fromDate != null && fromDate.isNotEmpty) 'from': fromDate,
      if (toDate != null && toDate.isNotEmpty) 'to': toDate,
    };
    final suffix = '?${Uri(queryParameters: params).query}';
    final response = await _apiClient.get(
      '/inventory/deliveries$suffix',
      useCache: true,
      forceRefresh: forceRefresh,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (_isMissingRoute(response.body) ||
          _isManagementAccessDenied(response.body)) {
        return const [];
      }
      throw Exception(
        _apiClient.errorMessage(
          response,
          fallback: 'Failed to load purchases.',
        ),
      );
    }
    final json = _apiClient.decodeObject(response);
    return (json['deliveries'] as List<dynamic>? ?? const [])
        .map(
          (item) => DeliveryReceiptModel.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<DeliveryReceiptModel> createDeliveryReceipt({
    required String date,
    required Map<String, double> quantities,
    String note = '',
  }) async {
    final response = await _apiClient.post(
      '/inventory/deliveries',
      body: jsonEncode({'date': date, 'quantities': quantities, 'note': note}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (_isMissingRoute(response.body)) {
        throw Exception(
          'This server does not support purchases yet. Update the backend before using inventory purchases.',
        );
      }
      if (_isManagementAccessDenied(response.body)) {
        throw Exception(
          'You do not have permission to record purchases on this server.',
        );
      }
      throw Exception(
        _apiClient.errorMessage(response, fallback: 'Failed to save purchase.'),
      );
    }
    return DeliveryReceiptModel.fromJson(
      _apiClient.decodeObject(response)['delivery'] as Map<String, dynamic>,
    );
  }

  Future<List<InventoryStockSnapshotModel>> fetchStockSnapshots({
    String? fromDate,
    String? toDate,
    bool deletedOnly = false,
    bool forceRefresh = false,
  }) async {
    final params = <String, String>{
      if (fromDate != null && fromDate.isNotEmpty) 'from': fromDate,
      if (toDate != null && toDate.isNotEmpty) 'to': toDate,
      if (deletedOnly) 'view': 'deleted',
    };
    final suffix = params.isEmpty
        ? ''
        : '?${Uri(queryParameters: params).query}';
    final response = await _apiClient.get(
      '/inventory/stock-snapshots$suffix',
      useCache: true,
      forceRefresh: forceRefresh,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(
          response,
          fallback: 'Failed to load stock history.',
        ),
      );
    }
    final json = _apiClient.decodeObject(response);
    return (json['snapshots'] as List<dynamic>? ?? const [])
        .map(
          (item) => InventoryStockSnapshotModel.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<InventoryStockSnapshotModel> createStockSnapshot({
    required String effectiveDate,
    required Map<String, double> stock,
    String note = '',
  }) async {
    final response = await _apiClient.post(
      '/inventory/stock-snapshots',
      body: jsonEncode({
        'effectiveDate': effectiveDate,
        'stock': stock,
        'note': note,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(response, fallback: 'Failed to save stock.'),
      );
    }
    return InventoryStockSnapshotModel.fromJson(
      _apiClient.decodeObject(response)['snapshot'] as Map<String, dynamic>,
    );
  }

  Future<void> deleteStockSnapshot(String snapshotId) async {
    final encoded = Uri.encodeComponent(snapshotId);
    final response = await _apiClient.delete(
      '/inventory/stock-snapshots/$encoded',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(
          response,
          fallback: 'Failed to delete stock history.',
        ),
      );
    }
  }

  Future<List<PumpOpeningReadingLogModel>> fetchOpeningReadingLogs({
    String? fromDate,
    String? toDate,
    bool deletedOnly = false,
    bool forceRefresh = false,
  }) async {
    final params = <String, String>{
      if (fromDate != null && fromDate.isNotEmpty) 'from': fromDate,
      if (toDate != null && toDate.isNotEmpty) 'to': toDate,
      if (deletedOnly) 'view': 'deleted',
    };
    final suffix = params.isEmpty
        ? ''
        : '?${Uri(queryParameters: params).query}';
    final response = await _apiClient.get(
      '/inventory/opening-readings$suffix',
      useCache: true,
      forceRefresh: forceRefresh,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(
          response,
          fallback: 'Failed to load pump opening reading history.',
        ),
      );
    }
    final json = _apiClient.decodeObject(response);
    return (json['logs'] as List<dynamic>? ?? const [])
        .map(
          (item) =>
              PumpOpeningReadingLogModel.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<PumpOpeningReadingLogModel> createOpeningReadingLog({
    required String effectiveDate,
    required Map<String, PumpReadings> readings,
    String note = '',
  }) async {
    final response = await _apiClient.post(
      '/inventory/opening-readings',
      body: jsonEncode({
        'effectiveDate': effectiveDate,
        'readings': readings.map((key, value) => MapEntry(key, value.toJson())),
        'note': note,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(
          response,
          fallback: 'Failed to save pump opening readings.',
        ),
      );
    }
    return PumpOpeningReadingLogModel.fromJson(
      _apiClient.decodeObject(response)['log'] as Map<String, dynamic>,
    );
  }

  Future<void> deleteOpeningReadingLog(String logId) async {
    final encoded = Uri.encodeComponent(logId);
    final response = await _apiClient.delete(
      '/inventory/opening-readings/$encoded',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(
          response,
          fallback: 'Failed to delete pump opening reading history.',
        ),
      );
    }
  }

  Future<StationConfigModel> saveStationConfig(
    StationConfigModel station,
  ) async {
    final response = await _apiClient.put(
      '/inventory/station-config',
      body: jsonEncode(station.toJson()),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(
          response,
          fallback: 'Failed to save station config.',
        ),
      );
    }
    return StationConfigModel.fromJson(
      _apiClient.decodeObject(response)['station'] as Map<String, dynamic>,
    );
  }

  Future<StationConfigModel> saveSalesmen(
    List<StationSalesmanModel> salesmen,
  ) async {
    final response = await _apiClient.put(
      '/inventory/station-config',
      body: jsonEncode({
        'salesmen': salesmen.map((item) => item.toJson()).toList(),
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _apiClient.errorMessage(
          response,
          fallback: 'Failed to save salesman settings.',
        ),
      );
    }
    return StationConfigModel.fromJson(
      _apiClient.decodeObject(response)['station'] as Map<String, dynamic>,
    );
  }

  bool _isMissingRoute(String body) {
    final normalized = body.toLowerCase();
    return normalized.contains('cannot get /inventory/dashboard') ||
        normalized.contains('cannot get /inventory/deliveries') ||
        normalized.contains('cannot post /inventory/deliveries');
  }

  bool _isManagementAccessDenied(String body) {
    return body.toLowerCase().contains('management access required');
  }

  bool _shouldUseLegacyInventoryFallback(String body) {
    return _isMissingRoute(body) || _isManagementAccessDenied(body);
  }

  Future<InventoryDashboardModel> _buildLegacyInventoryDashboard({
    bool forceRefresh = false,
  }) async {
    final station = await _loadStationForInventory(forceRefresh: forceRefresh);
    final entries = await _loadEntriesForLegacyInventory(
      forceRefresh: forceRefresh,
    );
    final deliveries = await _safeFetchDeliveries(forceRefresh: forceRefresh);
    return _buildFallbackInventoryDashboard(
      station: station,
      entries: entries,
      deliveries: deliveries,
    );
  }

  Future<InventoryDashboardModel> _buildSalesInventoryDashboard({
    bool forceRefresh = false,
  }) async {
    final station = await _loadStationForInventory(forceRefresh: forceRefresh);
    final entries = await _loadSalesEntriesForInventory(
      forceRefresh: forceRefresh,
    );
    final deliveries = await _safeFetchDeliveries(forceRefresh: forceRefresh);
    return _buildFallbackInventoryDashboard(
      station: station,
      entries: entries,
      deliveries: deliveries,
    );
  }

  Future<InventoryDashboardModel> _buildEmergencySalesInventoryDashboard({
    bool forceRefresh = false,
  }) async {
    final dashboard = await _salesService.fetchDashboard(
      forceRefresh: forceRefresh,
    );
    final entries = _fallbackEntriesFromDashboard(dashboard);
    return _buildFallbackInventoryDashboard(
      station: dashboard.station,
      entries: entries,
      deliveries: const [],
    );
  }

  InventoryDashboardModel _buildFallbackInventoryDashboard({
    required StationConfigModel station,
    required List<ShiftEntryModel> entries,
    required List<DeliveryReceiptModel> deliveries,
  }) {
    final baselineStock = station.inventoryPlanning.openingStock;
    final baselineUpdatedAt = station.inventoryPlanning.updatedAt.trim();
    final currentStock = <String, double>{
      'petrol': _roundNumber(baselineStock['petrol'] ?? 0),
      'diesel': _roundNumber(baselineStock['diesel'] ?? 0),
      'two_t_oil': _roundNumber(baselineStock['two_t_oil'] ?? 0),
    };
    final normalizedEntries = _normalizeInventoryEntries(entries);

    final receiptsAfterBaseline = deliveries.where((delivery) {
      if (baselineUpdatedAt.isEmpty) {
        return true;
      }
      return delivery.createdAt.trim().compareTo(baselineUpdatedAt) > 0;
    }).toList()..sort((left, right) => left.date.compareTo(right.date));

    final entriesAfterBaseline = normalizedEntries.where((entry) {
      if (baselineUpdatedAt.isEmpty) {
        return true;
      }
      return _entryInventoryTimestamp(entry).compareTo(baselineUpdatedAt) > 0;
    }).toList()..sort((left, right) => left.date.compareTo(right.date));

    for (final receipt in receiptsAfterBaseline) {
      for (final fuelTypeId in ['petrol', 'diesel', 'two_t_oil']) {
        currentStock[fuelTypeId] = _roundNumber(
          (currentStock[fuelTypeId] ?? 0) +
              (receipt.quantities[fuelTypeId] ?? 0),
        );
      }
    }

    for (final entry in entriesAfterBaseline) {
      currentStock['petrol'] = _roundNumber(
        (currentStock['petrol'] ?? 0) - _inventoryFuelTotal(entry, 'petrol'),
      );
      currentStock['diesel'] = _roundNumber(
        (currentStock['diesel'] ?? 0) - _inventoryFuelTotal(entry, 'diesel'),
      );
      currentStock['two_t_oil'] = _roundNumber(
        (currentStock['two_t_oil'] ?? 0) - _inventoryFuelTotal(entry, 'twoT'),
      );
    }

    final planning = InventoryPlanningModel(
      openingStock: baselineStock,
      currentStock: currentStock,
      deliveryLeadDays: station.inventoryPlanning.deliveryLeadDays,
      alertBeforeDays: station.inventoryPlanning.alertBeforeDays,
      updatedAt: station.inventoryPlanning.updatedAt,
    );

    return InventoryDashboardModel(
      station: station,
      inventoryPlanning: planning,
      forecast: [
        _buildLegacyForecast(
          fuelTypeId: 'petrol',
          label: 'Petrol',
          currentStock: currentStock['petrol'] ?? 0,
          averageDailySales: _averageDailySales(normalizedEntries, 'petrol'),
          planning: planning,
        ),
        _buildLegacyForecast(
          fuelTypeId: 'diesel',
          label: 'Diesel',
          currentStock: currentStock['diesel'] ?? 0,
          averageDailySales: _averageDailySales(normalizedEntries, 'diesel'),
          planning: planning,
        ),
        _buildLegacyForecast(
          fuelTypeId: 'two_t_oil',
          label: '2T Oil',
          currentStock: currentStock['two_t_oil'] ?? 0,
          averageDailySales: _averageDailySales(normalizedEntries, 'twoT'),
          planning: planning,
        ),
      ],
      deliveries: deliveries,
      activeStockSnapshot: InventoryStockSnapshotModel(
        id: 'fallback-active-stock',
        stationId: station.id,
        effectiveDate: baselineUpdatedAt.isEmpty
            ? DateTime.now().toIso8601String().split('T').first
            : baselineUpdatedAt.split('T').first,
        stock: baselineStock,
        note: '',
        createdAt: baselineUpdatedAt,
        createdBy: '',
        createdByName: '',
      ),
    );
  }

  Future<StationConfigModel> _loadStationForInventory({
    bool forceRefresh = false,
  }) async {
    try {
      return await fetchStationConfig(forceRefresh: forceRefresh);
    } catch (_) {
      final dashboard = await _salesService.fetchDashboard(
        forceRefresh: forceRefresh,
      );
      return dashboard.station;
    }
  }

  Future<List<ShiftEntryModel>> _loadSalesEntriesForInventory({
    bool forceRefresh = false,
  }) async {
    try {
      return await _salesService.fetchEntries(
        month: currentMonthKey(),
        summary: true,
        forceRefresh: forceRefresh,
      );
    } catch (_) {
      final dashboard = await _salesService.fetchDashboard(
        forceRefresh: forceRefresh,
      );
      return _fallbackEntriesFromDashboard(dashboard);
    }
  }

  List<ShiftEntryModel> _fallbackEntriesFromDashboard(
    SalesDashboardModel dashboard,
  ) {
    final entries = <ShiftEntryModel>[
      ...dashboard.todaysEntries,
      if (dashboard.selectedEntry != null &&
          !dashboard.todaysEntries.any(
            (item) => item.id == dashboard.selectedEntry!.id,
          ))
        dashboard.selectedEntry!,
    ];
    return entries;
  }

  Future<List<DeliveryReceiptModel>> _safeFetchDeliveries({
    bool forceRefresh = false,
  }) async {
    try {
      return await fetchDeliveries(forceRefresh: forceRefresh);
    } catch (_) {
      return const [];
    }
  }

  Future<List<ShiftEntryModel>> _loadEntriesForLegacyInventory({
    bool forceRefresh = false,
  }) async {
    final user = await _authService.readCurrentUser();
    final role = user?.role.trim().toLowerCase() ?? 'sales';
    if (role == 'admin' || role == 'superadmin') {
      try {
        return await _managementService.fetchEntries(
          month: currentMonthKey(),
          approvedOnly: false,
          summary: true,
          forceRefresh: forceRefresh,
        );
      } catch (_) {
        // Fall back to sales-visible entries when management endpoints are unavailable.
      }
    }
    return _salesService.fetchEntries(
      month: currentMonthKey(),
      summary: true,
      forceRefresh: forceRefresh,
    );
  }

  double _averageDailySales(
    List<ShiftEntryModel> entries,
    String fuelKey, {
    String? endDate,
  }) {
    final totalsByDate = <String, double>{};
    for (final entry in entries) {
      final sold = _inventoryFuelTotal(entry, fuelKey);
      totalsByDate[entry.date] = (totalsByDate[entry.date] ?? 0) + sold;
    }
    final resolvedEndDate =
        endDate ?? DateTime.now().toIso8601String().split('T').first;
    final windowDates = List<String>.generate(
      7,
      (index) => _shiftIsoDate(resolvedEndDate, -index),
    ).reversed.toList();
    final enteredDates = windowDates
        .where((date) => totalsByDate.containsKey(date))
        .toList(growable: false);
    if (enteredDates.isEmpty) {
      return 0;
    }
    final total = enteredDates.fold<double>(
      0,
      (sum, date) => sum + (totalsByDate[date] ?? 0),
    );
    return total / enteredDates.length;
  }

  FuelInventoryForecastModel _buildLegacyForecast({
    required String fuelTypeId,
    required String label,
    required double currentStock,
    required double averageDailySales,
    required InventoryPlanningModel planning,
  }) {
    final totalLeadWindow =
        planning.deliveryLeadDays + planning.alertBeforeDays;
    final daysRemaining = averageDailySales > 0
        ? currentStock / averageDailySales
        : null;
    final projectedRunoutDate = daysRemaining == null
        ? ''
        : _shiftIsoDate(
            DateTime.now().toIso8601String().split('T').first,
            daysRemaining.floor(),
          );
    final recommendedOrderDate = projectedRunoutDate.isEmpty
        ? ''
        : _shiftIsoDate(projectedRunoutDate, -totalLeadWindow);
    final shouldAlert =
        averageDailySales > 0 &&
        currentStock <= averageDailySales * totalLeadWindow;

    return FuelInventoryForecastModel(
      fuelTypeId: fuelTypeId,
      label: label,
      currentStock: currentStock,
      averageDailySales: averageDailySales,
      daysRemaining: daysRemaining,
      projectedRunoutDate: projectedRunoutDate,
      recommendedOrderDate: recommendedOrderDate,
      shouldAlert: shouldAlert,
      alertMessage: shouldAlert
          ? '$label stock is low for the configured lead time. This screen is using local fallback inventory math because the server inventory dashboard is unavailable.'
          : '',
    );
  }

  double _roundNumber(double value) {
    return double.parse(value.toStringAsFixed(2));
  }

  double _inventoryFuelTotal(ShiftEntryModel entry, String fuelKey) {
    switch (fuelKey) {
      case 'petrol':
        return entry.inventoryTotals.petrol;
      case 'diesel':
        return entry.inventoryTotals.diesel;
      case 'twoT':
      case 'two_t_oil':
        return entry.inventoryTotals.twoT;
      default:
        return 0;
    }
  }

  String _entryInventoryTimestamp(ShiftEntryModel entry) {
    return entry.latestActivityTimestamp;
  }

  List<ShiftEntryModel> _normalizeInventoryEntries(
    List<ShiftEntryModel> entries,
  ) {
    final latestByDate = <String, ShiftEntryModel>{};
    for (final entry in entries) {
      if (!entry.isFinalized) {
        continue;
      }
      final existing = latestByDate[entry.date];
      if (existing == null) {
        latestByDate[entry.date] = entry;
        continue;
      }
      final nextTimestamp = entry.latestActivityTimestamp;
      final existingTimestamp = existing.latestActivityTimestamp;
      if (nextTimestamp.compareTo(existingTimestamp) >= 0) {
        latestByDate[entry.date] = entry;
      }
    }
    final normalized = latestByDate.values.toList()
      ..sort((left, right) => left.date.compareTo(right.date));
    return normalized;
  }

  String _shiftIsoDate(String date, int offsetDays) {
    final parsed = DateTime.tryParse(date);
    if (parsed == null) {
      return '';
    }
    final shifted = parsed.add(Duration(days: offsetDays));
    final month = shifted.month.toString().padLeft(2, '0');
    final day = shifted.day.toString().padLeft(2, '0');
    return '${shifted.year}-$month-$day';
  }
}
