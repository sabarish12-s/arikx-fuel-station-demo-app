import 'package:flutter_test/flutter_test.dart';
import 'package:rk_fuels/models/domain_models.dart';
import 'package:rk_fuels/utils/fuel_prices.dart';

void main() {
  group('mergePriceSnapshots', () {
    test('fills missing selling prices from fallback prices', () {
      final merged = mergePriceSnapshots(
        primary: const <String, Map<String, double>>{
          'petrol': <String, double>{'sellingPrice': 0, 'costPrice': 72},
        },
        fallback: buildPriceSnapshotFromPrices(const <FuelPriceModel>[
          FuelPriceModel(
            fuelTypeId: 'petrol',
            costPrice: 74,
            sellingPrice: 101.5,
            updatedAt: '',
            updatedBy: '',
          ),
          FuelPriceModel(
            fuelTypeId: 'diesel',
            costPrice: 69,
            sellingPrice: 92.25,
            updatedAt: '',
            updatedBy: '',
          ),
        ]),
      );

      expect(merged['petrol']?['sellingPrice'], 101.5);
      expect(merged['petrol']?['costPrice'], 72);
      expect(merged['diesel']?['sellingPrice'], 92.25);
    });

    test('keeps non-zero primary prices when present', () {
      final merged = mergePriceSnapshots(
        primary: const <String, Map<String, double>>{
          'petrol': <String, double>{'sellingPrice': 104.75, 'costPrice': 76},
        },
        fallback: const <String, Map<String, double>>{
          'petrol': <String, double>{'sellingPrice': 99, 'costPrice': 70},
        },
      );

      expect(merged['petrol']?['sellingPrice'], 104.75);
      expect(merged['petrol']?['costPrice'], 76);
    });
  });

  group('hasRequiredSellingPrices', () {
    test('returns false when a required fuel is missing', () {
      const snapshot = <String, Map<String, double>>{
        'petrol': <String, double>{'sellingPrice': 104.75, 'costPrice': 76},
      };

      expect(
        hasRequiredSellingPrices(snapshot, const <String>['petrol', 'diesel']),
        isFalse,
      );
    });

    test('returns true when all required fuels have selling prices', () {
      const snapshot = <String, Map<String, double>>{
        'petrol': <String, double>{'sellingPrice': 104.75, 'costPrice': 76},
        'diesel': <String, double>{'sellingPrice': 95.2, 'costPrice': 70},
      };

      expect(
        hasRequiredSellingPrices(snapshot, const <String>['petrol', 'diesel']),
        isTrue,
      );
    });
  });
}
