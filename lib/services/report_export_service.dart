import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/domain_models.dart';

class StockReportRow {
  const StockReportRow({
    required this.date,
    required this.eventType,
    required this.stockInwards,
    required this.sales,
    required this.manualStock,
    required this.runningBalance,
    required this.details,
  });

  final String date;
  final String eventType;
  final double stockInwards;
  final double sales;
  final double? manualStock;
  final double runningBalance;
  final String details;
}

class StockReportSection {
  const StockReportSection({
    required this.label,
    required this.rows,
    required this.totalInwards,
    required this.totalSales,
    required this.closingBalance,
  });

  final String label;
  final List<StockReportRow> rows;
  final double totalInwards;
  final double totalSales;
  final double closingBalance;
}

class ReportExportService {
  static const MethodChannel _downloadsChannel = MethodChannel(
    'com.rk.fuels.rk_fuels/downloads',
  );

  static const List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const List<String> _shortMonths = [
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

  String _monthLabel(String key) {
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

  String _row(List<dynamic> cells) => cells.map(_csvVal).join(',');

  Future<String> _saveCsvToDownloads({
    required String fileName,
    required String contents,
    required String notificationTitle,
    required String notificationBody,
  }) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final savedLocation = await _downloadsChannel
          .invokeMethod<String>('saveTextFileToDownloads', <String, dynamic>{
            'fileName': fileName,
            'mimeType': 'text/csv',
            'text': contents,
            'notificationTitle': notificationTitle,
            'notificationBody': notificationBody,
          });
      if (savedLocation != null && savedLocation.isNotEmpty) {
        return savedLocation;
      }
    }

    Directory? downloadsDirectory;
    try {
      downloadsDirectory = await getDownloadsDirectory();
    } catch (_) {
      downloadsDirectory = null;
    }
    final directory =
        downloadsDirectory ?? await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(contents, flush: true);
    return file.path;
  }

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

  String _safeTitle(String title) {
    return title.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }

  String _buildReportCsv({
    required MonthlyReportModel report,
    String fromLabel = '',
    String toLabel = '',
  }) {
    final buffer = StringBuffer();

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

    final byMonth = <String, List<TrendPointModel>>{};
    for (final point in report.trend) {
      final key =
          point.date.length >= 7 ? point.date.substring(0, 7) : point.date;
      byMonth.putIfAbsent(key, () => []).add(point);
    }
    final sortedKeys = byMonth.keys.toList()..sort();

    double gtRevenue = 0;
    double gtCollected = 0;
    double gtProfit = 0;
    double gtPetrol = 0;
    double gtDiesel = 0;
    double gtTwoT = 0;
    int gtEntries = 0;

    for (final monthKey in sortedKeys) {
      final points = byMonth[monthKey]!;
      final label = _monthLabel(monthKey);
      final upperLabel = label.toUpperCase();

      buffer.writeln();
      buffer.writeln('=== $label ===');
      buffer.writeln(_row(_colHeaders));

      double mRevenue = 0;
      double mCollected = 0;
      double mProfit = 0;
      double mPetrol = 0;
      double mDiesel = 0;
      double mTwoT = 0;
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

      buffer.writeln(
        _row([
          '$upperLabel TOTAL',
          mRevenue.toStringAsFixed(2),
          mCollected.toStringAsFixed(2),
          mProfit.toStringAsFixed(2),
          mPetrol.toStringAsFixed(2),
          mDiesel.toStringAsFixed(2),
          mTwoT.toStringAsFixed(2),
          mEntries.toString(),
        ]),
      );

      gtRevenue += mRevenue;
      gtCollected += mCollected;
      gtProfit += mProfit;
      gtPetrol += mPetrol;
      gtDiesel += mDiesel;
      gtTwoT += mTwoT;
      gtEntries += mEntries;
    }

    if (sortedKeys.length > 1) {
      buffer.writeln();
      buffer.writeln('=== GRAND TOTAL ===');
      buffer.writeln(_row(_colHeaders));
      buffer.writeln(
        _row([
          'ALL MONTHS',
          gtRevenue.toStringAsFixed(2),
          gtCollected.toStringAsFixed(2),
          gtProfit.toStringAsFixed(2),
          gtPetrol.toStringAsFixed(2),
          gtDiesel.toStringAsFixed(2),
          gtTwoT.toStringAsFixed(2),
          gtEntries.toString(),
        ]),
      );
    }

    return buffer.toString();
  }

  String _buildStockReportCsv({
    required List<StockReportSection> sections,
    String fromLabel = '',
    String toLabel = '',
  }) {
    final buffer = StringBuffer();

    buffer.writeln('RK Fuels - Stock Report');
    if (fromLabel.isNotEmpty && toLabel.isNotEmpty) {
      buffer.writeln('Period: $fromLabel to $toLabel');
    }

    for (final section in sections) {
      buffer.writeln();
      buffer.writeln('=== ${section.label.toUpperCase()} ===');
      buffer.writeln(
        _row([
          'Date',
          'Event',
          'Stock Inwards (L)',
          'Sales (L)',
          'Manual Stock (L)',
          'Running Balance (L)',
          'Details',
        ]),
      );

      for (final row in section.rows) {
        buffer.writeln(
          _row([
            _formatRowDate(row.date),
            row.eventType,
            row.stockInwards.toStringAsFixed(2),
            row.sales.toStringAsFixed(2),
            row.manualStock?.toStringAsFixed(2) ?? '',
            row.runningBalance.toStringAsFixed(2),
            row.details,
          ]),
        );
      }

      buffer.writeln(
        _row([
          '${section.label.toUpperCase()} TOTAL',
          '',
          section.totalInwards.toStringAsFixed(2),
          section.totalSales.toStringAsFixed(2),
          '',
          section.closingBalance.toStringAsFixed(2),
          '',
        ]),
      );
    }

    return buffer.toString();
  }

  Future<File> exportReport({
    required MonthlyReportModel report,
    required String title,
    String fromLabel = '',
    String toLabel = '',
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/${_safeTitle(title)}.csv');
    final contents = _buildReportCsv(
      report: report,
      fromLabel: fromLabel,
      toLabel: toLabel,
    );
    await file.writeAsString(contents, flush: true);
    return file;
  }

  Future<String> saveReportToDownloads({
    required MonthlyReportModel report,
    required String title,
    String fromLabel = '',
    String toLabel = '',
  }) async {
    final fileName = '${_safeTitle(title)}.csv';
    final contents = _buildReportCsv(
      report: report,
      fromLabel: fromLabel,
      toLabel: toLabel,
    );
    return _saveCsvToDownloads(
      fileName: fileName,
      contents: contents,
      notificationTitle: 'Sales report downloaded',
      notificationBody: fileName,
    );
  }

  Future<File> exportStockReport({
    required List<StockReportSection> sections,
    required String title,
    String fromLabel = '',
    String toLabel = '',
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/${_safeTitle(title)}.csv');
    final contents = _buildStockReportCsv(
      sections: sections,
      fromLabel: fromLabel,
      toLabel: toLabel,
    );
    await file.writeAsString(contents, flush: true);
    return file;
  }

  Future<String> saveStockReportToDownloads({
    required List<StockReportSection> sections,
    required String title,
    String fromLabel = '',
    String toLabel = '',
  }) async {
    final fileName = '${_safeTitle(title)}.csv';
    final contents = _buildStockReportCsv(
      sections: sections,
      fromLabel: fromLabel,
      toLabel: toLabel,
    );
    return _saveCsvToDownloads(
      fileName: fileName,
      contents: contents,
      notificationTitle: 'Stock report downloaded',
      notificationBody: fileName,
    );
  }

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
