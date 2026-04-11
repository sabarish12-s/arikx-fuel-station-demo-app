import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/auth_models.dart';
import '../models/domain_models.dart';
import '../services/api_response_cache.dart';
import '../services/management_service.dart';
import '../utils/formatters.dart';
import '../utils/user_facing_errors.dart';
import '../widgets/app_date_range_picker.dart';
import '../widgets/responsive_text.dart';

String _shortDateLabel(String raw) {
  final date = DateTime.tryParse(raw);
  if (date == null) return raw;
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
  return '${months[date.month - 1]} ${date.day}';
}

class ManagementDashboardScreen extends StatefulWidget {
  const ManagementDashboardScreen({super.key, required this.user});
  final AuthUser user;

  @override
  State<ManagementDashboardScreen> createState() =>
      _ManagementDashboardScreenState();
}

class _ManagementDashboardScreenState extends State<ManagementDashboardScreen> {
  final ManagementService _managementService = ManagementService();
  late Future<ManagementDashboardModel> _future;
  late final StreamSubscription<ApiResponseCacheUpdate> _cacheSubscription;

  // Default to last7 — "today" is not useful since entries are logged next day
  String _preset = 'last7';
  String? _fromDate;
  String? _toDate;
  int _pumpTouchedIndex = -1;
  int _staffTouchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _cacheSubscription = ApiResponseCache.updates.listen((update) {
      if (!mounted ||
          !update.background ||
          !update.path.startsWith('/management/dashboard')) {
        return;
      }
      setState(() => _future = _load());
    });
  }

  @override
  void dispose() {
    _cacheSubscription.cancel();
    super.dispose();
  }

  Future<ManagementDashboardModel> _load({bool forceRefresh = false}) =>
      _managementService.fetchDashboard(
        preset: _preset == 'custom' ? null : _preset,
        fromDate: _fromDate,
        toDate: _toDate,
        forceRefresh: forceRefresh,
      );

  Future<void> _refresh() async {
    setState(() => _future = _load(forceRefresh: true));
    await _future;
  }

  Future<void> _applyPreset(String preset) async {
    setState(() {
      _preset = preset;
      _fromDate = null;
      _toDate = null;
      _pumpTouchedIndex = -1;
      _staffTouchedIndex = -1;
      _future = _load();
    });
  }

  Future<void> _pickCustomRange() async {
    final range = await showAppDateRangePicker(
      context: context,
      fromDate: DateTime.tryParse(_fromDate ?? ''),
      toDate: DateTime.tryParse(_toDate ?? ''),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      helpText: 'Select dashboard range',
    );
    if (range == null) return;
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    setState(() {
      _preset = 'custom';
      _fromDate = fmt(range.start);
      _toDate = fmt(range.end);
      _pumpTouchedIndex = -1;
      _staffTouchedIndex = -1;
      _future = _load();
    });
  }

  Color _pumpColor(String pumpId) {
    switch (pumpId) {
      case 'pump1':
        return const Color(0xFF1E5CBA);
      case 'pump2':
        return const Color(0xFF0F9D58);
      case 'pump3':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF7C3AED);
    }
  }

  // 8 hue-distinct, consistent-weight colors — each from a different color family
  // so they never look similar side-by-side regardless of how many staff there are.
  static const _premiumPalette = [
    Color(0xFF3B6FCC), // blue
    Color(0xFF2AA878), // emerald
    Color(0xFFCE5828), // burnt orange
    Color(0xFF8B4EC0), // violet
    Color(0xFF1298B8), // teal
    Color(0xFFC49018), // amber gold
    Color(0xFFC02868), // deep rose
    Color(0xFF3AAA90), // seafoam
    Color(0xFF7048A8), // purple
    Color(0xFFA85830), // copper
    Color(0xFF4858C8), // periwinkle
    Color(0xFF50A038), // forest green
  ];

  List<Color> _uniqueStaffColors(int count) {
    if (count == 0) return [];
    return List.generate(count, (i) {
      if (i < _premiumPalette.length) return _premiumPalette[i];
      final hue = (i * 137.508) % 360;
      return HSLColor.fromAHSL(1.0, hue, 0.35, 0.48).toColor();
    });
  }

  // ── Compact horizontal filter bar ─────────────────────────────────────────
  Widget _buildFilterBar() {
    final presets = <MapEntry<String, String>>[
      const MapEntry('last7', 'Last 7 Days'),
      const MapEntry('thisMonth', 'This Month'),
      const MapEntry('lastMonth', 'Last Month'),
    ];

    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          ...presets.map(
            (p) => _FilterPill(
              label: p.value,
              selected: _preset == p.key,
              onTap: () => _applyPreset(p.key),
            ),
          ),
          _FilterPill(
            label: _preset == 'custom' ? 'Custom ✓' : 'Custom Range',
            selected: _preset == 'custom',
            icon: Icons.date_range_rounded,
            onTap: _pickCustomRange,
          ),
        ],
      ),
    );
  }

  // ── Hero snapshot card ─────────────────────────────────────────────────────
  Widget _buildHeroCard(ManagementDashboardModel data) {
    final hasAlert =
        data.varianceCount > 0 ||
        data.flaggedCount > 0 ||
        data.pendingRequests > 0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F2D6B), Color(0xFF1E5CBA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E5CBA).withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.station.name.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.range.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Approved entries only',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Divider
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            color: Colors.white.withValues(alpha: 0.1),
          ),

          const SizedBox(height: 16),

          // Metric grid — 2 columns
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                _HeroMetricRow(
                  left: _HeroMetricCell(
                    label: 'Collected',
                    value: formatCurrency(data.paymentTotal),
                    highlight: true,
                  ),
                  right: _HeroMetricCell(
                    label: 'Computed Sales',
                    value: formatCurrency(data.revenue),
                  ),
                ),
                const SizedBox(height: 14),
                _HeroMetricRow(
                  left: _HeroMetricCell(
                    label: 'Petrol Sold',
                    value: formatLiters(data.petrolSold),
                  ),
                  right: _HeroMetricCell(
                    label: 'Diesel Sold',
                    value: formatLiters(data.dieselSold),
                  ),
                ),
                const SizedBox(height: 14),
                _HeroMetricRow(
                  left: _HeroMetricCell(
                    label: 'Approved Entries',
                    value: '${data.entriesCompleted}',
                  ),
                  right:
                      data.twoTSold > 0
                          ? _HeroMetricCell(
                            label: '2T Oil Sold',
                            value: formatLiters(data.twoTSold),
                          )
                          : const SizedBox.shrink(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Alert strip at bottom
          if (hasAlert) ...[
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              color: Colors.white.withValues(alpha: 0.1),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  _AlertBadge(
                    label: 'Variance',
                    count: data.varianceCount,
                    color: const Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 8),
                  _AlertBadge(
                    label: 'Flags',
                    count: data.flaggedCount,
                    color: const Color(0xFFEF4444),
                  ),
                  const SizedBox(width: 8),
                  _AlertBadge(
                    label: 'Pending Users',
                    count: data.pendingRequests,
                    color: const Color(0xFF34D399),
                  ),
                ],
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF34D399),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'No flags, variances, or pending users',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Pump + Staff contribution ──────────────────────────────────────────────
  Widget _buildContributionSection(ManagementDashboardModel data) {
    final pumpSlices =
        data.pumpPerformance
            .map(
              (item) => _ContributionSlice(
                label: formatPumpLabel(item.pumpId, item.pumpLabel),
                amount: item.collectedAmount,
                liters: item.liters,
                subtitle:
                    item.attendantsSeen.isEmpty
                        ? 'No attendants recorded'
                        : item.attendantsSeen.join(', '),
                color: _pumpColor(item.pumpId),
              ),
            )
            .toList();

    final staffColors = _uniqueStaffColors(data.attendantPerformance.length);
    final staffSlices = [
      for (int i = 0; i < data.attendantPerformance.length; i++)
        _ContributionSlice(
          label: data.attendantPerformance[i].attendantName,
          amount: data.attendantPerformance[i].collectedAmount,
          liters: data.attendantPerformance[i].liters,
          subtitle:
              data.attendantPerformance[i].pumpsWorked.isEmpty
                  ? 'No pumps recorded'
                  : data.attendantPerformance[i].pumpsWorked.join(', '),
          color: staffColors[i],
        ),
    ];

    final pumpItems =
        data.pumpPerformance
            .map(
              (item) => _PerformanceItem(
                title: formatPumpLabel(item.pumpId, item.pumpLabel),
                subtitle:
                    item.attendantsSeen.isEmpty
                        ? 'No attendants recorded'
                        : item.attendantsSeen.join(', '),
                liters: item.liters,
                collectedAmount: item.collectedAmount,
                computedSalesValue: item.computedSalesValue,
                variance: item.variance,
                accent: _pumpColor(item.pumpId),
              ),
            )
            .toList();

    final staffItems = [
      for (int i = 0; i < data.attendantPerformance.length; i++)
        _PerformanceItem(
          title: data.attendantPerformance[i].attendantName,
          subtitle:
              data.attendantPerformance[i].pumpsWorked.isEmpty
                  ? '${data.attendantPerformance[i].activeDays} active days'
                  : '${data.attendantPerformance[i].activeDays} active days  ·  ${data.attendantPerformance[i].pumpsWorked.join(', ')}',
          liters: data.attendantPerformance[i].liters,
          collectedAmount: data.attendantPerformance[i].collectedAmount,
          computedSalesValue: data.attendantPerformance[i].computedSalesValue,
          variance: data.attendantPerformance[i].variance,
          accent: staffColors[i],
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ContributionPieCard(
                  title: 'Pump Contribution',
                  slices: pumpSlices,
                  touchedIndex: _pumpTouchedIndex,
                  onTouched: (i) => setState(() => _pumpTouchedIndex = i),
                  performanceItems: pumpItems,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ContributionPieCard(
                  title: 'Staff Contribution',
                  slices: staffSlices,
                  touchedIndex: _staffTouchedIndex,
                  onTouched: (i) => setState(() => _staffTouchedIndex = i),
                  performanceItems: staffItems,
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            _ContributionPieCard(
              title: 'Pump Contribution',
              slices: pumpSlices,
              touchedIndex: _pumpTouchedIndex,
              onTouched: (i) => setState(() => _pumpTouchedIndex = i),
              performanceItems: pumpItems,
            ),
            const SizedBox(height: 12),
            _ContributionPieCard(
              title: 'Staff Contribution',
              slices: staffSlices,
              touchedIndex: _staffTouchedIndex,
              onTouched: (i) => setState(() => _staffTouchedIndex = i),
              performanceItems: staffItems,
            ),
          ],
        );
      },
    );
  }

  // ── Trend chart ────────────────────────────────────────────────────────────
  Widget _buildTrendSection(ManagementDashboardModel data) {
    final trend = data.trend;

    if (trend.isEmpty) {
      return _SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(title: 'Sales Trend'),
            const SizedBox(height: 12),
            const Text(
              'No approved sales trend available for this range.',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            ),
          ],
        ),
      );
    }

    final maxY = trend.fold<double>(
      0,
      (m, p) => [m, p.petrolSold, p.dieselSold].reduce((a, b) => a > b ? a : b),
    );

    // Build the list of indices where a date appears for the first time.
    // This prevents the same date from being labelled multiple times when
    // there are several data points (e.g. shifts) for the same day.
    final List<int> uniqueDateIndices = [];
    final seenDates = <String>{};
    for (int i = 0; i < trend.length; i++) {
      final dateKey =
          trend[i].date.length >= 10
              ? trend[i].date.substring(0, 10)
              : trend[i].date;
      if (seenDates.add(dateKey)) {
        uniqueDateIndices.add(i);
      }
    }

    // For compact view show at most 5 labels; for full screen show all unique dates.
    Set<int> labelIndices(bool compact) {
      if (!compact) return uniqueDateIndices.toSet();
      if (uniqueDateIndices.length <= 5) return uniqueDateIndices.toSet();
      // Evenly spread 5 labels across the unique date indices.
      final result = <int>{};
      final step = (uniqueDateIndices.length / 4).ceil();
      for (int i = 0; i < uniqueDateIndices.length; i += step) {
        result.add(uniqueDateIndices[i]);
      }
      // Always include the last date.
      result.add(uniqueDateIndices.last);
      return result;
    }

    LineChartData buildChartData({required bool compact}) {
      final labelSet = labelIndices(compact);
      return LineChartData(
        minX: 0,
        maxX: (trend.length - 1).toDouble(),
        minY: 0,
        maxY: maxY <= 0 ? 10 : maxY * 1.2,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine:
              (_) => const FlLine(color: Color(0xFFEEF2FF), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData:
            compact
                ? const LineTouchData(enabled: false)
                : LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems:
                        (spots) =>
                            spots.map((s) {
                              final idx = s.x.toInt();
                              final point =
                                  trend[idx.clamp(0, trend.length - 1)];
                              final isFirst = s.barIndex == 0;
                              return LineTooltipItem(
                                isFirst
                                    ? '${_shortDateLabel(point.date)}\nPetrol ${formatLiters(s.y)}'
                                    : 'Diesel ${formatLiters(s.y)}',
                                TextStyle(
                                  color:
                                      isFirst
                                          ? const Color(0xFF1E5CBA)
                                          : const Color(0xFF0F9D58),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              );
                            }).toList(),
                  ),
                ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles:
              compact
                  ? const AxisTitles()
                  : AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 48,
                      interval: maxY <= 0 ? 10 : (maxY * 1.2) / 4,
                      getTitlesWidget:
                          (value, _) => Text(
                            '${value.toInt()} L',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                    ),
                  ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              // interval:1 ensures getTitlesWidget is called for every integer
              // index exactly once — without this fl_chart calls it for
              // non-integer floats that toInt() to the same value repeatedly.
              interval: 1,
              getTitlesWidget: (value, _) {
                final index = value.round();
                if (index < 0 || index >= trend.length) {
                  return const SizedBox.shrink();
                }
                if (!labelSet.contains(index)) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _shortDateLabel(trend[index].date),
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (int i = 0; i < trend.length; i++)
                FlSpot(i.toDouble(), trend[i].petrolSold),
            ],
            isCurved: true,
            color: const Color(0xFF1E5CBA),
            barWidth: 2.5,
            dotData: FlDotData(
              show: !compact,
              getDotPainter:
                  (p, i, b, j) => FlDotCirclePainter(
                    radius: 3,
                    color: const Color(0xFF1E5CBA),
                    strokeWidth: 0,
                    strokeColor: Colors.transparent,
                  ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF1E5CBA).withValues(alpha: 0.07),
            ),
          ),
          LineChartBarData(
            spots: [
              for (int i = 0; i < trend.length; i++)
                FlSpot(i.toDouble(), trend[i].dieselSold),
            ],
            isCurved: true,
            color: const Color(0xFF0F9D58),
            barWidth: 2.5,
            dotData: FlDotData(
              show: !compact,
              getDotPainter:
                  (p, i, b, j) => FlDotCirclePainter(
                    radius: 3,
                    color: const Color(0xFF0F9D58),
                    strokeWidth: 0,
                    strokeColor: Colors.transparent,
                  ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF0F9D58).withValues(alpha: 0.07),
            ),
          ),
        ],
      );
    }

    final legend = Row(
      children: [
        _LegendDot(color: const Color(0xFF1E5CBA), label: 'Petrol'),
        const SizedBox(width: 16),
        _LegendDot(color: const Color(0xFF0F9D58), label: 'Diesel'),
      ],
    );

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SectionHeader(title: 'Sales Trend'),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.open_in_full_rounded, size: 18),
                color: const Color(0xFF9CA3AF),
                tooltip: 'Expand',
                onPressed:
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        fullscreenDialog: true,
                        builder:
                            (_) => _TrendChartPage(
                              trend: trend,
                              rangeLabel: data.range.label,
                              buildChartData: buildChartData,
                              legend: legend,
                            ),
                      ),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: LineChart(buildChartData(compact: true)),
          ),
          const SizedBox(height: 8),
          legend,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<ManagementDashboardModel>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Failed to load\n${userFacingErrorMessage(snapshot.error)}',
                ),
              ],
            );
          }

          final data = snapshot.data!;

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              // Filter bar
              const SizedBox(height: 12),
              _buildFilterBar(),
              const SizedBox(height: 16),

              // Hero card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildHeroCard(data),
              ),
              const SizedBox(height: 12),

              // Contribution + trend
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildContributionSection(data),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildTrendSection(data),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Shared section card ───────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1E3A6E),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─── Section header ────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: Color(0xFF1A2561),
      ),
    );
  }
}

// ─── Filter pill ───────────────────────────────────────────────────────────────
class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1E5CBA) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF1E5CBA) : const Color(0xFFE5E7EB),
          ),
          boxShadow:
              selected
                  ? [
                    BoxShadow(
                      color: const Color(0xFF1E5CBA).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                  : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected ? Colors.white : const Color(0xFF6B7280),
              ),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: OneLineScaleText(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : const Color(0xFF374151),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Hero metric row (2 columns) ───────────────────────────────────────────────
class _HeroMetricRow extends StatelessWidget {
  const _HeroMetricRow({required this.left, required this.right});
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 16),
        Expanded(child: right),
      ],
    );
  }
}

class _HeroMetricCell extends StatelessWidget {
  const _HeroMetricCell({
    required this.label,
    required this.value,
    this.highlight = false,
  });
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OneLineScaleText(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 3),
        OneLineScaleText(
          value,
          style: TextStyle(
            color: highlight ? const Color(0xFF93C5FD) : Colors.white,
            fontSize: highlight ? 22 : 18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

// ─── Alert badge ───────────────────────────────────────────────────────────────
class _AlertBadge extends StatelessWidget {
  const _AlertBadge({
    required this.label,
    required this.count,
    required this.color,
  });
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final active = count > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color:
            active
                ? color.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? color.withValues(alpha: 0.5) : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OneLineScaleText(
            '$count',
            style: TextStyle(
              color: active ? color : Colors.white38,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 5),
          OneLineScaleText(
            label,
            style: TextStyle(
              color: active ? Colors.white70 : Colors.white38,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Contribution data classes ─────────────────────────────────────────────────
class _ContributionSlice {
  const _ContributionSlice({
    required this.label,
    required this.amount,
    required this.liters,
    required this.subtitle,
    required this.color,
  });
  final String label;
  final double amount;
  final PumpReadings liters;
  final String subtitle;
  final Color color;
}

class _PerformanceItem {
  const _PerformanceItem({
    required this.title,
    required this.subtitle,
    required this.liters,
    required this.collectedAmount,
    required this.computedSalesValue,
    required this.variance,
    required this.accent,
  });
  final String title;
  final String subtitle;
  final PumpReadings liters;
  final double collectedAmount;
  final double computedSalesValue;
  final double variance;
  final Color accent;
}

// ─── Contribution pie card ─────────────────────────────────────────────────────
class _ContributionPieCard extends StatelessWidget {
  const _ContributionPieCard({
    required this.title,
    required this.slices,
    required this.touchedIndex,
    required this.onTouched,
    required this.performanceItems,
  });
  final String title;
  final List<_ContributionSlice> slices;
  final int touchedIndex;
  final ValueChanged<int> onTouched;
  final List<_PerformanceItem> performanceItems;

  @override
  Widget build(BuildContext context) {
    final totalAmount = slices.fold<double>(0, (s, i) => s + i.amount);

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: title),
          const SizedBox(height: 12),
          _PieWithLeaderLabels(
            slices: slices,
            total: totalAmount,
            touchedIndex: touchedIndex,
            onTouched: onTouched,
          ),
          const SizedBox(height: 12),
          if (performanceItems.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'No data for this range.',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
              ),
            )
          else
            ...performanceItems.map(
              (item) => _PerformanceTile(
                title: item.title,
                subtitle: item.subtitle,
                liters: item.liters,
                collectedAmount: item.collectedAmount,
                computedSalesValue: item.computedSalesValue,
                variance: item.variance,
                accent: item.accent,
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Full pie with outside leader-line labels ─────────────────────────────────
class _PieWithLeaderLabels extends StatelessWidget {
  const _PieWithLeaderLabels({
    required this.slices,
    required this.total,
    required this.touchedIndex,
    required this.onTouched,
  });

  final List<_ContributionSlice> slices;
  final double total;
  final int touchedIndex;
  final ValueChanged<int> onTouched;

  @override
  Widget build(BuildContext context) {
    if (total <= 0 || slices.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No approved data in this range',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (ctx, constraints) {
        const double labelSpace = 68.0;
        const double chartH = 270.0;
        const double verticalPad = 20.0;
        const double touchExpansion = 6.0;
        final double chartW = constraints.maxWidth;
        final double maxPieDByWidth =
            chartW - (labelSpace * 2) - (touchExpansion * 2);
        const double maxPieDByHeight =
            chartH - (verticalPad * 2) - (touchExpansion * 2);
        final double pieD = math
            .min(maxPieDByWidth, maxPieDByHeight)
            .clamp(80.0, maxPieDByHeight);
        final double pieR = pieD / 2;
        final Offset center = Offset(chartW / 2, chartH / 2);
        final double pieBoxD = pieD + touchExpansion * 2;

        return SizedBox(
          width: chartW,
          height: chartH,
          child: Stack(
            children: [
              // Full pie — no center hole
              Positioned(
                left: center.dx - pieBoxD / 2,
                top: center.dy - pieBoxD / 2,
                width: pieBoxD,
                height: pieBoxD,
                child: PieChart(
                  PieChartData(
                    centerSpaceRadius: 0,
                    sectionsSpace: 2,
                    startDegreeOffset: -90,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        final isRelease =
                            event is FlTapUpEvent ||
                            event is FlLongPressEnd ||
                            event is FlPointerExitEvent ||
                            event is FlPanEndEvent;
                        if (isRelease) {
                          onTouched(-1);
                          return;
                        }
                        final idx =
                            response?.touchedSection?.touchedSectionIndex;
                        if (idx != null && idx >= 0) onTouched(idx);
                      },
                    ),
                    sections: [
                      for (int i = 0; i < slices.length; i++)
                        PieChartSectionData(
                          value: slices[i].amount,
                          color:
                              (touchedIndex == -1 || touchedIndex == i)
                                  ? slices[i].color
                                  : slices[i].color.withValues(alpha: 0.3),
                          radius:
                              touchedIndex == i ? pieR + touchExpansion : pieR,
                          title:
                              (slices[i].amount / total) >= 0.08
                                  ? '${((slices[i].amount / total) * 100).round()}%'
                                  : '',
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                          titlePositionPercentageOffset: 0.6,
                        ),
                    ],
                  ),
                ),
              ),
              // Leader lines + outside labels drawn via CustomPaint
              CustomPaint(
                size: Size(chartW, chartH),
                painter: _LeaderLinePainter(
                  slices: slices,
                  total: total,
                  center: center,
                  pieRadius: pieR,
                  touchedIndex: touchedIndex,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LeaderLinePainter extends CustomPainter {
  const _LeaderLinePainter({
    required this.slices,
    required this.total,
    required this.center,
    required this.pieRadius,
    required this.touchedIndex,
  });

  final List<_ContributionSlice> slices;
  final double total;
  final Offset center;
  final double pieRadius;
  final int touchedIndex;

  static double _toRad(double deg) => deg * math.pi / 180;

  void _drawLabel(
    Canvas canvas,
    String text,
    Offset anchor,
    bool isRight, {
    required Color color,
    required double fontSize,
    required bool bold,
    required double dy,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 80);
    final x = isRight ? anchor.dx + 5 : anchor.dx - 5 - tp.width;
    tp.paint(canvas, Offset(x, anchor.dy + dy));
  }

  @override
  void paint(Canvas canvas, Size size) {
    double startDeg = -90.0;

    for (int i = 0; i < slices.length; i++) {
      final pct = slices[i].amount / total;
      final sweepDeg = pct * 360;
      final midDeg = startDeg + sweepDeg / 2;
      final midRad = _toRad(midDeg);
      final cosA = math.cos(midRad);
      final sinA = math.sin(midRad);
      final isRight = cosA >= 0;
      final active = touchedIndex == -1 || touchedIndex == i;
      final color = slices[i].color;

      // Skip label for slices too tiny to be readable
      if (pct >= 0.03) {
        // Line: from pie edge → elbow → horizontal stub
        final edgePt = Offset(
          center.dx + (pieRadius + 2) * cosA,
          center.dy + (pieRadius + 2) * sinA,
        );
        final elbowPt = Offset(
          center.dx + (pieRadius + 14) * cosA,
          center.dy + (pieRadius + 14) * sinA,
        );
        final stubPt = Offset(
          elbowPt.dx + (isRight ? 10.0 : -10.0),
          elbowPt.dy,
        );

        final linePaint =
            Paint()
              ..color =
                  active
                      ? color.withValues(alpha: 0.6)
                      : color.withValues(alpha: 0.2)
              ..strokeWidth = 1.2
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round;

        canvas.drawLine(edgePt, elbowPt, linePaint);
        canvas.drawLine(elbowPt, stubPt, linePaint);

        // Small dot at stub end
        canvas.drawCircle(
          stubPt,
          2.0,
          Paint()..color = active ? color : color.withValues(alpha: 0.25),
        );

        // Name label
        final name =
            slices[i].label.length > 10
                ? '${slices[i].label.substring(0, 9)}.'
                : slices[i].label;
        _drawLabel(
          canvas,
          name,
          stubPt,
          isRight,
          color: active ? const Color(0xFF1A2561) : const Color(0xFFD1D5DB),
          fontSize: 10.0,
          bold: true,
          dy: -8,
        );
      }

      startDeg += sweepDeg;
    }
  }

  @override
  bool shouldRepaint(_LeaderLinePainter old) =>
      old.touchedIndex != touchedIndex ||
      old.slices.length != slices.length ||
      old.pieRadius != pieRadius;
}

// ─── Performance tile ──────────────────────────────────────────────────────────
class _PerformanceTile extends StatelessWidget {
  const _PerformanceTile({
    required this.title,
    required this.subtitle,
    required this.liters,
    required this.collectedAmount,
    required this.computedSalesValue,
    required this.variance,
    required this.accent,
  });
  final String title;
  final String subtitle;
  final PumpReadings liters;
  final double collectedAmount;
  final double computedSalesValue;
  final double variance;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final hasVariance = variance.abs() >= 0.01;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEF2FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OneLineScaleText(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFF1A2561),
                  ),
                ),
              ),
              if (hasVariance)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: OneLineScaleText(
                    'Var ${formatCurrency(variance)}',
                    alignment: Alignment.center,
                    style: const TextStyle(
                      color: Color(0xFF92400E),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MetricTag(
                  label: 'Petrol',
                  value: formatLiters(liters.petrol),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTag(
                  label: 'Diesel',
                  value: formatLiters(liters.diesel),
                ),
              ),
              if (liters.twoT > 0) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricTag(
                    label: '2T Oil',
                    value: formatLiters(liters.twoT),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MetricTag(
                  label: 'Collected',
                  value: formatCurrency(collectedAmount),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTag(
                  label: 'Computed',
                  value: formatCurrency(computedSalesValue),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Metric tag ────────────────────────────────────────────────────────────────
class _MetricTag extends StatelessWidget {
  const _MetricTag({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1E3A6E),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          OneLineScaleText(
            label,
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 3),
          OneLineScaleText(
            value,
            style: const TextStyle(
              color: Color(0xFF1A2561),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Legend dot ────────────────────────────────────────────────────────────────
class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        OneLineScaleText(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF374151),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─── Trend fullscreen page ─────────────────────────────────────────────────────
class _TrendChartPage extends StatelessWidget {
  const _TrendChartPage({
    required this.trend,
    required this.rangeLabel,
    required this.buildChartData,
    required this.legend,
  });
  final List<DashboardTrendPointModel> trend;
  final String rangeLabel;
  final LineChartData Function({required bool compact}) buildChartData;
  final Widget legend;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sales Trend',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            Text(
              rangeLabel,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            legend,
            const SizedBox(height: 16),
            SizedBox(
              height: 320,
              child: LineChart(buildChartData(compact: false)),
            ),
          ],
        ),
      ),
    );
  }
}
