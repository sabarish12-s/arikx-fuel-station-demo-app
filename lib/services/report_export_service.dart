import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/domain_models.dart';

class ReportExportService {
  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static const List<String> _shortMonths = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _monthLabel(String key) {
    // key = 'yyyy-MM'
    final parts = key.split('-');
    if (parts.length < 2) return key;
    final m = (int.tryParse(parts[1]) ?? 1).clamp(1, 12);
    return '${_monthNames[m - 1]} ${parts[0]}';
  }

  String _formatRowDate(String raw) {
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    return '${d.day.toString().padLeft(2, '0')} ${_shortMonths[d.month - 1]} ${d.year}';
  }

  String _csvVal(dynamic value) {
    final s = value.toString();
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  String _row(List<dynamic> cells) =>
      cells.map(_csvVal).join(',');

  static const List<String> _colHeaders = [
    'Date',
    'Sales (Rs)',
    'Collected (Rs)',
    'Profit (Rs)',
    'Petrol Sold (L)',
    'Diesel Sold (L)',
    '2T Oil Sold (L)',
    'Entries',
  ];

  List<dynamic> _pointRow(TrendPointModel p) => [
    _formatRowDate(p.date),
    p.revenue.toStringAsFixed(2),
    p.paymentTotal.toStringAsFixed(2),
    p.profit.toStringAsFixed(2),
    p.petrolSold.toStringAsFixed(2),
    p.dieselSold.toStringAsFixed(2),
    p.twoTSold.toStringAsFixed(2),
    p.entries.toString(),
  ];

  Future<File> exportReport({
    required MonthlyReportModel report,
    required String title,
    String fromLabel = '',
    String toLabel = '',
  }) async {
    final buffer = StringBuffer();

    // ── Report title block ──────────────────────────────────────────────────
    buffer.writeln('RK Fuels - Sales Report');
    if (fromLabel.isNotEmpty && toLabel.isNotEmpty) {
      buffer.writeln('Period: $fromLabel to $toLabel');
    } else if (report.fromDate.isNotEmpty && report.toDate.isNotEmpty) {
      buffer.writeln(
        'Period: ${_formatRowDate(report.fromDate)} to ${_formatRowDate(report.toDate)}',
      );
    } else {
      buffer.writeln('Month: ${report.month}');
    }

    // ── Group trend points by calendar month ────────────────────────────────
    final Map<String, List<TrendPointModel>> byMonth = {};
    for (final point in report.trend) {
      final key =
          point.date.length >= 7 ? point.date.substring(0, 7) : point.date;
      byMonth.putIfAbsent(key, () => []).add(point);
    }
    final sortedKeys = byMonth.keys.toList()..sort();

    // Grand total accumulators
    double gtRevenue = 0, gtCollected = 0, gtProfit = 0;
    double gtPetrol = 0, gtDiesel = 0, gtTwoT = 0;
    int gtEntries = 0;

    for (final monthKey in sortedKeys) {
      final points = byMonth[monthKey]!;
      final label = _monthLabel(monthKey);
      final upperLabel = label.toUpperCase();

      // Month section header
      buffer.writeln();
      buffer.writeln('=== $label ===');
      buffer.writeln(_row(_colHeaders));

      // Daily rows + monthly accumulators
      double mRevenue = 0, mCollected = 0, mProfit = 0;
      double mPetrol = 0, mDiesel = 0, mTwoT = 0;
      int mEntries = 0;

      for (final p in points) {
        buffer.writeln(_row(_pointRow(p)));
        mRevenue += p.revenue;
        mCollected += p.paymentTotal;
        mProfit += p.profit;
        mPetrol += p.petrolSold;
        mDiesel += p.dieselSold;
        mTwoT += p.twoTSold;
        mEntries += p.entries;
      }

      // Monthly subtotal row
      buffer.writeln(_row([
        '$upperLabel TOTAL',
        mRevenue.toStringAsFixed(2),
        mCollected.toStringAsFixed(2),
        mProfit.toStringAsFixed(2),
        mPetrol.toStringAsFixed(2),
        mDiesel.toStringAsFixed(2),
        mTwoT.toStringAsFixed(2),
        mEntries.toString(),
      ]));

      // Accumulate grand totals
      gtRevenue += mRevenue;
      gtCollected += mCollected;
      gtProfit += mProfit;
      gtPetrol += mPetrol;
      gtDiesel += mDiesel;
      gtTwoT += mTwoT;
      gtEntries += mEntries;
    }

    // ── Grand total ─────────────────────────────────────────────────────────
    if (sortedKeys.length > 1) {
      buffer.writeln();
      buffer.writeln('=== GRAND TOTAL ===');
      buffer.writeln(_row(_colHeaders));
      buffer.writeln(_row([
        'ALL MONTHS',
        gtRevenue.toStringAsFixed(2),
        gtCollected.toStringAsFixed(2),
        gtProfit.toStringAsFixed(2),
        gtPetrol.toStringAsFixed(2),
        gtDiesel.toStringAsFixed(2),
        gtTwoT.toStringAsFixed(2),
        gtEntries.toString(),
      ]));
    }

    final directory = await getApplicationDocumentsDirectory();
    final safeTitle = title.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final file = File('${directory.path}/$safeTitle.csv');
    await file.writeAsString(buffer.toString(), flush: true);
    return file;
  }

  /// Backward-compatible wrapper used by existing screen code.
  Future<File> exportMonthlyReport({
    required MonthlyReportModel report,
    required String title,
  }) {
    return exportReport(report: report, title: title);
  }

  Future<void> shareFile(File file, {String? text}) async {
    await Share.shareXFiles([XFile(file.path)], text: text);
  }
}
