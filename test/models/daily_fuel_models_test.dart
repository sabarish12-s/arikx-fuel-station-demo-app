import 'package:flutter_test/flutter_test.dart';
import 'package:rk_fuels/models/domain_models.dart';

Map<String, dynamic> _stationJson() {
  return <String, dynamic>{
    'id': 'station-1',
    'name': 'RK Fuels',
    'code': 'RKF',
    'city': 'Salem',
    'shifts': const <String>['morning', 'afternoon', 'night'],
    'pumps': const <Map<String, dynamic>>[],
    'baseReadings': const <String, dynamic>{},
    'meterLimits': const <String, dynamic>{},
    'inventoryPlanning': const <String, dynamic>{},
  };
}

Map<String, dynamic> _dailyFuelJson() {
  return <String, dynamic>{
    'id': 'station-1:2026-04-18',
    'stationId': 'station-1',
    'date': '2026-04-18',
    'openingStock': const <String, dynamic>{
      'petrol': 1450.5,
      'diesel': 2980.25,
    },
    'density': const <String, dynamic>{
      'petrol': 742.125,
      'diesel': 833.625,
    },
    'price': const <String, dynamic>{
      'petrol': 102.45,
      'diesel': 94.15,
    },
    'sourceClosingDate': '2026-04-17',
    'createdBy': 'sales-1',
    'createdByName': 'Sales User',
    'updatedBy': 'admin-1',
    'updatedByName': 'Admin User',
    'createdAt': '2026-04-18T05:00:00.000Z',
    'updatedAt': '2026-04-18T06:30:00.000Z',
    'exists': true,
    'complete': true,
  };
}

void main() {
  group('DailyFuelRecordModel', () {
    test('parses the resolved record payload and completeness flags', () {
      final record = DailyFuelRecordModel.fromJson(_dailyFuelJson());

      expect(record.id, 'station-1:2026-04-18');
      expect(record.openingStock['petrol'], 1450.5);
      expect(record.openingStock['diesel'], 2980.25);
      expect(record.density['petrol'], 742.125);
      expect(record.density['diesel'], 833.625);
      expect(record.price['petrol'], 102.45);
      expect(record.price['diesel'], 94.15);
      expect(record.sourceClosingDate, '2026-04-17');
      expect(record.exists, isTrue);
      expect(record.isComplete, isTrue);
    });

    test('treats records with both densities as complete even when flag is absent', () {
      final json = _dailyFuelJson()..remove('complete');

      final record = DailyFuelRecordModel.fromJson(json);

      expect(record.complete, isFalse);
      expect(record.isComplete, isTrue);
    });
  });

  group('dashboard model parsing', () {
    test('sales dashboard exposes the daily fuel register gate and record', () {
      final dashboard = SalesDashboardModel.fromJson(<String, dynamic>{
        'station': _stationJson(),
        'date': '2026-04-18',
        'setupExists': true,
        'allowedEntryDate': '2026-04-18',
        'activeSetupDate': '2026-04-18',
        'entryLockedReason': '',
        'openingReadings': const <String, dynamic>{},
        'entryExists': false,
        'totals': const <String, dynamic>{'entriesCompleted': 0},
        'todaysEntries': const <dynamic>[],
        'priceSnapshot': const <String, dynamic>{},
        'dailyFuelRecord': _dailyFuelJson(),
        'dailyFuelRecordComplete': true,
      });

      expect(dashboard.allowedEntryDate, '2026-04-18');
      expect(dashboard.dailyFuelRecordComplete, isTrue);
      expect(dashboard.dailyFuelRecord, isNotNull);
      expect(dashboard.dailyFuelRecord?.density['petrol'], 742.125);
    });

    test('management dashboard exposes the register summary for entries gating', () {
      final dashboard = ManagementDashboardModel.fromJson(<String, dynamic>{
        'station': _stationJson(),
        'today': '2026-04-19',
        'range': const <String, dynamic>{
          'label': 'Today',
          'preset': 'today',
          'fromDate': '2026-04-19',
          'toDate': '2026-04-19',
        },
        'setupExists': true,
        'allowedEntryDate': '2026-04-18',
        'activeSetupDate': '2026-04-18',
        'entryLockedReason': '',
        'pendingRequests': 0,
        'varianceCount': 0,
        'totals': const <String, dynamic>{'entriesCompleted': 2},
        'pumpPerformance': const <dynamic>[],
        'attendantPerformance': const <dynamic>[],
        'trend': const <dynamic>[],
        'recentEntries': const <dynamic>[],
        'fuelTypes': const <dynamic>[],
        'prices': const <dynamic>[],
        'dailyFuelRecord': _dailyFuelJson(),
        'dailyFuelRecordComplete': true,
      });

      expect(dashboard.allowedEntryDate, '2026-04-18');
      expect(dashboard.entriesCompleted, 2);
      expect(dashboard.dailyFuelRecordComplete, isTrue);
      expect(dashboard.dailyFuelRecord?.price['diesel'], 94.15);
    });
  });
}
