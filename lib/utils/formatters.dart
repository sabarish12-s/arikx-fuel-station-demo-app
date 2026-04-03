import 'package:flutter/material.dart';

String formatCurrency(double value) => 'Rs ${value.toStringAsFixed(2)}';

String formatLiters(double value) => '${value.toStringAsFixed(2)} L';

String formatCompactNumber(double value) => value.toStringAsFixed(0);

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
