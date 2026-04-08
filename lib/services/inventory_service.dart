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

  Future<List<FuelTypeModel>> fetchFuelTypes() async {
    final response = await _apiClient.get('/inventory/fuel-types');
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

  Future<List<FuelPriceModel>> fetchPrices({bool activeOnly = false}) async {
    final suffix = activeOnly ? '?view=active' : '';
    final response = await _apiClient.get('/inventory/prices$suffix');
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

  Future<StationConfigModel> fetchStationConfig() async {
    final response = await _apiClient.get('/inventory/station-config');
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

  Future<InventoryDashboardModel> fetchInventoryDashboard() async {
    final user = await _authService.readCurrentUser();
    final role = user?.role.trim().toLowerCase() ?? 'sales';

    final response = await _apiClient.get('/inventory/dashboard');
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return InventoryDashboardModel.fromJson(
        _apiClient.decodeObject(response),
      );
    }
    if (_shouldUseLegacyInventoryFallback(response.body)) {
      if (role == 'sales') {
        try {
          return await _buildSalesInventoryDashboard();
        } catch (_) {
          return _buildEmergencySalesInventoryDashboard();
        }
      }
      return _buildLegacyInventoryDashboard();
    }
    throw Exception(
      _apiClient.errorMessage(
        response,
        fallback: 'Failed to load inventory dashboard.',
      ),
    );
  }

  Future<List<DeliveryReceiptModel>> fetchDeliveries() async {
    final response = await _apiClient.get('/inventory/deliveries?view=summary');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (_isMissingRoute(response.body) ||
          _isManagementAccessDenied(response.body)) {
        return const [];
      }
      throw Exception(
        _apiClient.errorMessage(
          response,
          fallback: 'Failed to load deliveries.',
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
          'This server does not support delivery receipts yet. Update the backend before using inventory delivery.',
        );
      }
      if (_isManagementAccessDenied(response.body)) {
        throw Exception(
          'You do not have permission to record delivery receipts on this server.',
        );
      }
      throw Exception(
        _apiClient.errorMessage(
          response,
          fallback: 'Failed to save delivery receipt.',
        ),
      );
    }
    return DeliveryReceiptModel.fromJson(
      _apiClient.decodeObject(response)['delivery'] as Map<String, dynamic>,
    );
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

  Future<InventoryDashboardModel> _buildLegacyInventoryDashboard() async {
    final station = await _loadStationForInventory();
    final entries = await _loadEntriesForLegacyInventory();
    final deliveries = await _safeFetchDeliveries();
    return _buildFallbackInventoryDashboard(
      station: station,
      entries: entries,
      deliveries: deliveries,
    );
  }

  Future<InventoryDashboardModel> _buildSalesInventoryDashboard() async {
    final station = await _loadStationForInventory();
    final entries = await _loadSalesEntriesForInventory();
    final deliveries = await _safeFetchDeliveries();
    return _buildFallbackInventoryDashboard(
      station: station,
      entries: entries,
      deliveries: deliveries,
    );
  }

  Future<InventoryDashboardModel>
  _buildEmergencySalesInventoryDashboard() async {
    final dashboard = await _salesService.fetchDashboard();
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

    final receiptsAfterBaseline =
        deliveries.where((delivery) {
            if (baselineUpdatedAt.isEmpty) {
              return true;
            }
            return delivery.createdAt.trim().compareTo(baselineUpdatedAt) > 0;
          }).toList()
          ..sort((left, right) => left.date.compareTo(right.date));

    final entriesAfterBaseline =
        entries.where((entry) {
            if (entry.status == 'preview') {
              return false;
            }
            if (baselineUpdatedAt.isEmpty) {
              return true;
            }
            return _entryInventoryTimestamp(
                  entry,
                ).compareTo(baselineUpdatedAt) >
                0;
          }).toList()
          ..sort((left, right) => left.date.compareTo(right.date));

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
        (currentStock['petrol'] ?? 0) - entry.totals.sold.petrol,
      );
      currentStock['diesel'] = _roundNumber(
        (currentStock['diesel'] ?? 0) - entry.totals.sold.diesel,
      );
      currentStock['two_t_oil'] = _roundNumber(
        (currentStock['two_t_oil'] ?? 0) - entry.totals.sold.twoT,
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
          averageDailySales: _averageDailySales(entries, 'petrol'),
          planning: planning,
        ),
        _buildLegacyForecast(
          fuelTypeId: 'diesel',
          label: 'Diesel',
          currentStock: currentStock['diesel'] ?? 0,
          averageDailySales: _averageDailySales(entries, 'diesel'),
          planning: planning,
        ),
        _buildLegacyForecast(
          fuelTypeId: 'two_t_oil',
          label: '2T Oil',
          currentStock: currentStock['two_t_oil'] ?? 0,
          averageDailySales: _averageDailySales(entries, 'twoT'),
          planning: planning,
        ),
      ],
      deliveries: deliveries,
    );
  }

  Future<StationConfigModel> _loadStationForInventory() async {
    try {
      return await fetchStationConfig();
    } catch (_) {
      final dashboard = await _salesService.fetchDashboard();
      return dashboard.station;
    }
  }

  Future<List<ShiftEntryModel>> _loadSalesEntriesForInventory() async {
    try {
      return await _salesService.fetchEntries(
        month: currentMonthKey(),
        summary: true,
      );
    } catch (_) {
      final dashboard = await _salesService.fetchDashboard();
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

  Future<List<DeliveryReceiptModel>> _safeFetchDeliveries() async {
    try {
      return await fetchDeliveries();
    } catch (_) {
      return const [];
    }
  }

  Future<List<ShiftEntryModel>> _loadEntriesForLegacyInventory() async {
    final user = await _authService.readCurrentUser();
    final role = user?.role.trim().toLowerCase() ?? 'sales';
    if (role == 'admin' || role == 'superadmin') {
      try {
        return await _managementService.fetchEntries(
          month: currentMonthKey(),
          approvedOnly: false,
          summary: true,
        );
      } catch (_) {
        // Fall back to sales-visible entries when management endpoints are unavailable.
      }
    }
    return _salesService.fetchEntries(
      month: currentMonthKey(),
      summary: true,
    );
  }

  double _averageDailySales(List<ShiftEntryModel> entries, String fuelKey) {
    final totalsByDate = <String, double>{};
    for (final entry in entries) {
      final sold =
          fuelKey == 'petrol'
              ? entry.totals.sold.petrol
              : fuelKey == 'diesel'
              ? entry.totals.sold.diesel
              : entry.totals.sold.twoT;
      totalsByDate[entry.date] = (totalsByDate[entry.date] ?? 0) + sold;
    }
    final recent =
        totalsByDate.entries.toList()
          ..removeWhere((item) => item.value <= 0)
          ..sort((a, b) => b.key.compareTo(a.key));
    final selected = recent.take(7).toList();
    if (selected.isEmpty) {
      return 0;
    }
    final total = selected.fold<double>(0, (sum, item) => sum + item.value);
    return total / selected.length;
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
    final daysRemaining =
        averageDailySales > 0 ? currentStock / averageDailySales : null;
    final projectedRunoutDate =
        daysRemaining == null
            ? ''
            : _shiftIsoDate(
              DateTime.now().toIso8601String().split('T').first,
              daysRemaining.floor(),
            );
    final recommendedOrderDate =
        projectedRunoutDate.isEmpty
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
      alertMessage:
          shouldAlert
              ? '$label stock is low for the configured lead time. This screen is using local fallback inventory math because the server inventory dashboard is unavailable.'
              : '',
    );
  }

  double _roundNumber(double value) {
    return double.parse(value.toStringAsFixed(2));
  }

  String _entryInventoryTimestamp(ShiftEntryModel entry) {
    final approvedAt = entry.approvedAt.trim();
    if (approvedAt.isNotEmpty) {
      return approvedAt;
    }
    final updatedAt = entry.updatedAt.trim();
    if (updatedAt.isNotEmpty) {
      return updatedAt;
    }
    return entry.submittedAt.trim();
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
