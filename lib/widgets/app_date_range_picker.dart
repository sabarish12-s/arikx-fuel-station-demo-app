import 'package:flutter/material.dart';

import 'clay_widgets.dart';

DateTime appDateOnly(DateTime date) =>
    DateTime(date.year, date.month, date.day);

DateTime clampAppDate(
  DateTime date, {
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  final first = appDateOnly(firstDate);
  final last = appDateOnly(lastDate);
  if (last.isBefore(first)) {
    throw ArgumentError.value(lastDate, 'lastDate', 'Must be after firstDate.');
  }

  final day = appDateOnly(date);
  if (day.isBefore(first)) return first;
  if (day.isAfter(last)) return last;
  return day;
}

DateTimeRange normalizedAppDateRange({
  DateTime? fromDate,
  DateTime? toDate,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTime? fallbackDate,
}) {
  final fallback = clampAppDate(
    fallbackDate ?? DateTime.now(),
    firstDate: firstDate,
    lastDate: lastDate,
  );
  var start = fromDate == null
      ? (toDate == null
            ? fallback
            : clampAppDate(toDate, firstDate: firstDate, lastDate: lastDate))
      : clampAppDate(fromDate, firstDate: firstDate, lastDate: lastDate);
  var end = toDate == null
      ? start
      : clampAppDate(toDate, firstDate: firstDate, lastDate: lastDate);

  if (end.isBefore(start)) {
    final previousStart = start;
    start = end;
    end = previousStart;
  }

  return DateTimeRange(start: start, end: end);
}

Future<DateTimeRange?> showAppDateRangePicker({
  required BuildContext context,
  DateTime? fromDate,
  DateTime? toDate,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTime? fallbackDate,
  String helpText = 'Select date range',
}) {
  final first = appDateOnly(firstDate);
  final last = appDateOnly(lastDate);
  final initialRange = normalizedAppDateRange(
    fromDate: fromDate,
    toDate: toDate,
    firstDate: first,
    lastDate: last,
    fallbackDate: fallbackDate,
  );

  return showDateRangePicker(
    context: context,
    firstDate: first,
    lastDate: last,
    initialDateRange: initialRange,
    helpText: helpText,
    builder: (context, child) {
      final theme = Theme.of(context);
      return Theme(
        data: theme.copyWith(
          colorScheme: theme.colorScheme.copyWith(
            primary: kClayHeroStart,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: kClayPrimary,
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      );
    },
  );
}
