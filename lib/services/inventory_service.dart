import 'dart:convert';

import '../models/domain_models.dart';
import 'api_client.dart';
import 'auth_service.dart';

class InventoryService {
  InventoryService() : _apiClient = ApiClient(AuthService());

  final ApiClient _apiClient;

  Future<List<FuelTypeModel>> fetchFuelTypes() async {
    final response = await _apiClient.get('/inventory/fuel-types');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load fuel types: ${response.body}');
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
      throw Exception('Failed to create fuel type: ${response.body}');
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
      throw Exception('Failed to update fuel type: ${response.body}');
    }
    return FuelTypeModel.fromJson(
      _apiClient.decodeObject(response)['fuelType'] as Map<String, dynamic>,
    );
  }

  Future<void> deleteFuelType(String id) async {
    final response = await _apiClient.delete('/inventory/fuel-types/$id');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to delete fuel type: ${response.body}');
    }
  }

  Future<List<FuelPriceModel>> fetchPrices() async {
    final response = await _apiClient.get('/inventory/prices');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load prices: ${response.body}');
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
      throw Exception('Failed to save prices: ${response.body}');
    }
    final json = _apiClient.decodeObject(response);
    return (json['prices'] as List<dynamic>? ?? const [])
        .map((item) => FuelPriceModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<StationConfigModel> fetchStationConfig() async {
    final response = await _apiClient.get('/inventory/station-config');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load station config: ${response.body}');
    }
    return StationConfigModel.fromJson(
      _apiClient.decodeObject(response)['station'] as Map<String, dynamic>,
    );
  }

  Future<StationConfigModel> saveStationConfig(StationConfigModel station) async {
    final response = await _apiClient.put(
      '/inventory/station-config',
      body: jsonEncode(station.toJson()),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to save station config: ${response.body}');
    }
    return StationConfigModel.fromJson(
      _apiClient.decodeObject(response)['station'] as Map<String, dynamic>,
    );
  }
}
