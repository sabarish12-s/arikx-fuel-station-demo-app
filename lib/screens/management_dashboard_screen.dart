import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/auth_models.dart';
import '../models/domain_models.dart';
import '../services/management_service.dart';
import '../utils/formatters.dart';

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

  String _shortDateLabel(String raw) {
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
    return '${months[date.month - 1]} ${date.day}';
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
    final totalLiters = data.petrolSold + data.dieselSold + data.twoTSold;
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
                label: 'Total Liters',
                value: formatLiters(totalLiters),
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
                liters: item.totalLiters,
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
                liters: item.totalLiters,
                subtitle:
                    item.pumpsWorked.isEmpty
                        ? 'No pumps recorded'
                        : item.pumpsWorked.join(', '),
                color: _staffColor(item.attendantName),
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
                subtitle: 'Slices by collected amount, legend shows liters too',
                slices: pumpSlices,
                touchedIndex: _pumpTouchedIndex,
                onTouched: (index) {
                  setState(() {
                    _pumpTouchedIndex = index;
                  });
                },
              ),
              const SizedBox(height: 14),
              _ContributionPieCard(
                title: 'Staff Contribution',
                subtitle: 'Attendants grouped across all approved entries',
                slices: staffSlices,
                touchedIndex: _staffTouchedIndex,
                onTouched: (index) {
                  setState(() {
                    _staffTouchedIndex = index;
                  });
                },
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
                subtitle: 'Slices by collected amount, legend shows liters too',
                slices: pumpSlices,
                touchedIndex: _pumpTouchedIndex,
                onTouched: (index) {
                  setState(() {
                    _pumpTouchedIndex = index;
                  });
                },
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _ContributionPieCard(
                title: 'Staff Contribution',
                subtitle: 'Attendants grouped across all approved entries',
                slices: staffSlices,
                touchedIndex: _staffTouchedIndex,
                onTouched: (index) {
                  setState(() {
                    _staffTouchedIndex = index;
                  });
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTrendSection(ManagementDashboardModel data) {
    if (data.range.isSingleDay || data.trend.length <= 1) {
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
              'Daily Trend',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF293340),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Single-day view. Switch to a wider range to compare daily movement.',
              style: TextStyle(color: Color(0xFF55606E)),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 18,
              runSpacing: 12,
              children: [
                _TrendMetric(
                  label: 'Collected',
                  value: formatCurrency(data.paymentTotal),
                ),
                _TrendMetric(
                  label: 'Computed Sales',
                  value: formatCurrency(data.revenue),
                ),
                _TrendMetric(
                  label: 'Total Liters',
                  value: formatLiters(
                    data.petrolSold + data.dieselSold + data.twoTSold,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final maxAmount = data.trend.fold<double>(
      0,
      (max, item) => item.collectedAmount > max ? item.collectedAmount : max,
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
          const Text(
            'Daily Trend',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF293340),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Collected amount by day for ${data.range.label.toLowerCase()}',
            style: const TextStyle(color: Color(0xFF55606E)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                maxY: maxAmount <= 0 ? 1 : maxAmount * 1.2,
                alignment: BarChartAlignment.spaceAround,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= data.trend.length) {
                          return const SizedBox.shrink();
                        }
                        final showLabel =
                            data.trend.length <= 8 || index.isEven;
                        if (!showLabel) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _shortDateLabel(data.trend[index].date),
                            style: const TextStyle(fontSize: 11),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (int index = 0; index < data.trend.length; index++)
                    BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: data.trend[index].collectedAmount,
                          width: 16,
                          color: const Color(0xFF1E5CBA),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPumpPerformance(ManagementDashboardModel data) {
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
            'Pump Performance',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF293340),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Volume, amount, and attendants by pump for the selected range.',
            style: TextStyle(color: Color(0xFF55606E)),
          ),
          const SizedBox(height: 14),
          if (data.pumpPerformance.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text('No approved pump data for this range.'),
            )
          else
            ...data.pumpPerformance.map(
              (item) => _PerformanceTile(
                title: formatPumpLabel(item.pumpId, item.pumpLabel),
                subtitle:
                    item.attendantsSeen.isEmpty
                        ? 'No attendants recorded'
                        : item.attendantsSeen.join(', '),
                liters: item.liters,
                totalLiters: item.totalLiters,
                collectedAmount: item.collectedAmount,
                computedSalesValue: item.computedSalesValue,
                variance: item.variance,
                accent: _pumpColor(item.pumpId),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAttendantPerformance(ManagementDashboardModel data) {
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
            'Attendant Performance',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF293340),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Staff contribution across pumps, with liters and collection totals.',
            style: TextStyle(color: Color(0xFF55606E)),
          ),
          const SizedBox(height: 14),
          if (data.attendantPerformance.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text('No approved attendant data for this range.'),
            )
          else
            ...data.attendantPerformance.map(
              (item) => _PerformanceTile(
                title: item.attendantName,
                subtitle:
                    item.pumpsWorked.isEmpty
                        ? '${item.activeDays} active days'
                        : '${item.activeDays} active days  |  ${item.pumpsWorked.join(', ')}',
                liters: item.liters,
                totalLiters: item.totalLiters,
                collectedAmount: item.collectedAmount,
                computedSalesValue: item.computedSalesValue,
                variance: item.variance,
                accent: _staffColor(item.attendantName),
              ),
            ),
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
              children: [Text('Failed to load dashboard\n${snapshot.error}')],
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
              const SizedBox(height: 16),
              _buildPumpPerformance(data),
              const SizedBox(height: 16),
              _buildAttendantPerformance(data),
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
  final double liters;
  final String subtitle;
  final Color color;
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
        color: accent.withValues(alpha: 0.16),
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
    required this.subtitle,
    required this.slices,
    required this.touchedIndex,
    required this.onTouched,
  });

  final String title;
  final String subtitle;
  final List<_ContributionSlice> slices;
  final int touchedIndex;
  final ValueChanged<int> onTouched;

  @override
  Widget build(BuildContext context) {
    final totalAmount = slices.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );
    final selected =
        slices.isEmpty
            ? null
            : slices[touchedIndex.clamp(0, slices.length - 1)];

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
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Color(0xFF55606E))),
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
          if (selected != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FF),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selected.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF293340),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selected.subtitle,
                    style: const TextStyle(color: Color(0xFF55606E)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Amount ${formatCurrency(selected.amount)}  |  Volume ${formatLiters(selected.liters)}',
                    style: const TextStyle(
                      color: Color(0xFF293340),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          ...slices.map(
            (slice) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: slice.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          slice.label,
                          style: const TextStyle(
                            color: Color(0xFF293340),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Amount ${formatCurrency(slice.amount)}  |  ${formatLiters(slice.liters)}',
                          style: const TextStyle(color: Color(0xFF55606E)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendMetric extends StatelessWidget {
  const _TrendMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF55606E),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF293340),
              fontWeight: FontWeight.w900,
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
    required this.totalLiters,
    required this.collectedAmount,
    required this.computedSalesValue,
    required this.variance,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final PumpReadings liters;
  final double totalLiters;
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
              _MetricTag(
                label: 'Total Liters',
                value: formatLiters(totalLiters),
              ),
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
