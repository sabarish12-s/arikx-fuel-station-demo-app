import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/auth_models.dart';
import '../models/domain_models.dart';
import '../services/api_response_cache.dart';
import '../services/auth_service.dart';
import '../services/credit_service.dart';
import '../services/inventory_service.dart';
import '../services/management_service.dart';
import '../services/report_export_service.dart';
import '../utils/formatters.dart';
import '../utils/user_facing_errors.dart';
import '../widgets/app_date_range_picker.dart';
import '../widgets/app_bottom_nav_bar.dart';
import '../widgets/app_logo.dart';
import '../widgets/clay_widgets.dart';
import '../widgets/responsive_text.dart';
import 'credit_ledger_screen.dart';
import 'management_shell.dart';
import 'sales_shell.dart';

class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportViewData {
  const _MonthlyReportViewData({
    required this.report,
    required this.creditOutstandingTotal,
    required this.paymentBreakdown,
  });

  final MonthlyReportModel report;
  final double creditOutstandingTotal;
  final Map<String, double> paymentBreakdown;
}

enum _ExportReportType { sales, stock }

class _StockTimelineEvent {
  const _StockTimelineEvent({
    required this.date,
    required this.type,
    required this.eventAt,
    required this.values,
    required this.details,
  });

  final String date;
  final String type;
  final String eventAt;
  final Map<String, double> values;
  final String details;
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  final ManagementService _managementService = ManagementService();
  final CreditService _creditService = CreditService();
  final InventoryService _inventoryService = InventoryService();
  final ReportExportService _reportExportService = ReportExportService();
  static const List<String> _monthNames = <String>[
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
  late Future<_MonthlyReportViewData> _future;
  late final StreamSubscription<ApiResponseCacheUpdate> _cacheSubscription;
  String _filterMonth = currentMonthKey();
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _filterByDateRange = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _future = _fetchReport();
    _cacheSubscription = ApiResponseCache.updates.listen((update) {
      if (!mounted || !update.background) {
        return;
      }
      if (!update.path.startsWith('/management/reports/monthly') &&
          !update.path.startsWith('/credits/summary')) {
        return;
      }
      setState(() {
        _future = _fetchReport();
      });
    });
  }

  @override
  void dispose() {
    _cacheSubscription.cancel();
    super.dispose();
  }

  void _showDownloadSuccess(String label) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          backgroundColor: const Color(0xFF17326B),
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$label downloaded',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  Future<_MonthlyReportViewData> _fetchReport({
    bool forceRefresh = false,
  }) async {
    final monthParam = _filterByDateRange ? null : _filterMonth;
    final fromDateParam = _filterByDateRange && _fromDate != null
        ? _toApiDate(_fromDate!)
        : null;
    final toDateParam = _filterByDateRange && _toDate != null
        ? _toApiDate(_toDate!)
        : null;
    final reportFuture = _managementService.fetchMonthlyReport(
      month: monthParam,
      fromDate: fromDateParam,
      toDate: toDateParam,
      forceRefresh: forceRefresh,
    );
    final creditSummaryFuture = _fetchCreditSummary(forceRefresh: forceRefresh);

    final report = await reportFuture;
    final creditSummary = await creditSummaryFuture;
    return _MonthlyReportViewData(
      report: report,
      creditOutstandingTotal:
          creditSummary?.openBalanceTotal ?? report.creditTotal,
      paymentBreakdown: report.paymentBreakdown,
    );
  }

  Future<CreditLedgerSummaryModel?> _fetchCreditSummary({
    bool forceRefresh = false,
  }) async {
    try {
      final summary = await _creditService.fetchSummary(
        forceRefresh: forceRefresh,
      );
      return summary;
    } catch (_) {
      return null;
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _fetchReport(forceRefresh: true);
    });
    await _future;
  }

  String _toApiDate(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }

  String get _activeFilterLabel {
    if (_filterByDateRange) {
      if (_fromDate == null || _toDate == null) {
        return 'Custom Range';
      }
      return '${_fmtShort(_fromDate!)} - ${_fmtShort(_toDate!)}';
    }
    final parts = _filterMonth.split('-');
    if (parts.length != 2) return _filterMonth;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null || month < 1 || month > 12) {
      return _filterMonth;
    }
    return '${_shortMonths[month - 1]} $year';
  }

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

  String _fmtDt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_shortMonths[d.month - 1]} ${d.year}';

  String _fmtShort(DateTime d) => '${_shortMonths[d.month - 1]} ${d.day}';

  Future<void> _openFilterDialog() async {
    final today = DateTime.now();
    bool byRange = _filterByDateRange;
    final parts = _filterMonth.split('-');
    int selYear = int.tryParse(parts.firstOrNull ?? '') ?? today.year;
    int selMonth =
        int.tryParse(parts.length > 1 ? parts[1] : '') ?? today.month;
    DateTime? fromDt = _fromDate;
    DateTime? toDt = _toDate;
    final now = DateTime(today.year, today.month, today.day);

    String formatDialogDate(DateTime? dt) {
      if (dt == null) return 'Tap to choose';
      return formatDateLabel(_toApiDate(dt));
    }

    String formatDialogRange() {
      if (fromDt == null || toDt == null) return 'Tap to choose';
      return '${formatDialogDate(fromDt)} to ${formatDialogDate(toDt)}';
    }

    bool matchesQuickRange(int dayCount) {
      if (fromDt == null || toDt == null) return false;
      final expectedFrom = now.subtract(Duration(days: dayCount - 1));
      return DateTime(fromDt!.year, fromDt!.month, fromDt!.day) ==
              expectedFrom &&
          DateTime(toDt!.year, toDt!.month, toDt!.day) == now;
    }

    void applyQuickRange(StateSetter set, int dayCount) {
      set(() {
        byRange = true;
        fromDt = now.subtract(Duration(days: dayCount - 1));
        toDt = now;
      });
    }

    Future<void> pickRange(
      BuildContext pickerContext,
      StateSetter setDialogState,
    ) async {
      final picked = await showAppDateRangePicker(
        context: pickerContext,
        fromDate: fromDt,
        toDate: toDt,
        firstDate: DateTime(2024),
        lastDate: today,
        helpText: 'Select report range',
      );
      if (picked == null) return;
      setDialogState(() {
        byRange = true;
        fromDt = picked.start;
        toDt = picked.end;
      });
    }

    final applied = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final years = List<int>.generate(
              today.year - 2024 + 1,
              (i) => today.year - i,
            );

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 24,
              ),
              title: const Text('Filter Reports'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFECEFF8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          _ReportToggleTab(
                            label: 'By Month',
                            selected: !byRange,
                            onTap: () => setDialogState(() => byRange = false),
                          ),
                          _ReportToggleTab(
                            label: 'Date Range',
                            selected: byRange,
                            onTap: () => setDialogState(() => byRange = true),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (!byRange) ...[
                      _ReportDropdownField<int>(
                        label: 'Year',
                        icon: Icons.event_note_rounded,
                        value: selYear,
                        items: years
                            .map(
                              (y) => DropdownMenuItem<int>(
                                value: y,
                                child: Text('$y'),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setDialogState(() => selYear = v);
                        },
                      ),
                      const SizedBox(height: 12),
                      _ReportDropdownField<int>(
                        label: 'Month',
                        icon: Icons.calendar_month_rounded,
                        value: selMonth,
                        items: List.generate(
                          _monthNames.length,
                          (i) => DropdownMenuItem<int>(
                            value: i + 1,
                            child: Text(_monthNames[i]),
                          ),
                        ),
                        onChanged: (v) {
                          if (v == null) return;
                          setDialogState(() => selMonth = v);
                        },
                      ),
                    ] else ...[
                      _ReportDateTile(
                        label: 'Date Range',
                        value: formatDialogRange(),
                        selected: false,
                        onTap: () => pickRange(dialogContext, setDialogState),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _PresetPill(
                              label: 'Last 7 Days',
                              selected: matchesQuickRange(7),
                              onTap: () => applyQuickRange(setDialogState, 7),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _PresetPill(
                              label: 'Last 30 Days',
                              selected: matchesQuickRange(30),
                              onTap: () => applyQuickRange(setDialogState, 30),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              actions: [
                SizedBox(
                  width: double.maxFinite,
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text('Cancel'),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: () {
                          if (byRange && (fromDt == null || toDt == null)) {
                            return;
                          }
                          Navigator.of(dialogContext).pop(true);
                        },
                        icon: const Icon(Icons.filter_alt_rounded),
                        label: const Text('Apply'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (applied != true) return;

    setState(() {
      _filterByDateRange = byRange;
      if (byRange) {
        _fromDate = fromDt;
        _toDate = toDt;
      } else {
        _filterMonth = '$selYear-${selMonth.toString().padLeft(2, '0')}';
        _fromDate = null;
        _toDate = null;
      }
      _future = _fetchReport();
    });
  }

  List<TrendPointModel> _latestDailyPreview(List<TrendPointModel> points) {
    final sorted = [...points]
      ..sort((left, right) => right.date.compareTo(left.date));
    return sorted.take(3).toList();
  }

  Future<void> _openDailyBreakdown(List<TrendPointModel> points) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _DailyBreakdownScreen(
          points: points,
          initialFromDate: _fromDate,
          initialToDate: _toDate,
        ),
      ),
    );
  }

  Future<void> _openExportDialog({required bool shareMode}) async {
    final now = DateTime.now();
    DateTime exportFrom = DateTime(now.year, now.month, 1);
    DateTime exportTo = DateTime(now.year, now.month + 1, 0);
    _ExportReportType reportType = _ExportReportType.sales;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> pickRange() async {
              final picked = await showAppDateRangePicker(
                context: dialogContext,
                fromDate: exportFrom,
                toDate: exportTo,
                firstDate: DateTime(2024),
                lastDate: DateTime(2100),
                helpText: shareMode
                    ? 'Select share range'
                    : 'Select export range',
              );
              if (picked != null) {
                setDialogState(() {
                  exportFrom = picked.start;
                  exportTo = picked.end;
                });
              }
            }

            void applyPreset(DateTime from, DateTime to) => setDialogState(() {
              exportFrom = from;
              exportTo = to;
            });

            final tMF = DateTime(now.year, now.month, 1);
            final tMT = DateTime(now.year, now.month + 1, 0);
            final lMF = DateTime(now.year, now.month - 1, 1);
            final lMT = DateTime(now.year, now.month, 0);

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 24,
              ),
              title: Text(shareMode ? 'Share Report' : 'Export Report'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Choose a date range for the export.',
                      style: TextStyle(color: Color(0xFF55606E)),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Report type',
                      style: TextStyle(
                        color: Color(0xFF55606E),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<_ExportReportType>(
                      segments: const [
                        ButtonSegment<_ExportReportType>(
                          value: _ExportReportType.sales,
                          label: Text('Sales Report'),
                          icon: Icon(Icons.bar_chart_rounded),
                        ),
                        ButtonSegment<_ExportReportType>(
                          value: _ExportReportType.stock,
                          label: Text('Stock Report'),
                          icon: Icon(Icons.inventory_2_rounded),
                        ),
                      ],
                      selected: <_ExportReportType>{reportType},
                      onSelectionChanged: (selection) {
                        setDialogState(() {
                          reportType = selection.first;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          label: const Text('This Month'),
                          onPressed: () => applyPreset(tMF, tMT),
                        ),
                        ActionChip(
                          label: const Text('Last Month'),
                          onPressed: () => applyPreset(lMF, lMT),
                        ),
                        ActionChip(
                          label: const Text('YTD'),
                          onPressed: () =>
                              applyPreset(DateTime(now.year, 1, 1), now),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _ExportDateTile(
                      label: 'DATE RANGE',
                      value: '${_fmtDt(exportFrom)} to ${_fmtDt(exportTo)}',
                      onTap: pickRange,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: () async {
                    if (exportTo.isBefore(exportFrom)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Color(0xFFB91C1C),
                          content: Text(
                            '"To" date must be on or after "From" date.',
                          ),
                        ),
                      );
                      return;
                    }
                    Navigator.of(dialogContext).pop();
                    if (reportType == _ExportReportType.sales) {
                      await _runExport(
                        from: exportFrom,
                        to: exportTo,
                        shareMode: shareMode,
                      );
                    } else {
                      await _runStockExport(
                        from: exportFrom,
                        to: exportTo,
                        shareMode: shareMode,
                      );
                    }
                  },
                  icon: Icon(
                    shareMode
                        ? Icons.share_rounded
                        : (reportType == _ExportReportType.stock
                              ? Icons.inventory_2_rounded
                              : Icons.download_rounded),
                  ),
                  label: Text(
                    shareMode
                        ? 'Share CSV'
                        : (reportType == _ExportReportType.stock
                              ? 'Download CSV'
                              : 'Export CSV'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _runExport({
    required DateTime from,
    required DateTime to,
    required bool shareMode,
  }) async {
    setState(() => _exporting = true);
    try {
      final fromStr = _toApiDate(from);
      final toStr = _toApiDate(to);
      final report = await _managementService.fetchMonthlyReport(
        fromDate: fromStr,
        toDate: toStr,
      );
      if (!mounted) return;
      final safeFrom = fromStr.replaceAll('-', '');
      final safeTo = toStr.replaceAll('-', '');
      final title = 'rk_fuels_report_${safeFrom}_$safeTo';
      if (!mounted) return;
      if (shareMode) {
        final file = await _reportExportService.exportReport(
          report: report,
          title: title,
          fromLabel: _fmtDt(from),
          toLabel: _fmtDt(to),
        );
        await _reportExportService.shareFile(
          file,
          text: 'RK Fuels report ${_fmtDt(from)} to ${_fmtDt(to)}',
        );
      } else {
        await _reportExportService.saveReportToDownloads(
          report: report,
          title: title,
          fromLabel: _fmtDt(from),
          toLabel: _fmtDt(to),
        );
        if (!mounted) return;
        _showDownloadSuccess('Sales report');
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFB91C1C),
          content: Text(userFacingErrorMessage(error)),
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  double _round2(double value) => double.parse(value.toStringAsFixed(2));

  List<ShiftEntryModel> _normalizeInventoryEntries(
    List<ShiftEntryModel> entries,
  ) {
    final latestByDate = <String, ShiftEntryModel>{};
    for (final entry in entries) {
      if (!entry.isFinalized) {
        continue;
      }
      final existing = latestByDate[entry.date];
      if (existing == null) {
        latestByDate[entry.date] = entry;
        continue;
      }
      if (entry.latestActivityTimestamp.compareTo(
            existing.latestActivityTimestamp,
          ) >=
          0) {
        latestByDate[entry.date] = entry;
      }
    }
    final normalized = latestByDate.values.toList()
      ..sort((left, right) => left.date.compareTo(right.date));
    return normalized;
  }

  List<StockReportSection> _buildStockReportSections({
    required List<InventoryStockSnapshotModel> snapshots,
    required List<ShiftEntryModel> entries,
    required List<DeliveryReceiptModel> deliveries,
    required DateTime from,
    required DateTime to,
  }) {
    final fromStr = _toApiDate(from);
    final toStr = _toApiDate(to);
    final normalizedEntries = _normalizeInventoryEntries(entries);
    final carrySnapshot =
        snapshots
            .where((snapshot) => snapshot.effectiveDate.compareTo(fromStr) < 0)
            .toList()
          ..sort((left, right) {
            final byDate = left.effectiveDate.compareTo(right.effectiveDate);
            if (byDate != 0) return byDate;
            final byCreatedAt = left.createdAt.compareTo(right.createdAt);
            if (byCreatedAt != 0) return byCreatedAt;
            return left.id.compareTo(right.id);
          });
    final startingSnapshot = carrySnapshot.isEmpty ? null : carrySnapshot.last;
    final startingStock = <String, double>{
      'petrol': _round2(startingSnapshot?.stock['petrol'] ?? 0),
      'diesel': _round2(startingSnapshot?.stock['diesel'] ?? 0),
      'two_t_oil': _round2(startingSnapshot?.stock['two_t_oil'] ?? 0),
    };
    final carryStartDate = startingSnapshot?.effectiveDate ?? '';

    for (final delivery in deliveries.where(
      (item) =>
          (carryStartDate.isEmpty ||
              item.date.compareTo(carryStartDate) >= 0) &&
          item.date.compareTo(fromStr) < 0,
    )) {
      for (final fuelTypeId in ['petrol', 'diesel', 'two_t_oil']) {
        startingStock[fuelTypeId] = _round2(
          (startingStock[fuelTypeId] ?? 0) +
              (delivery.quantities[fuelTypeId] ?? 0),
        );
      }
    }

    for (final entry in normalizedEntries.where(
      (item) =>
          (carryStartDate.isEmpty ||
              item.date.compareTo(carryStartDate) >= 0) &&
          item.date.compareTo(fromStr) < 0,
    )) {
      startingStock['petrol'] = _round2(
        (startingStock['petrol'] ?? 0) - entry.inventoryTotals.petrol,
      );
      startingStock['diesel'] = _round2(
        (startingStock['diesel'] ?? 0) - entry.inventoryTotals.diesel,
      );
      startingStock['two_t_oil'] = _round2(
        (startingStock['two_t_oil'] ?? 0) - entry.inventoryTotals.twoT,
      );
    }

    final events =
        <_StockTimelineEvent>[
          ...snapshots
              .where(
                (snapshot) =>
                    snapshot.effectiveDate.compareTo(fromStr) >= 0 &&
                    snapshot.effectiveDate.compareTo(toStr) <= 0,
              )
              .map(
                (snapshot) => _StockTimelineEvent(
                  date: snapshot.effectiveDate,
                  type: 'snapshot',
                  eventAt: snapshot.createdAt,
                  values: snapshot.stock,
                  details: [
                    if (snapshot.createdByName.trim().isNotEmpty)
                      'Set by ${snapshot.createdByName.trim()}',
                    if (snapshot.note.trim().isNotEmpty) snapshot.note.trim(),
                  ].join(' - '),
                ),
              ),
          ...deliveries
              .where(
                (delivery) =>
                    delivery.date.compareTo(fromStr) >= 0 &&
                    delivery.date.compareTo(toStr) <= 0,
              )
              .map(
                (delivery) => _StockTimelineEvent(
                  date: delivery.date,
                  type: 'delivery',
                  eventAt: delivery.createdAt,
                  values: delivery.quantities,
                  details: [
                    if (delivery.purchasedByName.trim().isNotEmpty)
                      'Purchased by ${delivery.purchasedByName.trim()}',
                    if (delivery.note.trim().isNotEmpty) delivery.note.trim(),
                  ].join(' - '),
                ),
              ),
          ...normalizedEntries
              .where(
                (entry) =>
                    entry.date.compareTo(fromStr) >= 0 &&
                    entry.date.compareTo(toStr) <= 0,
              )
              .map(
                (entry) => _StockTimelineEvent(
                  date: entry.date,
                  type: 'sale',
                  eventAt: entry.latestActivityTimestamp,
                  values: {
                    'petrol': entry.inventoryTotals.petrol,
                    'diesel': entry.inventoryTotals.diesel,
                    'two_t_oil': entry.inventoryTotals.twoT,
                  },
                  details: entry.varianceNote.trim().isEmpty
                      ? 'Approved sales entry'
                      : 'Approved sales entry - ${entry.varianceNote.trim()}',
                ),
              ),
        ]..sort((left, right) {
          final byDate = left.date.compareTo(right.date);
          if (byDate != 0) return byDate;
          const eventOrder = {'snapshot': 0, 'delivery': 1, 'sale': 2};
          final byType =
              (eventOrder[left.type] ?? 99) - (eventOrder[right.type] ?? 99);
          if (byType != 0) return byType;
          return left.eventAt.compareTo(right.eventAt);
        });

    List<StockReportSection> buildSections() {
      final configs = [
        {'key': 'petrol', 'label': 'Petrol'},
        {'key': 'diesel', 'label': 'Diesel'},
        {'key': 'two_t_oil', 'label': '2T Oil'},
      ];

      return configs.map((config) {
        final fuelKey = config['key']!;
        final label = config['label']!;
        var runningBalance = _round2(startingStock[fuelKey] ?? 0);
        var totalInwards = 0.0;
        var totalSales = 0.0;
        final rows = <StockReportRow>[];

        for (final event in events) {
          final value = _round2(event.values[fuelKey] ?? 0);
          if (event.type == 'snapshot') {
            runningBalance = value;
            rows.add(
              StockReportRow(
                date: event.date,
                eventType: 'Manual Stock Set',
                stockInwards: 0,
                sales: 0,
                manualStock: value,
                runningBalance: runningBalance,
                details: event.details,
              ),
            );
            continue;
          }
          if (event.type == 'delivery') {
            runningBalance = _round2(runningBalance + value);
            totalInwards = _round2(totalInwards + value);
            rows.add(
              StockReportRow(
                date: event.date,
                eventType: 'Delivery',
                stockInwards: value,
                sales: 0,
                manualStock: null,
                runningBalance: runningBalance,
                details: event.details,
              ),
            );
            continue;
          }
          totalSales = _round2(totalSales + value);
          runningBalance = _round2(runningBalance - value);
          rows.add(
            StockReportRow(
              date: event.date,
              eventType: 'Sale',
              stockInwards: 0,
              sales: value,
              manualStock: null,
              runningBalance: runningBalance,
              details: event.details,
            ),
          );
        }

        return StockReportSection(
          label: label,
          rows: rows,
          totalInwards: totalInwards,
          totalSales: totalSales,
          closingBalance: runningBalance,
        );
      }).toList();
    }

    return buildSections();
  }

  Future<void> _runStockExport({
    required DateTime from,
    required DateTime to,
    bool shareMode = false,
  }) async {
    setState(() => _exporting = true);
    try {
      final fromStr = _toApiDate(from);
      final toStr = _toApiDate(to);
      final snapshots = await _inventoryService.fetchStockSnapshots(
        toDate: toStr,
      );
      final carrySnapshot =
          snapshots
              .where(
                (snapshot) => snapshot.effectiveDate.compareTo(fromStr) < 0,
              )
              .toList()
            ..sort((left, right) {
              final byDate = left.effectiveDate.compareTo(right.effectiveDate);
              if (byDate != 0) return byDate;
              return left.createdAt.compareTo(right.createdAt);
            });
      final historyStartDate = carrySnapshot.isEmpty
          ? fromStr
          : carrySnapshot.last.effectiveDate;
      final entries = await _managementService.fetchEntries(
        fromDate: historyStartDate.compareTo(fromStr) <= 0
            ? historyStartDate
            : fromStr,
        toDate: toStr,
        summary: true,
      );
      final deliveries = await _inventoryService.fetchDeliveries();
      final sections = _buildStockReportSections(
        snapshots: snapshots,
        entries: entries,
        deliveries: deliveries,
        from: from,
        to: to,
      );
      final safeFrom = fromStr.replaceAll('-', '');
      final safeTo = toStr.replaceAll('-', '');
      final title = 'rk_fuels_stock_report_${safeFrom}_$safeTo';
      if (shareMode) {
        final file = await _reportExportService.exportStockReport(
          sections: sections,
          title: title,
          fromLabel: _fmtDt(from),
          toLabel: _fmtDt(to),
        );
        await _reportExportService.shareFile(
          file,
          text: 'RK Fuels stock report ${_fmtDt(from)} to ${_fmtDt(to)}',
        );
      } else {
        await _reportExportService.saveStockReportToDownloads(
          sections: sections,
          title: title,
          fromLabel: _fmtDt(from),
          toLabel: _fmtDt(to),
        );
        if (!mounted) {
          return;
        }
        _showDownloadSuccess('Stock report');
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFB91C1C),
          content: Text(userFacingErrorMessage(error)),
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<_MonthlyReportViewData>(
        future: _future,
        builder: (context, snapshot) {
          return ColoredBox(
            color: const Color(0xFFECEFF8),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                // ── Filter card ───────────────────────────────────────
                const SizedBox.shrink(),

                // ── Loading / error ───────────────────────────────────
                if (snapshot.connectionState != ConnectionState.done &&
                    !snapshot.hasData)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (snapshot.hasError && !snapshot.hasData)
                  Padding(
                    padding: const EdgeInsets.only(top: 80),
                    child: Center(
                      child: Text(userFacingErrorMessage(snapshot.error)),
                    ),
                  )
                else
                  ..._buildReport(snapshot.data!),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildReport(_MonthlyReportViewData data) {
    final report = data.report;
    final petrol = report.fuelBreakdown['petrol'] ?? 0;
    final diesel = report.fuelBreakdown['diesel'] ?? 0;
    final twoT = report.fuelBreakdown['two_t_oil'] ?? 0;
    final totalFuel = petrol + diesel + twoT;
    final cash = data.paymentBreakdown['cash'] ?? 0;
    final hpPay = data.paymentBreakdown['check'] ?? 0;
    final upi = data.paymentBreakdown['upi'] ?? 0;
    final credit = data.paymentBreakdown['credit'] ?? 0;
    final totalPayments = cash + hpPay + upi + credit;
    final maxFuelTrend = report.trend.fold<double>(
      0,
      (max, item) => [
        max,
        item.petrolSold,
        item.dieselSold,
      ].reduce((a, b) => a > b ? a : b),
    );
    final dailyPreview = _latestDailyPreview(report.trend);

    return [
      // ── Summary hero card ─────────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFF1A3A7A), Color(0xFF0D2460)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0D2460).withValues(alpha: 0.45),
              offset: const Offset(0, 10),
              blurRadius: 24,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reports',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _openFilterDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_month_rounded,
                          color: Colors.white70,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        OneLineScaleText(
                          _activeFilterLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white60,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 16),
            Row(
              children: [
                _SummaryCell(
                  label: 'Sales',
                  value: formatCurrency(report.revenue),
                ),
                const _SummarySep(),
                _SummaryCell(
                  label: 'Profit',
                  value: formatCurrency(report.profit),
                ),
              ],
            ),
            const SizedBox(height: 1),
            Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.1),
              margin: const EdgeInsets.symmetric(vertical: 10),
            ),
            Row(
              children: [
                _SummaryCell(
                  label: 'Petrol',
                  value: formatLiters(report.petrolSold),
                ),
                const _SummarySep(),
                _SummaryCell(
                  label: 'Diesel',
                  value: formatLiters(report.dieselSold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _SummaryCell(
                  label: '2T Oil',
                  value: formatLiters(report.twoTSold),
                ),
                const _SummarySep(),
                _SummaryCell(
                  label: 'Credits',
                  value: formatCurrency(data.creditOutstandingTotal),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _HeroActionBtn(
                    icon: Icons.download_rounded,
                    label: _exporting ? 'Preparing...' : 'Download',
                    onTap: _exporting
                        ? null
                        : () => _openExportDialog(shareMode: false),
                    filled: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _HeroActionBtn(
                    icon: Icons.share_rounded,
                    label: 'Share',
                    onTap: _exporting
                        ? null
                        : () => _openExportDialog(shareMode: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _HeroActionBtn(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Credits',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const CreditLedgerScreen(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),

      const SizedBox(height: 14),

      // ── Revenue Trend ─────────────────────────────────────────
      _ClayCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sales Trend',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A2561),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: report.trend.isEmpty
                  ? const Center(
                      child: Text(
                        'No trend data for this filter.',
                        style: TextStyle(color: Color(0xFF8A93B8)),
                      ),
                    )
                  : LineChart(
                      LineChartData(
                        minY: 0,
                        maxY: maxFuelTrend <= 0 ? 10 : maxFuelTrend * 1.2,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: maxFuelTrend <= 0
                              ? 5
                              : (maxFuelTrend * 1.2) / 4,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: const Color(0xFFD8DCF0),
                            strokeWidth: 1,
                            dashArray: [4, 4],
                          ),
                        ),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 52,
                              interval: maxFuelTrend <= 0
                                  ? 5
                                  : (maxFuelTrend * 1.2) / 4,
                              getTitlesWidget: (value, meta) => Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Text(
                                  '${_compactK(value)} L',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF8A93B8),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 26,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx < 0 || idx >= report.trend.length) {
                                  return const SizedBox.shrink();
                                }
                                if (report.trend.length > 6 &&
                                    idx.isOdd &&
                                    idx != report.trend.length - 1) {
                                  return const SizedBox.shrink();
                                }
                                final dt = DateTime.tryParse(
                                  report.trend[idx].date,
                                );
                                final lbl = dt == null
                                    ? report.trend[idx].date
                                    : '${dt.day}/${dt.month}';
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    lbl,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF8A93B8),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineTouchData: LineTouchData(
                          enabled: true,
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipItems: (spots) => spots.map((spot) {
                              final index = spot.x
                                  .toInt()
                                  .clamp(0, report.trend.length - 1)
                                  .toInt();
                              final point = report.trend[index];
                              final isPetrol = spot.barIndex == 0;
                              return LineTooltipItem(
                                isPetrol
                                    ? '${formatDateLabel(point.date)}\nPetrol ${formatLiters(spot.y)}'
                                    : 'Diesel ${formatLiters(spot.y)}',
                                TextStyle(
                                  color: isPetrol
                                      ? const Color(0xFF1A3A7A)
                                      : const Color(0xFF2AA878),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            isCurved: true,
                            color: const Color(0xFF1A3A7A),
                            barWidth: 2.5,
                            dotData: FlDotData(
                              show: report.trend.length <= 8,
                              getDotPainter: (spot, percent, bar, index) =>
                                  FlDotCirclePainter(
                                    radius: 4,
                                    color: const Color(0xFF1A3A7A),
                                    strokeWidth: 2,
                                    strokeColor: Colors.white,
                                  ),
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              color: const Color(
                                0xFF1A3A7A,
                              ).withValues(alpha: 0.10),
                            ),
                            spots: [
                              for (var i = 0; i < report.trend.length; i++)
                                FlSpot(
                                  i.toDouble(),
                                  report.trend[i].petrolSold,
                                ),
                            ],
                          ),
                          LineChartBarData(
                            isCurved: true,
                            color: const Color(0xFF2AA878),
                            barWidth: 2.5,
                            dotData: FlDotData(
                              show: report.trend.length <= 8,
                              getDotPainter: (spot, percent, bar, index) =>
                                  FlDotCirclePainter(
                                    radius: 4,
                                    color: const Color(0xFF2AA878),
                                    strokeWidth: 2,
                                    strokeColor: Colors.white,
                                  ),
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              color: const Color(
                                0xFF2AA878,
                              ).withValues(alpha: 0.08),
                            ),
                            spots: [
                              for (var i = 0; i < report.trend.length; i++)
                                FlSpot(
                                  i.toDouble(),
                                  report.trend[i].dieselSold,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 10),
            const Row(
              children: [
                _TrendLegendDot(color: Color(0xFF1A3A7A), label: 'Petrol'),
                SizedBox(width: 16),
                _TrendLegendDot(color: Color(0xFF2AA878), label: 'Diesel'),
              ],
            ),
          ],
        ),
      ),

      const SizedBox(height: 14),

      // ── Fuel Mix ──────────────────────────────────────────────
      _ClayCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fuel Mix',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A2561),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: totalFuel <= 0
                  ? const Center(
                      child: Text(
                        'No fuel data for this filter.',
                        style: TextStyle(color: Color(0xFF8A93B8)),
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: PieChart(
                            PieChartData(
                              centerSpaceRadius: 0,
                              sectionsSpace: 2,
                              startDegreeOffset: -90,
                              sections: [
                                PieChartSectionData(
                                  value: petrol,
                                  color: const Color(0xFF1A3A7A),
                                  title:
                                      '${((petrol / totalFuel) * 100).round()}%',
                                  radius: 80,
                                  titleStyle: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                PieChartSectionData(
                                  value: diesel,
                                  color: const Color(0xFF2AA878),
                                  title:
                                      '${((diesel / totalFuel) * 100).round()}%',
                                  radius: 80,
                                  titleStyle: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                if (twoT > 0)
                                  PieChartSectionData(
                                    value: twoT,
                                    color: const Color(0xFFCE5828),
                                    title: twoT / totalFuel >= 0.05
                                        ? '${((twoT / totalFuel) * 100).round()}%'
                                        : '',
                                    radius: 80,
                                    titleStyle: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          flex: 2,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FuelLegend(
                                label: 'Petrol',
                                value: formatLiters(petrol),
                                color: const Color(0xFF1A3A7A),
                              ),
                              const SizedBox(height: 14),
                              _FuelLegend(
                                label: 'Diesel',
                                value: formatLiters(diesel),
                                color: const Color(0xFF2AA878),
                              ),
                              if (twoT > 0) ...[
                                const SizedBox(height: 14),
                                _FuelLegend(
                                  label: '2T Oil',
                                  value: formatLiters(twoT),
                                  color: const Color(0xFFCE5828),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),

      const SizedBox(height: 14),

      // ── Daily Breakdown ───────────────────────────────────────
      _PaymentMixCard(
        cash: cash,
        hpPay: hpPay,
        upi: upi,
        credit: credit,
        total: totalPayments,
      ),

      const SizedBox(height: 14),

      _ClayCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Daily Breakdown',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A2561),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: report.trend.isEmpty
                      ? null
                      : () => _openDailyBreakdown(report.trend),
                  icon: const Icon(Icons.list_alt_rounded),
                  label: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Showing the latest 3 days. Open all daily rows for filters and sorting.',
              style: TextStyle(color: Color(0xFF8A93B8), height: 1.35),
            ),
            const SizedBox(height: 14),
            if (dailyPreview.isEmpty)
              const Text(
                'No daily breakdown for this filter.',
                style: TextStyle(color: Color(0xFF8A93B8), fontSize: 13),
              )
            else
              ...dailyPreview.map((point) => _DailyRow(point: point)),
          ],
        ),
      ),
    ];
  }

  String _compactK(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}K';
    }
    return value.toStringAsFixed(0);
  }
}

// ─── Clay card ─────────────────────────────────────────────────────────────────
PieChartSectionData _paymentPieSection(
  double value,
  double total,
  Color color,
) {
  return PieChartSectionData(
    value: value,
    color: color,
    title: value / total >= 0.05 ? '${((value / total) * 100).round()}%' : '',
    radius: 80,
    titleStyle: const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w800,
      fontSize: 13,
    ),
  );
}

class _PaymentMixCard extends StatelessWidget {
  const _PaymentMixCard({
    required this.cash,
    required this.hpPay,
    required this.upi,
    required this.credit,
    required this.total,
  });

  final double cash;
  final double hpPay;
  final double upi;
  final double credit;
  final double total;

  @override
  Widget build(BuildContext context) {
    return _ClayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Mix',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A2561),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: total <= 0
                ? const Center(
                    child: Text(
                      'No payment data for this filter.',
                      style: TextStyle(color: Color(0xFF8A93B8)),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: PieChart(
                          PieChartData(
                            centerSpaceRadius: 0,
                            sectionsSpace: 2,
                            startDegreeOffset: -90,
                            sections: [
                              if (cash > 0)
                                _paymentPieSection(
                                  cash,
                                  total,
                                  const Color(0xFF1A3A7A),
                                ),
                              if (hpPay > 0)
                                _paymentPieSection(
                                  hpPay,
                                  total,
                                  const Color(0xFF6B7280),
                                ),
                              if (upi > 0)
                                _paymentPieSection(
                                  upi,
                                  total,
                                  const Color(0xFF7C3AED),
                                ),
                              if (credit > 0)
                                _paymentPieSection(
                                  credit,
                                  total,
                                  const Color(0xFFCE5828),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 2,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (cash > 0)
                              _FuelLegend(
                                label: 'Cash',
                                value: formatCurrency(cash),
                                color: const Color(0xFF1A3A7A),
                              ),
                            if (hpPay > 0) ...[
                              const SizedBox(height: 14),
                              _FuelLegend(
                                label: 'HP Pay',
                                value: formatCurrency(hpPay),
                                color: const Color(0xFF6B7280),
                              ),
                            ],
                            if (upi > 0) ...[
                              const SizedBox(height: 14),
                              _FuelLegend(
                                label: 'UPI',
                                value: formatCurrency(upi),
                                color: const Color(0xFF7C3AED),
                              ),
                            ],
                            if (credit > 0) ...[
                              const SizedBox(height: 14),
                              _FuelLegend(
                                label: 'Credit',
                                value: formatCurrency(credit),
                                color: const Color(0xFFCE5828),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ClayCard extends StatelessWidget {
  const _ClayCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB8C0DC).withValues(alpha: 0.75),
            offset: const Offset(6, 6),
            blurRadius: 16,
          ),
          const BoxShadow(
            color: Colors.white,
            offset: Offset(-5, -5),
            blurRadius: 12,
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─── Preset pill ───────────────────────────────────────────────────────────────
class _PresetPill extends StatelessWidget {
  const _PresetPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1A3A7A) : const Color(0xFFECEFF8),
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0D2460).withValues(alpha: 0.22),
                    offset: const Offset(0, 6),
                    blurRadius: 14,
                  ),
                ]
              : [
                  BoxShadow(
                    color: const Color(0xFFB8C0DC).withValues(alpha: 0.5),
                    offset: const Offset(3, 3),
                    blurRadius: 8,
                  ),
                  const BoxShadow(
                    color: Colors.white,
                    offset: Offset(-2, -2),
                    blurRadius: 6,
                  ),
                ],
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : const Color(0xFF1A2561),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Report date tile ──────────────────────────────────────────────────────────
class _ReportDateTile extends StatelessWidget {
  const _ReportDateTile({
    required this.label,
    required this.value,
    this.selected = false,
    required this.onTap,
  });
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != 'Tap to choose';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFECEFF8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFF1E5CBA) : Colors.transparent,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFB8C0DC).withValues(alpha: 0.5),
              offset: const Offset(3, 3),
              blurRadius: 8,
            ),
            const BoxShadow(
              color: Colors.white,
              offset: Offset(-2, -2),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 16,
              color: hasValue
                  ? const Color(0xFF1E5CBA)
                  : const Color(0xFF8A93B8),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8A93B8),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: hasValue
                          ? const Color(0xFF1A2561)
                          : const Color(0xFFAAB3D0),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF8A93B8),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportToggleTab extends StatelessWidget {
  const _ReportToggleTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFFB8C0DC).withValues(alpha: 0.5),
                      offset: const Offset(2, 2),
                      blurRadius: 6,
                    ),
                  ]
                : [],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected
                  ? const Color(0xFF1A2561)
                  : const Color(0xFF8A93B8),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportDropdownField<T> extends StatelessWidget {
  const _ReportDropdownField({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return ClayDropdownField<T>(
      label: label,
      icon: icon,
      value: value,
      items: items,
      onChanged: onChanged,
    );
  }
}

// ─── Summary cell ──────────────────────────────────────────────────────────────
class _SummaryCell extends StatelessWidget {
  const _SummaryCell({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OneLineScaleText(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          OneLineScaleText(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummarySep extends StatelessWidget {
  const _SummarySep();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.white.withValues(alpha: 0.15),
    );
  }
}

// ─── Hero action button ────────────────────────────────────────────────────────
class _HeroActionBtn extends StatelessWidget {
  const _HeroActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: filled ? Colors.white : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: filled
                  ? (disabled
                        ? const Color(0xFF8A93B8)
                        : const Color(0xFF1A3A7A))
                  : (disabled ? Colors.white30 : Colors.white),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: filled
                    ? (disabled
                          ? const Color(0xFF8A93B8)
                          : const Color(0xFF1A3A7A))
                    : (disabled ? Colors.white30 : Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Fuel legend item ──────────────────────────────────────────────────────────
class _FuelLegend extends StatelessWidget {
  const _FuelLegend({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OneLineScaleText(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8A93B8),
                ),
              ),
              OneLineScaleText(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A2561),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Trend legend dot ──────────────────────────────────────────────────────────
class _TrendLegendDot extends StatelessWidget {
  const _TrendLegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF374151),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ─── Daily row ─────────────────────────────────────────────────────────────────
enum _DailyBreakdownSort {
  dateNewest,
  dateOldest,
  salesHigh,
  salesLow,
  profitHigh,
  profitLow,
  fuelHigh,
  fuelLow,
}

double _dailyFuelTotal(TrendPointModel point) =>
    point.petrolSold + point.dieselSold + point.twoTSold;

String _dailySortLabel(_DailyBreakdownSort sort) {
  switch (sort) {
    case _DailyBreakdownSort.dateNewest:
      return 'Date - newest';
    case _DailyBreakdownSort.dateOldest:
      return 'Date - oldest';
    case _DailyBreakdownSort.salesHigh:
      return 'Sales - high to low';
    case _DailyBreakdownSort.salesLow:
      return 'Sales - low to high';
    case _DailyBreakdownSort.profitHigh:
      return 'Profit - high to low';
    case _DailyBreakdownSort.profitLow:
      return 'Profit - low to high';
    case _DailyBreakdownSort.fuelHigh:
      return 'Fuel sold - high to low';
    case _DailyBreakdownSort.fuelLow:
      return 'Fuel sold - low to high';
  }
}

class _DailyBreakdownScreen extends StatefulWidget {
  const _DailyBreakdownScreen({
    required this.points,
    required this.initialFromDate,
    required this.initialToDate,
  });

  final List<TrendPointModel> points;
  final DateTime? initialFromDate;
  final DateTime? initialToDate;

  @override
  State<_DailyBreakdownScreen> createState() => _DailyBreakdownScreenState();
}

class _DailyBreakdownScreenState extends State<_DailyBreakdownScreen> {
  final AuthService _authService = AuthService();
  final InventoryService _inventoryService = InventoryService();
  DateTime? _fromDate;
  DateTime? _toDate;
  _DailyBreakdownSort _sort = _DailyBreakdownSort.dateNewest;
  AuthUser? _currentUser;
  String _stationTitle = 'Daily Breakdown';

  @override
  void initState() {
    super.initState();
    _fromDate = widget.initialFromDate;
    _toDate = widget.initialToDate;
    _loadChromeData();
  }

  Future<void> _loadChromeData() async {
    final user = await _authService.readCurrentUser();
    String title = user?.stationId ?? 'Daily Breakdown';
    try {
      final station = await _inventoryService.fetchStationConfig();
      if (station.name.trim().isNotEmpty) {
        title = station.name.trim();
      }
    } catch (_) {
      // Keep the user station id fallback when station config is unavailable.
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _currentUser = user;
      _stationTitle = title;
    });
  }

  bool get _usesManagementNav {
    final role = _currentUser?.role.trim().toLowerCase();
    return role == null || role == 'admin' || role == 'superadmin';
  }

  int get _selectedNavIndex => 3;

  List<AppBottomNavItem> get _navItems {
    if (_usesManagementNav) {
      return const [
        AppBottomNavItem(icon: Icons.grid_view_rounded, label: 'Dashboard'),
        AppBottomNavItem(
          icon: Icons.local_gas_station_outlined,
          label: 'Inventory',
        ),
        AppBottomNavItem(icon: Icons.edit_note_rounded, label: 'Entry'),
        AppBottomNavItem(icon: Icons.bar_chart_rounded, label: 'Report'),
        AppBottomNavItem(
          icon: Icons.manage_accounts_outlined,
          label: 'Settings',
        ),
      ];
    }
    return const [
      AppBottomNavItem(icon: Icons.grid_view_rounded, label: 'Dashboard'),
      AppBottomNavItem(icon: Icons.inventory_2_outlined, label: 'Sales'),
      AppBottomNavItem(
        icon: Icons.local_gas_station_outlined,
        label: 'Inventory',
      ),
      AppBottomNavItem(icon: Icons.local_shipping_outlined, label: 'History'),
      AppBottomNavItem(icon: Icons.person_outline_rounded, label: 'Account'),
    ];
  }

  void _openShellAt(int index) {
    final user = _currentUser;
    if (user == null) {
      Navigator.of(context).maybePop();
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => _usesManagementNav
            ? ManagementShell(user: user, initialIndex: index)
            : SalesShell(user: user, initialIndex: index),
      ),
      (_) => false,
    );
  }

  String _toApiDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  DateTime _firstPointDate() {
    final values =
        widget.points
            .map((point) => DateTime.tryParse(point.date))
            .whereType<DateTime>()
            .toList()
          ..sort();
    return values.isEmpty ? DateTime.now() : values.first;
  }

  DateTime _lastPointDate() {
    final values =
        widget.points
            .map((point) => DateTime.tryParse(point.date))
            .whereType<DateTime>()
            .toList()
          ..sort();
    return values.isEmpty ? DateTime.now() : values.last;
  }

  Future<void> _pickDateRange() async {
    final selected = await showAppDateRangePicker(
      context: context,
      fromDate: _fromDate ?? _firstPointDate(),
      toDate: _toDate ?? _lastPointDate(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Select daily breakdown range',
    );
    if (selected == null) return;
    setState(() {
      _fromDate = selected.start;
      _toDate = selected.end;
    });
  }

  List<TrendPointModel> _visibleRows() {
    final rows = widget.points.where((point) {
      if (_fromDate != null &&
          point.date.compareTo(_toApiDate(_fromDate!)) < 0) {
        return false;
      }
      if (_toDate != null && point.date.compareTo(_toApiDate(_toDate!)) > 0) {
        return false;
      }
      return true;
    }).toList();

    rows.sort((left, right) {
      switch (_sort) {
        case _DailyBreakdownSort.dateNewest:
          return right.date.compareTo(left.date);
        case _DailyBreakdownSort.dateOldest:
          return left.date.compareTo(right.date);
        case _DailyBreakdownSort.salesHigh:
          return right.revenue.compareTo(left.revenue);
        case _DailyBreakdownSort.salesLow:
          return left.revenue.compareTo(right.revenue);
        case _DailyBreakdownSort.profitHigh:
          return right.profit.compareTo(left.profit);
        case _DailyBreakdownSort.profitLow:
          return left.profit.compareTo(right.profit);
        case _DailyBreakdownSort.fuelHigh:
          return _dailyFuelTotal(right).compareTo(_dailyFuelTotal(left));
        case _DailyBreakdownSort.fuelLow:
          return _dailyFuelTotal(left).compareTo(_dailyFuelTotal(right));
      }
    });
    return rows;
  }

  String _rangeLabel() {
    if (_fromDate == null || _toDate == null) return 'All report dates';
    return '${formatDateLabel(_toApiDate(_fromDate!))} to ${formatDateLabel(_toApiDate(_toDate!))}';
  }

  void _clearFilters() {
    setState(() {
      _fromDate = null;
      _toDate = null;
      _sort = _DailyBreakdownSort.dateNewest;
    });
  }

  @override
  Widget build(BuildContext context) {
    final rows = _visibleRows();
    return Scaffold(
      backgroundColor: const Color(0xFFECEFF8),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFECEFF8),
        scrolledUnderElevation: 0,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A2561)),
        title: Row(
          children: [
            const AppLogo(size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: OneLineScaleText(
                _stationTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A2561),
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        selectedIndex: _selectedNavIndex,
        onSelected: _openShellAt,
        items: _navItems,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _ClayCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${rows.length} day${rows.length == 1 ? '' : 's'} shown',
                        style: const TextStyle(
                          color: Color(0xFF1A2561),
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _clearFilters,
                      child: const Text('Clear filter'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickDateRange,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECEFF8),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFDDE2F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.event_rounded,
                          size: 18,
                          color: Color(0xFF1A2561),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OneLineScaleText(
                            _rangeLabel(),
                            style: const TextStyle(
                              color: Color(0xFF1A2561),
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ClayDropdownField<_DailyBreakdownSort>(
                  label: 'Sort by',
                  value: _sort,
                  compact: true,
                  items: _DailyBreakdownSort.values
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(_dailySortLabel(item)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _sort = value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (rows.isEmpty)
            _ClayCard(
              child: const Text(
                'No daily breakdown for this filter.',
                style: TextStyle(color: Color(0xFF8A93B8), fontSize: 13),
              ),
            )
          else
            ...rows.map((point) => _DailyRow(point: point)),
        ],
      ),
    );
  }
}

class _DailyRow extends StatelessWidget {
  const _DailyRow({required this.point});
  final TrendPointModel point;

  @override
  Widget build(BuildContext context) {
    final totalFuel = _dailyFuelTotal(point);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB8C0DC).withValues(alpha: 0.65),
            offset: const Offset(5, 5),
            blurRadius: 12,
          ),
          const BoxShadow(
            color: Colors.white,
            offset: Offset(-4, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatDateLabel(point.date),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Color(0xFF1A2561),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${point.entries} entries recorded',
                      style: const TextStyle(
                        color: Color(0xFF8A93B8),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OneLineScaleText(
                formatCurrency(point.revenue),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: Color(0xFF1A3A7A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _DailyMetric(
                label: 'Sales',
                value: formatCurrency(point.revenue),
              ),
              const SizedBox(width: 10),
              _DailyMetric(
                label: 'Profit',
                value: formatCurrency(point.profit),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _DailyMetric(
                label: 'Petrol',
                value: formatLiters(point.petrolSold),
              ),
              const SizedBox(width: 10),
              _DailyMetric(
                label: 'Diesel',
                value: formatLiters(point.dieselSold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _DailyMetric(
                label: '2T Oil',
                value: formatLiters(point.twoTSold),
              ),
              const SizedBox(width: 10),
              _DailyMetric(label: 'Total fuel', value: formatLiters(totalFuel)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Export date tile (used in dialog) ────────────────────────────────────────
class _DailyMetric extends StatelessWidget {
  const _DailyMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFECEFF8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OneLineScaleText(
              label,
              style: const TextStyle(
                color: Color(0xFF8A93B8),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            OneLineScaleText(
              value,
              style: const TextStyle(
                color: Color(0xFF1A2561),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportDateTile extends StatelessWidget {
  const _ExportDateTile({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDDE3F0)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_rounded,
              size: 16,
              color: Color(0xFF1A3A7A),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF55606E),
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF293340),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
