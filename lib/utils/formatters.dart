import 'package:flutter/material.dart';

String formatCurrency(double value) => 'Rs ${value.toStringAsFixed(2)}';

String formatLiters(double value) => '${value.toStringAsFixed(2)} L';

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
  final baseLabel =
      label != null && label.trim().isNotEmpty
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
