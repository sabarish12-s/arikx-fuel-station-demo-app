import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_station_demo_app/utils/sales_entry_dates.dart';

void main() {
  group('resolveDefaultSalesEntryDate', () {
    test('returns today when there are no entries', () {
      expect(
        resolveDefaultSalesEntryDate(const [], today: DateTime(2026, 4, 11)),
        '2026-04-11',
      );
    });

    test('returns the day after the latest existing entry', () {
      expect(
        resolveDefaultSalesEntryDate(const [
          '2026-04-08',
          '2026-04-09',
        ], today: DateTime(2026, 4, 11)),
        '2026-04-10',
      );
    });

    test('returns today when the latest entry is yesterday', () {
      expect(
        resolveDefaultSalesEntryDate(const [
          '2026-04-10',
        ], today: DateTime(2026, 4, 11)),
        '2026-04-11',
      );
    });

    test('caps the result at today when the latest entry is today', () {
      expect(
        resolveDefaultSalesEntryDate(const [
          '2026-04-11',
        ], today: DateTime(2026, 4, 11)),
        '2026-04-11',
      );
    });

    test('ignores invalid and empty dates', () {
      expect(
        resolveDefaultSalesEntryDate(const [
          '',
          'not-a-date',
          '2026-02-30',
          '2026-04-08',
        ], today: DateTime(2026, 4, 11)),
        '2026-04-09',
      );
    });

    test('ignores older gaps and uses the latest entry only', () {
      expect(
        resolveDefaultSalesEntryDate(const [
          '2026-04-01',
          '2026-04-03',
          '2026-04-09',
        ], today: DateTime(2026, 4, 11)),
        '2026-04-10',
      );
    });
  });

  test('salesEntryApiDate formats date-only API values', () {
    expect(salesEntryApiDate(DateTime(2026, 4, 9, 23, 59)), '2026-04-09');
  });
}
