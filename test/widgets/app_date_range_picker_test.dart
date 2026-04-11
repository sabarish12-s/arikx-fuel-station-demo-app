import 'package:flutter_test/flutter_test.dart';
import 'package:rk_fuels/widgets/app_date_range_picker.dart';

void main() {
  group('normalizedAppDateRange', () {
    final firstDate = DateTime(2024);
    final lastDate = DateTime(2026, 4, 11);

    test('uses an existing from and to range', () {
      final range = normalizedAppDateRange(
        fromDate: DateTime(2026, 4, 1),
        toDate: DateTime(2026, 4, 10),
        firstDate: firstDate,
        lastDate: lastDate,
      );

      expect(range.start, DateTime(2026, 4, 1));
      expect(range.end, DateTime(2026, 4, 10));
    });

    test('uses a one-day range when only from is present', () {
      final range = normalizedAppDateRange(
        fromDate: DateTime(2026, 4, 3),
        firstDate: firstDate,
        lastDate: lastDate,
      );

      expect(range.start, DateTime(2026, 4, 3));
      expect(range.end, DateTime(2026, 4, 3));
    });

    test('uses a one-day range when only to is present', () {
      final range = normalizedAppDateRange(
        toDate: DateTime(2026, 4, 5),
        firstDate: firstDate,
        lastDate: lastDate,
      );

      expect(range.start, DateTime(2026, 4, 5));
      expect(range.end, DateTime(2026, 4, 5));
    });

    test('clamps fallback and selected dates inside picker bounds', () {
      final range = normalizedAppDateRange(
        fromDate: DateTime(2023, 12, 31),
        toDate: DateTime(2026, 5),
        firstDate: firstDate,
        lastDate: lastDate,
        fallbackDate: DateTime(2027),
      );

      expect(range.start, DateTime(2024));
      expect(range.end, DateTime(2026, 4, 11));
    });

    test('sorts reversed ranges', () {
      final range = normalizedAppDateRange(
        fromDate: DateTime(2026, 4, 9),
        toDate: DateTime(2026, 4, 2),
        firstDate: firstDate,
        lastDate: lastDate,
      );

      expect(range.start, DateTime(2026, 4, 2));
      expect(range.end, DateTime(2026, 4, 9));
    });
  });
}
