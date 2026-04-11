String salesEntryApiDate(DateTime date) {
  final dateOnly = DateTime(date.year, date.month, date.day);
  final month = dateOnly.month.toString().padLeft(2, '0');
  final day = dateOnly.day.toString().padLeft(2, '0');
  return '${dateOnly.year}-$month-$day';
}

bool _isApiDateShape(String value) {
  if (value.length != 10 || value[4] != '-' || value[7] != '-') {
    return false;
  }
  final digits = '${value.substring(0, 4)}${value.substring(5, 7)}'
      '${value.substring(8, 10)}';
  return int.tryParse(digits) != null;
}

DateTime? _parseApiDate(String raw) {
  final value = raw.trim();
  if (!_isApiDateShape(value)) {
    return null;
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return null;
  }
  final dateOnly = DateTime(parsed.year, parsed.month, parsed.day);
  return salesEntryApiDate(dateOnly) == value ? dateOnly : null;
}

String resolveDefaultSalesEntryDate(
  Iterable<String> existingEntryDates, {
  required DateTime today,
}) {
  final todayOnly = DateTime(today.year, today.month, today.day);
  DateTime? latestEntryDate;

  for (final rawDate in existingEntryDates) {
    final parsed = _parseApiDate(rawDate);
    if (parsed == null || parsed.isAfter(todayOnly)) {
      continue;
    }
    if (latestEntryDate == null || parsed.isAfter(latestEntryDate)) {
      latestEntryDate = parsed;
    }
  }

  final nextDate =
      latestEntryDate == null
          ? todayOnly
          : latestEntryDate.add(const Duration(days: 1));
  return salesEntryApiDate(nextDate.isAfter(todayOnly) ? todayOnly : nextDate);
}
