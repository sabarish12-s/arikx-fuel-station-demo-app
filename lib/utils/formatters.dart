import 'package:flutter/material.dart';

const String _nbsp = '\u00A0';

String _indianCommas(String digits) {
  if (digits.length <= 3) return digits;
  final last3 = digits.substring(digits.length - 3);
  final rest = digits.substring(0, digits.length - 3);
  final buf = StringBuffer();
  final start = rest.length % 2;
  if (start > 0) buf.write(rest.substring(0, start));
  for (int i = start; i < rest.length; i += 2) {
    if (buf.isNotEmpty) buf.write(',');
    buf.write(rest.substring(i, i + 2));
  }
  return '${buf.isEmpty ? '' : '$buf,'}$last3';
}

String formatCurrency(double value) {
  final isNeg = value < 0;
  final abs = value.abs();
  final intPart = abs.truncate();
  final dec = (abs - intPart).toStringAsFixed(2).substring(1); // '.XX'
  return '${isNeg ? '-' : ''}Rs$_nbsp${_indianCommas(intPart.toString())}$dec';
}

String formatLiters(double value) => '${value.toStringAsFixed(2)}${_nbsp}L';
String formatPricePerLiter(double value) =>
    '${formatCurrency(value)}/${_nbsp}L';
String formatDensity(double value) =>
    '${value.toStringAsFixed(3)}${_nbsp}kg/m3';

String formatCompactNumber(double value) => value.toStringAsFixed(0);

const Map<String, String> _pumpSideNames = {
  'pump1': 'road side',
  'pump2': 'middle',
  'pump3': 'office side',
};

String _defaultPumpName(String pumpId) {
  switch (pumpId.toLowerCase()) {
    case 'pump1':
      return 'Pump 1';
    case 'pump2':
      return 'Pump 2';
    case 'pump3':
      return 'Pump 3';
    default:
      return pumpId;
  }
}

String formatPumpLabel(String pumpId, [String? label]) {
  final normalizedId = pumpId.trim().toLowerCase();
  final baseLabel = label != null && label.trim().isNotEmpty
      ? label.trim()
      : _defaultPumpName(normalizedId);
  final sideName = _pumpSideNames[normalizedId];
  if (sideName == null || sideName.isEmpty) {
    return baseLabel;
  }

  final suffix = '($sideName)';
  if (baseLabel.toLowerCase().contains(suffix.toLowerCase())) {
    return baseLabel;
  }
  return '$baseLabel $suffix';
}

String formatShiftLabel(String shift) {
  switch (shift) {
    case 'morning':
      return 'Morning';
    case 'afternoon':
      return 'Afternoon';
    case 'night':
      return 'Night';
    default:
      return shift;
  }
}

String formatDateLabel(String raw) {
  final date = DateTime.tryParse(raw);
  if (date == null) {
    return raw;
  }
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

String formatDateTimeLabel(String raw) {
  final date = DateTime.tryParse(raw);
  if (date == null) {
    return raw;
  }
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final hour24 = date.hour;
  final hour12 = hour24 == 0
      ? 12
      : hour24 > 12
      ? hour24 - 12
      : hour24;
  final minute = date.minute.toString().padLeft(2, '0');
  final meridiem = hour24 >= 12 ? 'PM' : 'AM';
  return '${months[date.month - 1]} ${date.day}, ${date.year} $hour12:$minute $meridiem';
}

String formatWeekdayLabel(String raw) {
  final date = DateTime.tryParse(raw);
  if (date == null) {
    return '';
  }
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  return weekdays[date.weekday - 1];
}

String currentMonthKey() {
  final now = DateTime.now();
  final month = now.month.toString().padLeft(2, '0');
  return '${now.year}-$month';
}

Color colorFromHex(String value) {
  final String hex = value.replaceAll('#', '');
  final String normalized = hex.length == 6 ? 'FF$hex' : hex;
  return Color(int.parse(normalized, radix: 16));
}
