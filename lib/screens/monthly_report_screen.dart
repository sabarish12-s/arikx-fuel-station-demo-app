import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/management_service.dart';
import '../services/report_export_service.dart';
import '../utils/formatters.dart';
import 'credit_ledger_screen.dart';

class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  final ManagementService _managementService = ManagementService();
  final ReportExportService _reportExportService = ReportExportService();
  late Future<MonthlyReportModel> _future;
  String _month = currentMonthKey();
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _fromDate = today.subtract(const Duration(days: 29));
    _toDate = today;
    _future = _fetchReport();
  }

  Future<MonthlyReportModel> _fetchReport() {
    return _managementService.fetchMonthlyReport(
      month: _fromDate == null && _toDate == null ? _month : null,
      fromDate: _fromDate == null ? null : _toApiDate(_fromDate!),
      toDate: _toDate == null ? null : _toApiDate(_toDate!),
    );
  }

  void _reload() => setState(() => _future = _fetchReport());

  String _toApiDate(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
      helpText: 'From date',
    );
    if (picked == null) return;
    setState(() {
      _fromDate = picked;
      _future = _fetchReport();
    });
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? _fromDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
      helpText: 'To date',
    );
    if (picked == null) return;
    setState(() {
      _toDate = picked;
      _future = _fetchReport();
    });
  }

  static const List<String> _shortMonths = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec',
  ];

  String _fmtDt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_shortMonths[d.month - 1]} ${d.year}';

  String _fmtShort(DateTime d) => '${_shortMonths[d.month - 1]} ${d.day}';

  void _applyLast30Days() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _fromDate = today.subtract(const Duration(days: 29));
      _toDate = today;
      _future = _fetchReport();
    });
  }

  void _applyThisMonth() {
    final now = DateTime.now();
    setState(() {
      _fromDate = DateTime(now.year, now.month, 1);
      _toDate = DateTime(now.year, now.month + 1, 0);
      _future = _fetchReport();
    });
  }

  void _applyLastMonth() {
    final now = DateTime.now();
    setState(() {
      _fromDate = DateTime(now.year, now.month - 1, 1);
      _toDate = DateTime(now.year, now.month, 0);
      _future = _fetchReport();
    });
  }

  bool get _isLast30Days {
    if (_fromDate == null || _toDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day) ==
            today.subtract(const Duration(days: 29)) &&
        DateTime(_toDate!.year, _toDate!.month, _toDate!.day) == today;
  }

  bool get _isThisMonth {
    if (_fromDate == null || _toDate == null) return false;
    final now = DateTime.now();
    return DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day) ==
            DateTime(now.year, now.month, 1) &&
        DateTime(_toDate!.year, _toDate!.month, _toDate!.day) ==
            DateTime(now.year, now.month + 1, 0);
  }

  bool get _isLastMonth {
    if (_fromDate == null || _toDate == null) return false;
    final now = DateTime.now();
    return DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day) ==
            DateTime(now.year, now.month - 1, 1) &&
        DateTime(_toDate!.year, _toDate!.month, _toDate!.day) ==
            DateTime(now.year, now.month, 0);
  }

  Future<void> _openExportDialog({required bool shareMode}) async {
    final now = DateTime.now();
    DateTime exportFrom = DateTime(now.year, now.month, 1);
    DateTime exportTo = DateTime(now.year, now.month + 1, 0);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> pickFrom() async {
              final picked = await showDatePicker(
                context: dialogContext,
                initialDate: exportFrom,
                firstDate: DateTime(2024),
                lastDate: DateTime(2100),
                helpText: 'From date',
              );
              if (picked != null) setDialogState(() => exportFrom = picked);
            }

            Future<void> pickTo() async {
              final picked = await showDatePicker(
                context: dialogContext,
                initialDate: exportTo.isBefore(exportFrom) ? exportFrom : exportTo,
                firstDate: DateTime(2024),
                lastDate: DateTime(2100),
                helpText: 'To date',
              );
              if (picked != null) setDialogState(() => exportTo = picked);
            }

            void applyPreset(DateTime from, DateTime to) =>
                setDialogState(() { exportFrom = from; exportTo = to; });

            final tMF = DateTime(now.year, now.month, 1);
            final tMT = DateTime(now.year, now.month + 1, 0);
            final lMF = DateTime(now.year, now.month - 1, 1);
            final lMT = DateTime(now.year, now.month, 0);

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(label: const Text('This Month'), onPressed: () => applyPreset(tMF, tMT)),
                        ActionChip(label: const Text('Last Month'), onPressed: () => applyPreset(lMF, lMT)),
                        ActionChip(label: const Text('YTD'), onPressed: () => applyPreset(DateTime(now.year, 1, 1), now)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _ExportDateTile(label: 'FROM', value: _fmtDt(exportFrom), onTap: pickFrom),
                    const SizedBox(height: 8),
                    _ExportDateTile(label: 'TO', value: _fmtDt(exportTo), onTap: pickTo),
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
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        backgroundColor: Color(0xFFB91C1C),
                        content: Text('"To" date must be on or after "From" date.'),
                      ));
                      return;
                    }
                    Navigator.of(dialogContext).pop();
                    await _runExport(from: exportFrom, to: exportTo, shareMode: shareMode);
                  },
                  icon: Icon(shareMode ? Icons.share_rounded : Icons.download_rounded),
                  label: Text(shareMode ? 'Share CSV' : 'Export CSV'),
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
      final file = await _reportExportService.exportReport(
        report: report,
        title: title,
        fromLabel: _fmtDt(from),
        toLabel: _fmtDt(to),
      );
      if (!mounted) return;
      if (shareMode) {
        await _reportExportService.shareFile(file, text: 'RK Fuels report ${_fmtDt(from)} to ${_fmtDt(to)}');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Report saved to ${file.path}')));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: const Color(0xFFB91C1C),
        content: Text(error.toString().replaceFirst('Exception: ', '')),
      ));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MonthlyReportModel>(
      future: _future,
      builder: (context, snapshot) {
        return ColoredBox(
          color: const Color(0xFFECEFF8),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // ── Filter card ───────────────────────────────────────
              _ClayCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.tune_rounded, color: Color(0xFF1A3A7A), size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Report Filters',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A2561),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _reload,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECEFF8),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFB8C0DC).withValues(alpha: 0.6),
                                  offset: const Offset(2, 2),
                                  blurRadius: 5,
                                ),
                                const BoxShadow(
                                  color: Colors.white,
                                  offset: Offset(-2, -2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF4A5598)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Preset pills
                    Row(
                      children: [
                        _PresetPill(label: 'Last 30 days', selected: _isLast30Days, onTap: _applyLast30Days),
                        const SizedBox(width: 8),
                        _PresetPill(label: 'This Month', selected: _isThisMonth, onTap: _applyThisMonth),
                        const SizedBox(width: 8),
                        _PresetPill(label: 'Last Month', selected: _isLastMonth, onTap: _applyLastMonth),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Date tiles
                    Row(
                      children: [
                        Expanded(
                          child: _ReportDateTile(
                            label: 'FROM',
                            value: _fromDate != null ? _fmtDt(_fromDate!) : '—',
                            onTap: _pickFromDate,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ReportDateTile(
                            label: 'TO',
                            value: _toDate != null ? _fmtDt(_toDate!) : '—',
                            onTap: _pickToDate,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── Loading / error ───────────────────────────────────
              if (snapshot.connectionState != ConnectionState.done)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 80),
                  child: Center(
                    child: Text(snapshot.error.toString().replaceFirst('Exception: ', '')),
                  ),
                )
              else
                ..._buildReport(snapshot.data!),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildReport(MonthlyReportModel report) {
    final petrol = report.fuelBreakdown['petrol'] ?? 0;
    final diesel = report.fuelBreakdown['diesel'] ?? 0;
    final twoT = report.fuelBreakdown['two_t_oil'] ?? 0;
    final totalFuel = petrol + diesel + twoT;
    final maxRevenue = report.trend.fold<double>(
      0, (max, item) => item.revenue > max ? item.revenue : max,
    );

    final rangeLabel = (_fromDate != null && _toDate != null)
        ? '${_fmtShort(_fromDate!)} – ${_fmtShort(_toDate!)}'
        : 'Month ${report.month}';

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
            Text(
              rangeLabel,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Summary',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _SummaryCell(label: 'Revenue', value: formatCurrency(report.revenue)),
                const _SummarySep(),
                _SummaryCell(label: 'Profit', value: formatCurrency(report.profit)),
              ],
            ),
            const SizedBox(height: 1),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.1), margin: const EdgeInsets.symmetric(vertical: 10)),
            Row(
              children: [
                _SummaryCell(label: 'Petrol', value: formatLiters(report.petrolSold)),
                const _SummarySep(),
                _SummaryCell(label: 'Diesel', value: formatLiters(report.dieselSold)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _SummaryCell(label: '2T Oil', value: formatLiters(report.twoTSold)),
                const _SummarySep(),
                _SummaryCell(label: 'Shifts', value: '${report.shiftsCompleted}'),
              ],
            ),
            const SizedBox(height: 18),
            // Action buttons row
            Row(
              children: [
                Expanded(
                  child: _HeroActionBtn(
                    icon: Icons.download_rounded,
                    label: _exporting ? 'Preparing...' : 'Download',
                    onTap: _exporting ? null : () => _openExportDialog(shareMode: false),
                    filled: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _HeroActionBtn(
                    icon: Icons.share_rounded,
                    label: 'Share',
                    onTap: _exporting ? null : () => _openExportDialog(shareMode: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _HeroActionBtn(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Credits',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const CreditLedgerScreen(),
                    )),
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
              'Revenue Trend',
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
                        maxY: maxRevenue <= 0 ? 10 : maxRevenue * 1.2,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: maxRevenue <= 0 ? 5 : (maxRevenue * 1.2) / 4,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: const Color(0xFFD8DCF0),
                            strokeWidth: 1,
                            dashArray: [4, 4],
                          ),
                        ),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 52,
                              interval: maxRevenue <= 0 ? 5 : (maxRevenue * 1.2) / 4,
                              getTitlesWidget: (value, meta) => Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Text(
                                  _compactK(value),
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF8A93B8)),
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
                                if (idx < 0 || idx >= report.trend.length) return const SizedBox.shrink();
                                if (report.trend.length > 6 && idx.isOdd && idx != report.trend.length - 1) {
                                  return const SizedBox.shrink();
                                }
                                final dt = DateTime.tryParse(report.trend[idx].date);
                                final lbl = dt == null
                                    ? report.trend[idx].date
                                    : '${dt.day}/${dt.month}';
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(lbl, style: const TextStyle(fontSize: 10, color: Color(0xFF8A93B8))),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineTouchData: LineTouchData(enabled: true),
                        lineBarsData: [
                          LineChartBarData(
                            isCurved: true,
                            color: const Color(0xFF1A3A7A),
                            barWidth: 2.5,
                            dotData: FlDotData(
                              show: report.trend.length <= 8,
                              getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                                radius: 4,
                                color: const Color(0xFF1A3A7A),
                                strokeWidth: 2,
                                strokeColor: Colors.white,
                              ),
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              color: const Color(0xFF1A3A7A).withValues(alpha: 0.10),
                            ),
                            spots: [
                              for (var i = 0; i < report.trend.length; i++)
                                FlSpot(i.toDouble(), report.trend[i].revenue),
                            ],
                          ),
                        ],
                      ),
                    ),
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
                                  title: '${((petrol / totalFuel) * 100).round()}%',
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
                                  title: '${((diesel / totalFuel) * 100).round()}%',
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
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10),
        child: Text(
          'Daily Breakdown',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF8A93B8),
            letterSpacing: 0.2,
          ),
        ),
      ),

      ...report.trend.map((point) => _DailyRow(point: point)),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1A3A7A) : const Color(0xFFECEFF8),
          borderRadius: BorderRadius.circular(999),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0D2460).withValues(alpha: 0.35),
                    offset: const Offset(0, 4),
                    blurRadius: 10,
                  ),
                ]
              : [
                  BoxShadow(
                    color: const Color(0xFFB8C0DC).withValues(alpha: 0.6),
                    offset: const Offset(3, 3),
                    blurRadius: 7,
                  ),
                  const BoxShadow(
                    color: Colors.white,
                    offset: Offset(-2, -2),
                    blurRadius: 5,
                  ),
                ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF4A5598),
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
    required this.onTap,
  });
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFECEFF8),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFB8C0DC).withValues(alpha: 0.55),
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
              size: 14,
              color: const Color(0xFF4A5598),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8A93B8),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
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
        ),
      ),
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
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
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
          color: filled
              ? Colors.white
              : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: filled
                  ? (disabled ? const Color(0xFF8A93B8) : const Color(0xFF1A3A7A))
                  : (disabled ? Colors.white30 : Colors.white),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: filled
                    ? (disabled ? const Color(0xFF8A93B8) : const Color(0xFF1A3A7A))
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
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8A93B8),
                ),
              ),
              Text(
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

// ─── Daily row ─────────────────────────────────────────────────────────────────
class _DailyRow extends StatelessWidget {
  const _DailyRow({required this.point});
  final TrendPointModel point;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      child: Row(
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
                  'Profit ${formatCurrency(point.profit)}  •  '
                  'P ${formatLiters(point.petrolSold)}  •  '
                  'D ${formatLiters(point.dieselSold)}'
                  '${point.twoTSold > 0 ? '  •  2T ${formatLiters(point.twoTSold)}' : ''}',
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
          Text(
            formatCurrency(point.revenue),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: Color(0xFF1A3A7A),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Export date tile (used in dialog) ────────────────────────────────────────
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
            const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF1A3A7A)),
            const SizedBox(width: 10),
            Column(
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
                  style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF293340)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
