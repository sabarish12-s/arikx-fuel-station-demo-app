import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rk_fuels/models/domain_models.dart';
import 'package:rk_fuels/widgets/daily_fuel_widgets.dart';

DailyFuelRecordModel _record({
  bool complete = true,
  bool exists = true,
}) {
  return DailyFuelRecordModel(
    id: 'station-1:2026-04-18',
    stationId: 'station-1',
    date: '2026-04-18',
    openingStock: const <String, double>{
      'petrol': 1285.5,
      'diesel': 2460.75,
    },
    density: <String, double>{
      'petrol': complete ? 741.225 : 0,
      'diesel': complete ? 832.455 : 0,
    },
    price: const <String, double>{
      'petrol': 102.45,
      'diesel': 94.15,
    },
    sourceClosingDate: '2026-04-17',
    createdBy: 'sales-1',
    createdByName: 'Sales User',
    updatedBy: 'admin-1',
    updatedByName: 'Admin User',
    createdAt: '2026-04-18T05:00:00.000Z',
    updatedAt: '2026-04-18T06:30:00.000Z',
    exists: exists,
    complete: complete,
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  group('DailyFuelStatusCard', () {
    testWidgets('shows pending state when the record is missing', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DailyFuelStatusCard(
            title: 'Daily Fuel Status',
            targetDate: '2026-04-18',
            record: null,
            pendingMessage: 'Save density before sales entry.',
          ),
        ),
      );

      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Save density before sales entry.'), findsOneWidget);
      expect(find.textContaining('Opening stock source:'), findsNothing);
    });

    testWidgets('shows saved metrics when a complete record exists', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DailyFuelStatusCard(
            title: 'Daily Fuel Status',
            targetDate: '2026-04-18',
            record: _record(),
            primaryActionLabel: 'Edit Density',
            onPrimaryAction: () {},
            onHistory: () {},
          ),
        ),
      );

      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('Edit Density'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.textContaining('Opening stock source:'), findsOneWidget);
      expect(find.text('Petrol'), findsWidgets);
      expect(find.text('Diesel'), findsWidgets);
    });
  });

  group('DailyFuelEntrySection', () {
    testWidgets('blocks save when either density value is missing', (tester) async {
      Map<String, double>? savedPayload;

      await tester.pumpWidget(
        _wrap(
          DailyFuelEntrySection(
            targetDate: '2026-04-18',
            record: _record(complete: false, exists: false),
            busy: false,
            onSave: (density) async {
              savedPayload = density;
            },
          ),
        ),
      );

      await tester.tap(find.text('Save Density'));
      await tester.pump();

      expect(savedPayload, isNull);
      expect(
        find.text('Enter petrol and diesel density values greater than zero.'),
        findsOneWidget,
      );
    });

    testWidgets('submits both density values when valid numbers are entered', (tester) async {
      Map<String, double>? savedPayload;

      await tester.pumpWidget(
        _wrap(
          DailyFuelEntrySection(
            targetDate: '2026-04-18',
            record: _record(complete: false, exists: false),
            busy: false,
            onSave: (density) async {
              savedPayload = density;
            },
          ),
        ),
      );

      await tester.enterText(find.byType(TextField).at(0), '744.125');
      await tester.enterText(find.byType(TextField).at(1), '834.875');
      await tester.tap(find.text('Save Density'));
      await tester.pump();

      expect(savedPayload, isNotNull);
      expect(savedPayload?['petrol'], 744.125);
      expect(savedPayload?['diesel'], 834.875);
    });
  });
}
