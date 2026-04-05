import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/auth_models.dart';
import '../models/domain_models.dart';
import '../services/management_service.dart';
import '../utils/formatters.dart';
String _shortDateLabel(String raw) {
  final date = DateTime.tryParse(raw);
  if (date == null) return raw;
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
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

  String _errorText(Object? error) {
    return error.toString().replaceFirst('Exception: ', '');
  }
  String _preset = 'today';
  String? _fromDate;
  String? _toDate;
  int _pumpTouchedIndex = 0;
  int _staffTouchedIndex = 0;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<ManagementDashboardModel> _load() {
    return _managementService.fetchDashboard(
      preset: _preset == 'custom' ? null : _preset,
      fromDate: _fromDate,
      toDate: _toDate,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _applyPreset(String preset) async {
    setState(() {
      _preset = preset;
      _fromDate = null;
      _toDate = null;
      _pumpTouchedIndex = 0;
      _staffTouchedIndex = 0;
      _future = _load();
    });
  }

  Future<void> _pickCustomRange() async {
    final initialStart = DateTime.tryParse(_fromDate ?? '') ?? DateTime.now();
    final initialEnd = DateTime.tryParse(_toDate ?? '') ?? initialStart;
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      helpText: 'Select dashboard range',
    );
    if (range == null) {
      return;
    }

    final fromMonth = range.start.month.toString().padLeft(2, '0');
    final fromDay = range.start.day.toString().padLeft(2, '0');
    final toMonth = range.end.month.toString().padLeft(2, '0');
    final toDay = range.end.day.toString().padLeft(2, '0');

    setState(() {
      _preset = 'custom';
      _fromDate = '${range.start.year}-$fromMonth-$fromDay';
      _toDate = '${range.end.year}-$toMonth-$toDay';
      _pumpTouchedIndex = 0;
      _staffTouchedIndex = 0;
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

  Color _staffColor(String attendantName) {
    const palette = [
      Color(0xFF7C3AED),
      Color(0xFFEC4899),
      Color(0xFF0EA5E9),
      Color(0xFF14B8A6),
      Color(0xFFF97316),
      Color(0xFF6366F1),
    ];
    final index = attendantName.hashCode.abs() % palette.length;
    return palette[index];
  }

  Widget _buildRangeSelector(ManagementDashboardModel data) {
    final chips = <MapEntry<String, String>>[
      const MapEntry('today', 'Today'),
      const MapEntry('last7', 'Last 7 Days'),
      const MapEntry('thisMonth', 'This Month'),
      const MapEntry('lastMonth', 'Last Month'),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Owner View Range',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF293340),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            data.range.label,
            style: const TextStyle(
              color: Color(0xFF55606E),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ...chips.map(
                (chip) => ChoiceChip(
                  label: Text(chip.value),
                  selected: _preset == chip.key,
                  onSelected: (_) => _applyPreset(chip.key),
                ),
              ),
              ActionChip(
                avatar: const Icon(Icons.date_range_rounded, size: 18),
                label: Text(
                  _preset == 'custom' ? 'Custom Active' : 'Custom Range',
                ),
                onPressed: _pickCustomRange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(ManagementDashboardModel data) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF153A8A), Color(0xFF1E5CBA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'STATION OWNER SNAPSHOT',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data.station.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${data.range.label}  |  Approved entries only',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 18,
            runSpacing: 14,
            children: [
              _HeroMetric(
                label: 'Collected Amount',
                value: formatCurrency(data.paymentTotal),
              ),
              _HeroMetric(
                label: 'Petrol Sold',
                value: formatLiters(data.petrolSold),
              ),
              _HeroMetric(
                label: 'Diesel Sold',
                value: formatLiters(data.dieselSold),
              ),
              if (data.twoTSold > 0)
                _HeroMetric(
                  label: '2T Oil Sold',
                  value: formatLiters(data.twoTSold),
                ),
              _HeroMetric(
                label: 'Computed Sales',
                value: formatCurrency(data.revenue),
              ),
              _HeroMetric(
                label: 'Approved Entries',
                value: '${data.entriesCompleted}',
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatusPill(
                label: 'Variance Entries',
                value: '${data.varianceCount}',
                accent: const Color(0xFFF59E0B),
              ),
              _StatusPill(
                label: 'Open Flags',
                value: '${data.flaggedCount}',
                accent: const Color(0xFFEF4444),
              ),
              _StatusPill(
                label: 'Pending Users',
                value: '${data.pendingRequests}',
                accent: const Color(0xFF88F6DD),
              ),
            ],
          ),
        ],
      ),
    );
  }

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
    final staffSlices =
        data.attendantPerformance
            .map(
              (item) => _ContributionSlice(
                label: item.attendantName,
                amount: item.collectedAmount,
                liters: item.liters,
                subtitle:
                    item.pumpsWorked.isEmpty
                        ? 'No pumps recorded'
                        : item.pumpsWorked.join(', '),
                color: _staffColor(item.attendantName),
              ),
            )
            .toList();

    final pumpPerformanceItems =
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
    final staffPerformanceItems =
        data.attendantPerformance
            .map(
              (item) => _PerformanceItem(
                title: item.attendantName,
                subtitle:
                    item.pumpsWorked.isEmpty
                        ? '${item.activeDays} active days'
                        : '${item.activeDays} active days  |  ${item.pumpsWorked.join(', ')}',
                liters: item.liters,
                collectedAmount: item.collectedAmount,
                computedSalesValue: item.computedSalesValue,
                variance: item.variance,
                accent: _staffColor(item.attendantName),
              ),
            )
            .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 900;
        if (stacked) {
          return Column(
            children: [
              _ContributionPieCard(
                title: 'Pump Contribution',
                slices: pumpSlices,
                touchedIndex: _pumpTouchedIndex,
                onTouched: (index) {
                  setState(() {
                    _pumpTouchedIndex = index;
                  });
                },
                performanceItems: pumpPerformanceItems,
              ),
              const SizedBox(height: 14),
              _ContributionPieCard(
                title: 'Staff Contribution',
                slices: staffSlices,
                touchedIndex: _staffTouchedIndex,
                onTouched: (index) {
                  setState(() {
                    _staffTouchedIndex = index;
                  });
                },
                performanceItems: staffPerformanceItems,
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _ContributionPieCard(
                title: 'Pump Contribution',
                slices: pumpSlices,
                touchedIndex: _pumpTouchedIndex,
                onTouched: (index) {
                  setState(() {
                    _pumpTouchedIndex = index;
                  });
                },
                performanceItems: pumpPerformanceItems,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _ContributionPieCard(
                title: 'Staff Contribution',
                slices: staffSlices,
                touchedIndex: _staffTouchedIndex,
                onTouched: (index) {
                  setState(() {
                    _staffTouchedIndex = index;
                  });
                },
                performanceItems: staffPerformanceItems,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTrendSection(ManagementDashboardModel data) {
    final trend = data.trend;
    if (trend.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fuel Sales Trend',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF293340),
              ),
            ),
            SizedBox(height: 12),
            Text(
              'No approved sales trend is available for this range yet.',
              style: TextStyle(color: Color(0xFF55606E)),
            ),
          ],
        ),
      );
    }
    final maxY = trend.fold<double>(
      0,
      (m, p) => [m, p.petrolSold, p.dieselSold].reduce(
        (a, b) => a > b ? a : b,
      ),
    );
    final step = math.max(1, (trend.length / 5).ceil());

    LineChartData buildChartData({required bool compact}) {
      return LineChartData(
        minX: 0,
        maxX: (trend.length - 1).toDouble(),
        minY: 0,
        maxY: maxY <= 0 ? 10 : maxY * 1.2,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: Color(0xFFE9EEF7), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: compact
            ? const LineTouchData(enabled: false)
            : LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots.map((s) {
                    final idx = s.x.toInt();
                    final point = trend[idx.clamp(0, trend.length - 1)];
                    final isFirst = s.barIndex == 0;
                    return LineTooltipItem(
                      isFirst
                          ? '${_shortDateLabel(point.date)}\nPetrol ${formatLiters(s.y)}'
                          : 'Diesel ${formatLiters(s.y)}',
                      TextStyle(
                        color: isFirst
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
          leftTitles: compact
              ? const AxisTitles()
              : AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 48,
                    interval: maxY <= 0 ? 10 : (maxY * 1.2) / 4,
                    getTitlesWidget: (value, _) => Text(
                      '${value.toInt()} L',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF55606E),
                      ),
                    ),
                  ),
                ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, _) {
                final index = value.toInt();
                if (index < 0 || index >= trend.length) {
                  return const SizedBox.shrink();
                }
                final show = compact
                    ? index % step == 0
                    : (trend.length <= 10 || index % (trend.length / 8).ceil() == 0);
                if (!show) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _shortDateLabel(trend[index].date),
                    style: const TextStyle(fontSize: 10, color: Color(0xFF55606E)),
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
              getDotPainter: (p, i, b, j) => FlDotCirclePainter(
                radius: 3,
                color: const Color(0xFF1E5CBA),
                strokeWidth: 0,
                strokeColor: Colors.transparent,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF1E5CBA).withValues(alpha: 0.08),
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
              getDotPainter: (p, i, b, j) => FlDotCirclePainter(
                radius: 3,
                color: const Color(0xFF0F9D58),
                strokeWidth: 0,
                strokeColor: Colors.transparent,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF0F9D58).withValues(alpha: 0.08),
            ),
          ),
        ],
      );
    }

    Widget legend() => Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFF1E5CBA),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'Petrol',
              style: TextStyle(fontSize: 12, color: Color(0xFF293340), fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 16),
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFF0F9D58),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'Diesel',
              style: TextStyle(fontSize: 12, color: Color(0xFF293340), fontWeight: FontWeight.w600),
            ),
          ],
        );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Daily Trend',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF293340),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.open_in_full_rounded, size: 20),
                color: const Color(0xFF55606E),
                tooltip: 'Expand',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    fullscreenDialog: true,
                    builder: (_) => _TrendChartPage(
                      trend: trend,
                      rangeLabel: data.range.label,
                      buildChartData: buildChartData,
                      legend: legend(),
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
          const SizedBox(height: 10),
          legend(),
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
              padding: const EdgeInsets.all(24),
              children: [Text('Failed to load dashboard\n${_errorText(snapshot.error)}')],
            );
          }

          final data = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 120),
            children: [
              Text(
                data.station.name,
                style: const TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF55606E),
                ),
              ),
              const SizedBox(height: 16),
              _buildRangeSelector(data),
              const SizedBox(height: 16),
              _buildHeroCard(data),
              const SizedBox(height: 16),
              _buildContributionSection(data),
              const SizedBox(height: 16),
              _buildTrendSection(data),
            ],
          );
        },
      ),
    );
  }
}

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

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(color: accent, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF293340),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

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
    final totalAmount = slices.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF293340),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child:
                totalAmount <= 0
                    ? const Center(
                      child: Text('No approved data in this range'),
                    )
                    : Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            sectionsSpace: 3,
                            centerSpaceRadius: 44,
                            pieTouchData: PieTouchData(
                              touchCallback: (event, response) {
                                final sectionIndex =
                                    response
                                        ?.touchedSection
                                        ?.touchedSectionIndex;
                                if (sectionIndex == null) {
                                  return;
                                }
                                onTouched(sectionIndex);
                              },
                            ),
                            sections: [
                              for (
                                int index = 0;
                                index < slices.length;
                                index++
                              )
                                PieChartSectionData(
                                  value: slices[index].amount,
                                  color: slices[index].color,
                                  radius: touchedIndex == index ? 52 : 44,
                                  title:
                                      '${((slices[index].amount / totalAmount) * 100).round()}%',
                                  titleStyle: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Collected',
                              style: TextStyle(
                                color: Color(0xFF55606E),
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              formatCurrency(totalAmount),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF293340),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ],
                    ),
          ),
          const SizedBox(height: 12),
          if (performanceItems.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('No data for this range.'),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: Color(0xFF293340),
                  ),
                ),
              ),
              if (variance.abs() >= 0.01)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEDD5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Variance ${formatCurrency(variance)}',
                    style: const TextStyle(
                      color: Color(0xFFB45309),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Color(0xFF55606E))),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _MetricTag(label: 'Petrol', value: formatLiters(liters.petrol)),
              _MetricTag(label: 'Diesel', value: formatLiters(liters.diesel)),
              if (liters.twoT > 0)
                _MetricTag(label: '2T Oil', value: formatLiters(liters.twoT)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _MetricTag(
                label: 'Collected',
                value: formatCurrency(collectedAmount),
              ),
              _MetricTag(
                label: 'Computed Sales',
                value: formatCurrency(computedSalesValue),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF55606E),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF293340),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

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
              'Daily Trend',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            Text(
              rangeLabel,
              style: const TextStyle(fontSize: 12, color: Color(0xFF55606E)),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
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
