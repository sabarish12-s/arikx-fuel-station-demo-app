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

  void _reload() {
    setState(() {
      _future = _fetchReport();
    });
  }

  String _toApiDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<void> _pickMonth() async {
    final initial = DateTime.tryParse('$_month-01') ?? DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
      helpText: 'Select report month',
    );
    if (selected == null) {
      return;
    }
    setState(() {
      _month = '${selected.year}-${selected.month.toString().padLeft(2, '0')}';
      _fromDate = null;
      _toDate = null;
      _future = _fetchReport();
    });
  }

  Future<void> _pickFromDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
      helpText: 'Select from date',
    );
    if (selected == null) {
      return;
    }
    setState(() {
      _fromDate = selected;
      _future = _fetchReport();
    });
  }

  Future<void> _pickToDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _toDate ?? _fromDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
      helpText: 'Select to date',
    );
    if (selected == null) {
      return;
    }
    setState(() {
      _toDate = selected;
      _future = _fetchReport();
    });
  }

  static const List<String> _shortMonths = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatDisplayDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_shortMonths[d.month - 1]} ${d.year}';

  /// Opens the export dialog. shareMode=true triggers share instead of save.
  Future<void> _openExportDialog({required bool shareMode}) async {
    final now = DateTime.now();
    // Default: current month
    DateTime exportFrom = DateTime(now.year, now.month, 1);
    DateTime exportTo = DateTime(now.year, now.month + 1, 0); // last day of month

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
                helpText: 'Select from date',
              );
              if (picked != null) {
                setDialogState(() => exportFrom = picked);
              }
            }

            Future<void> pickTo() async {
              final picked = await showDatePicker(
                context: dialogContext,
                initialDate: exportTo.isBefore(exportFrom) ? exportFrom : exportTo,
                firstDate: DateTime(2024),
                lastDate: DateTime(2100),
                helpText: 'Select to date',
              );
              if (picked != null) {
                setDialogState(() => exportTo = picked);
              }
            }

            void applyPreset(DateTime from, DateTime to) {
              setDialogState(() {
                exportFrom = from;
                exportTo = to;
              });
            }

            final thisMonthFrom = DateTime(now.year, now.month, 1);
            final thisMonthTo = DateTime(now.year, now.month + 1, 0);
            final lastMonthFrom = DateTime(now.year, now.month - 1, 1);
            final lastMonthTo = DateTime(now.year, now.month, 0);
            final ytdFrom = DateTime(now.year, 1, 1);
            final ytdTo = now;

            return AlertDialog(
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
                    const SizedBox(height: 16),
                    // Quick presets
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          label: const Text('This Month'),
                          onPressed: () => applyPreset(thisMonthFrom, thisMonthTo),
                        ),
                        ActionChip(
                          label: const Text('Last Month'),
                          onPressed: () => applyPreset(lastMonthFrom, lastMonthTo),
                        ),
                        ActionChip(
                          label: const Text('YTD'),
                          onPressed: () => applyPreset(ytdFrom, ytdTo),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // From date
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: pickFrom,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              size: 18,
                              color: Color(0xFF1E5CBA),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'FROM',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF55606E),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                Text(
                                  _formatDisplayDate(exportFrom),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF293340),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // To date
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: pickTo,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.event_rounded,
                              size: 18,
                              color: Color(0xFF1E5CBA),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'TO',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF55606E),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                Text(
                                  _formatDisplayDate(exportTo),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF293340),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
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
                          content: Text('"To" date must be on or after "From" date.'),
                        ),
                      );
                      return;
                    }
                    Navigator.of(dialogContext).pop();
                    await _runExport(
                      from: exportFrom,
                      to: exportTo,
                      shareMode: shareMode,
                    );
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

      final fromLabel = _formatDisplayDate(from);
      final toLabel = _formatDisplayDate(to);
      final safeFrom = fromStr.replaceAll('-', '');
      final safeTo = toStr.replaceAll('-', '');
      final title = 'rk_fuels_report_${safeFrom}_$safeTo';

      final file = await _reportExportService.exportReport(
        report: report,
        title: title,
        fromLabel: fromLabel,
        toLabel: toLabel,
      );

      if (!mounted) return;

      if (shareMode) {
        await _reportExportService.shareFile(
          file,
          text: 'RK Fuels report $fromLabel to $toLabel',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Report saved to ${file.path}')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFB91C1C),
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }


  void _clearRange() {
    _applyLast30Days();
  }

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

  bool get _isLast30DaysPreset {
    if (_fromDate == null || _toDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final from = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
    final to = DateTime(_toDate!.year, _toDate!.month, _toDate!.day);
    return from == today.subtract(const Duration(days: 29)) && to == today;
  }

  bool get _isThisMonthPreset {
    if (_fromDate == null || _toDate == null) return false;
    final now = DateTime.now();
    final from = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
    final to = DateTime(_toDate!.year, _toDate!.month, _toDate!.day);
    return from == DateTime(now.year, now.month, 1) &&
        to == DateTime(now.year, now.month + 1, 0);
  }

  bool get _isLastMonthPreset {
    if (_fromDate == null || _toDate == null) return false;
    final now = DateTime.now();
    final from = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
    final to = DateTime(_toDate!.year, _toDate!.month, _toDate!.day);
    return from == DateTime(now.year, now.month - 1, 1) &&
        to == DateTime(now.year, now.month, 0);
  }

  Widget _buildPresetChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1E5CBA) : const Color(0xFFF0F4FF),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF1E5CBA),
          ),
        ),
      ),
    );
  }

  Widget _buildDateTile(String label, DateTime? date, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDDE3F0)),
        ),
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
            const SizedBox(height: 3),
            Text(
              date == null ? '—' : _formatDisplayDate(date),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF293340),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MonthlyReportModel>(
      future: _future,
      builder: (context, snapshot) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Report Filters',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF293340),
                        ),
                      ),
                      IconButton(
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh_rounded),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildPresetChip('Last 30 days', _isLast30DaysPreset, _applyLast30Days),
                        const SizedBox(width: 8),
                        _buildPresetChip('This Month', _isThisMonthPreset, _applyThisMonth),
                        const SizedBox(width: 8),
                        _buildPresetChip('Last Month', _isLastMonthPreset, _applyLastMonth),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildDateTile('FROM', _fromDate, _pickFromDate)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildDateTile('TO', _toDate, _pickToDate)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (snapshot.connectionState != ConnectionState.done)
              const Padding(
                padding: EdgeInsets.only(top: 120),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (snapshot.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 120),
                child: Center(
                  child: Text(
                    snapshot.error.toString().replaceFirst('Exception: ', ''),
                  ),
                ),
              )
            else
              ..._buildReport(snapshot.data!),
          ],
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
      0,
      (max, item) => item.revenue > max ? item.revenue : max,
    );

    return [
      _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _fromDate != null || _toDate != null
                  ? 'Report Range'
                  : 'Month ${report.month}',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 24,
                color: Color(0xFF293340),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: [
                Text('Revenue ${formatCurrency(report.revenue)}'),
                Text('Profit ${formatCurrency(report.profit)}'),
                Text('Petrol sold ${formatLiters(report.petrolSold)}'),
                Text('Diesel sold ${formatLiters(report.dieselSold)}'),
                Text('2T oil sold ${formatLiters(report.twoTSold)}'),
                Text('Shifts completed ${report.shiftsCompleted}'),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: _exporting ? null : () => _openExportDialog(shareMode: false),
                  icon: const Icon(Icons.download_rounded),
                  label: Text(_exporting ? 'Preparing...' : 'Download Report'),
                ),
                OutlinedButton.icon(
                  onPressed: _exporting ? null : () => _openExportDialog(shareMode: true),
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Share Report'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const CreditLedgerScreen(),
                        ),
                      ),
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  label: const Text('Credit Details'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Exports are generated as Excel-compatible CSV files.',
              style: TextStyle(color: Color(0xFF55606E), fontSize: 12),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Revenue Trend',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF293340),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 240,
              child: report.trend.isEmpty
                  ? const Center(child: Text('No trend data for this filter.'))
                  : LineChart(
                      LineChartData(
                        minY: 0,
                        maxY: maxRevenue <= 0 ? 10 : maxRevenue * 1.2,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: maxRevenue <= 0
                              ? 5
                              : (maxRevenue * 1.2) / 5,
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
                              reservedSize: 54,
                              interval: maxRevenue <= 0
                                  ? 5
                                  : (maxRevenue * 1.2) / 5,
                              getTitlesWidget: (value, meta) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Text(
                                    _compactCurrencyLabel(value),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF55606E),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index < 0 || index >= report.trend.length) {
                                  return const SizedBox.shrink();
                                }
                                if (report.trend.length > 6 &&
                                    index.isOdd &&
                                    index != report.trend.length - 1) {
                                  return const SizedBox.shrink();
                                }
                                final date = DateTime.tryParse(report.trend[index].date);
                                final label = date == null
                                    ? report.trend[index].date
                                    : '${date.day}/${date.month}';
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    label,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF55606E),
                                    ),
                                  ),
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
                            color: const Color(0xFF1E5CBA),
                            barWidth: 3,
                            dotData: FlDotData(
                              show: report.trend.length <= 8,
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              color: const Color(0xFF1E5CBA).withValues(alpha: 0.12),
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
      const SizedBox(height: 16),
      _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fuel Mix',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF293340),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: totalFuel <= 0
                  ? const Center(child: Text('No fuel movement for this filter.'))
                  : Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 3,
                              centerSpaceRadius: 34,
                              sections: [
                                PieChartSectionData(
                                  value: petrol,
                                  color: const Color(0xFF1E5CBA),
                                  title: '${((petrol / totalFuel) * 100).round()}%',
                                  radius: 52,
                                  titleStyle: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                                PieChartSectionData(
                                  value: diesel,
                                  color: const Color(0xFF006C5C),
                                  title: '${((diesel / totalFuel) * 100).round()}%',
                                  radius: 52,
                                  titleStyle: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                                if (twoT > 0)
                                  PieChartSectionData(
                                    value: twoT,
                                    color: const Color(0xFFB45309),
                                    title: '${((twoT / totalFuel) * 100).round()}%',
                                    radius: 52,
                                    titleStyle: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _LegendItem(
                                label: 'Petrol ${formatLiters(petrol)}',
                                color: const Color(0xFF1E5CBA),
                              ),
                              const SizedBox(height: 12),
                              _LegendItem(
                                label: 'Diesel ${formatLiters(diesel)}',
                                color: const Color(0xFF006C5C),
                              ),
                              if (twoT > 0) ...[
                                const SizedBox(height: 12),
                                _LegendItem(
                                  label: '2T Oil ${formatLiters(twoT)}',
                                  color: const Color(0xFFB45309),
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
      const SizedBox(height: 16),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          'Daily Breakdown',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF293340),
          ),
        ),
      ),
      const SizedBox(height: 10),
      ...report.trend.map(
        (point) => _Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatDateLabel(point.date),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Profit ${formatCurrency(point.profit)} • Petrol ${formatLiters(point.petrolSold)} • Diesel ${formatLiters(point.dieselSold)} • 2T ${formatLiters(point.twoTSold)}',
                      style: const TextStyle(color: Color(0xFF55606E)),
                    ),
                  ],
                ),
              ),
              Text(
                formatCurrency(point.revenue),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF293340),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  String _compactCurrencyLabel(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}K';
    }
    return value.toStringAsFixed(0);
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: child,
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF293340),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
