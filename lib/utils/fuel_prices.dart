import '../models/domain_models.dart';

const List<String> _defaultFuelPriceKeys = <String>[
  'petrol',
  'diesel',
  'two_t_oil',
];

double _preferredPriceValue(double? primary, double? fallback) {
  final primaryValue = primary ?? 0;
  if (primaryValue > 0) {
    return primaryValue;
  }
  final fallbackValue = fallback ?? 0;
  if (fallbackValue > 0) {
    return fallbackValue;
  }
  return primaryValue;
}

Map<String, Map<String, double>> buildPriceSnapshotFromPrices(
  Iterable<FuelPriceModel> prices,
) {
  final snapshot = <String, Map<String, double>>{};
  for (final price in prices) {
    final fuelTypeId = price.fuelTypeId.trim();
    if (fuelTypeId.isEmpty) {
      continue;
    }
    snapshot[fuelTypeId] = <String, double>{
      'sellingPrice': price.sellingPrice,
      'costPrice': price.costPrice,
    };
  }
  return mergePriceSnapshots(primary: snapshot);
}

Map<String, Map<String, double>> mergePriceSnapshots({
  Map<String, Map<String, double>> primary =
      const <String, Map<String, double>>{},
  Map<String, Map<String, double>> fallback =
      const <String, Map<String, double>>{},
}) {
  final merged = <String, Map<String, double>>{};
  final keys = <String>{
    ..._defaultFuelPriceKeys,
    ...fallback.keys,
    ...primary.keys,
  };

  for (final key in keys) {
    final primaryEntry = primary[key] ?? const <String, double>{};
    final fallbackEntry = fallback[key] ?? const <String, double>{};
    final sellingPrice = _preferredPriceValue(
      primaryEntry['sellingPrice'],
      fallbackEntry['sellingPrice'],
    );
    final costPrice = _preferredPriceValue(
      primaryEntry['costPrice'],
      fallbackEntry['costPrice'],
    );

    if (sellingPrice > 0 || costPrice > 0) {
      merged[key] = <String, double>{
        'sellingPrice': sellingPrice,
        'costPrice': costPrice,
      };
    }
  }

  return merged;
}

bool hasRequiredSellingPrices(
  Map<String, Map<String, double>> snapshot,
  Iterable<String> fuelKeys,
) {
  return fuelKeys.every(
    (fuelKey) => (snapshot[fuelKey]?['sellingPrice'] ?? 0) > 0,
  );
}
