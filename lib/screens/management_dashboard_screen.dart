import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/auth_models.dart';
import '../models/domain_models.dart';
import '../services/management_service.dart';
import '../utils/formatters.dart';

class ManagementDashboardScreen extends StatefulWidget {
  const ManagementDashboardScreen({
    super.key,
    required this.user,
    this.onOpenEntries,
    this.onOpenReports,
    this.onOpenInventory,
    this.onOpenUsers,
    this.onOpenSettings,
  });

  final AuthUser user;
  final VoidCallback? onOpenEntries;
  final VoidCallback? onOpenReports;
  final VoidCallback? onOpenInventory;
  final VoidCallback? onOpenUsers;
  final VoidCallback? onOpenSettings;

  @override
  State<ManagementDashboardScreen> createState() =>
      _ManagementDashboardScreenState();
}

class _ManagementDashboardScreenState extends State<ManagementDashboardScreen> {
  final ManagementService _managementService = ManagementService();
  late Future<ManagementDashboardModel> _future;

  @override
  void initState() {
    super.initState();
    _future = _managementService.fetchDashboard();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _managementService.fetchDashboard();
    });
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
          const int totalEntries = 1;
          final double completionRatio = data.entriesCompleted > 0 ? 1 : 0;
          final double totalVolume =
              data.petrolSold + data.dieselSold + data.twoTSold;
          final double profitRatio =
              data.revenue <= 0
                  ? 0
                  : (data.profit / data.revenue).clamp(0, 1).toDouble();

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
              Container(
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
                      'TODAY AT A GLANCE',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatCurrency(data.revenue),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Live station revenue with operational health below',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _HeroMetric(
                            label: 'Profit',
                            value: formatCurrency(data.profit),
                          ),
                        ),
                        Expanded(
                          child: _HeroMetric(
                            label: 'Pending users',
                            value: '${data.pendingRequests}',
                          ),
                        ),
                        Expanded(
                          child: _HeroMetric(
                            label: 'Flagged',
                            value: '${data.flaggedCount}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Daily entry completion',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 12,
                        value: completionRatio,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF88F6DD),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${data.entriesCompleted} of $totalEntries daily entries completed',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _MiniKpiCard(
                      title: 'Petrol sold',
                      value: formatLiters(data.petrolSold),
                      accent: const Color(0xFF1E5CBA),
                      icon: Icons.opacity_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MiniKpiCard(
                      title: 'Diesel sold',
                      value: formatLiters(data.dieselSold),
                      accent: const Color(0xFF006C5C),
                      icon: Icons.local_shipping_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MiniKpiCard(
                      title: '2T oil sold',
                      value: formatLiters(data.twoTSold),
                      accent: const Color(0xFFB45309),
                      icon: Icons.opacity_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _ChartCard(
                      title: 'Fuel Mix',
                      subtitle: 'Today by volume',
                      child: SizedBox(
                        height: 180,
                        child:
                            totalVolume <= 0
                                ? const Center(
                                  child: Text('No fuel movement yet'),
                                )
                                : Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    PieChart(
                                      PieChartData(
                                        sectionsSpace: 3,
                                        centerSpaceRadius: 40,
                                        sections: [
                                          PieChartSectionData(
                                            value: data.petrolSold,
                                            color: const Color(0xFF1E5CBA),
                                            title:
                                                '${((data.petrolSold / totalVolume) * 100).round()}%',
                                            radius: 42,
                                            titleStyle: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12,
                                            ),
                                          ),
                                          PieChartSectionData(
                                            value: data.dieselSold,
                                            color: const Color(0xFF0F9D58),
                                            title:
                                                '${((data.dieselSold / totalVolume) * 100).round()}%',
                                            radius: 42,
                                            titleStyle: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12,
                                            ),
                                          ),
                                          if (data.twoTSold > 0)
                                            PieChartSectionData(
                                              value: data.twoTSold,
                                              color: const Color(0xFFB45309),
                                              title:
                                                  '${((data.twoTSold / totalVolume) * 100).round()}%',
                                              radius: 42,
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
                                          'Total',
                                          style: TextStyle(
                                            color: Color(0xFF55606E),
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          formatLiters(totalVolume),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF293340),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ChartCard(
                      title: 'Operations Health',
                      subtitle: 'Profit and review status',
                      child: Column(
                        children: [
                          SizedBox(
                            height: 140,
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: 100,
                                gridData: const FlGridData(show: false),
                                borderData: FlBorderData(show: false),
                                titlesData: FlTitlesData(
                                  topTitles: const AxisTitles(),
                                  rightTitles: const AxisTitles(),
                                  leftTitles: const AxisTitles(),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        const labels = [
                                          'Profit',
                                          'Approved',
                                          'Flagged',
                                        ];
                                        final index = value.toInt();
                                        if (index < 0 ||
                                            index >= labels.length) {
                                          return const SizedBox.shrink();
                                        }
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            top: 8,
                                          ),
                                          child: Text(
                                            labels[index],
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                barTouchData: BarTouchData(enabled: false),
                                barGroups: [
                                  BarChartGroupData(
                                    x: 0,
                                    barRods: [
                                      BarChartRodData(
                                        toY: profitRatio * 100,
                                        width: 22,
                                        borderRadius: BorderRadius.circular(8),
                                        color: const Color(0xFF0F9D58),
                                      ),
                                    ],
                                  ),
                                  BarChartGroupData(
                                    x: 1,
                                    barRods: [
                                      BarChartRodData(
                                        toY:
                                            totalEntries == 0
                                                ? 0
                                                : (approvedEntryCount(data) /
                                                        totalEntries) *
                                                    100,
                                        width: 22,
                                        borderRadius: BorderRadius.circular(8),
                                        color: const Color(0xFF1E5CBA),
                                      ),
                                    ],
                                  ),
                                  BarChartGroupData(
                                    x: 2,
                                    barRods: [
                                      BarChartRodData(
                                        toY:
                                            totalEntries == 0
                                                ? 0
                                                : (data.flaggedCount /
                                                        totalEntries) *
                                                    100,
                                        width: 22,
                                        borderRadius: BorderRadius.circular(8),
                                        color: const Color(0xFFB91C1C),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _LegendRow(
                            color: const Color(0xFF0F9D58),
                            label:
                                'Profit margin ${(profitRatio * 100).toStringAsFixed(0)}%',
                          ),
                          _LegendRow(
                            color: const Color(0xFF1E5CBA),
                            label:
                                'Approved ${approvedEntryCount(data)} / $totalEntries',
                          ),
                          _LegendRow(
                            color: const Color(0xFFB91C1C),
                            label: 'Flagged ${data.flaggedCount}',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _ChartCard(
                title: 'Action Center',
                subtitle: 'Jump straight into the operational areas',
                child: Column(
                  children: [
                    _DashboardAction(
                      title: 'Entry Management',
                      subtitle:
                          'Review, edit, approve, or add live daily entries',
                      icon: Icons.edit_note_rounded,
                      onTap: widget.onOpenEntries,
                    ),
                    const SizedBox(height: 10),
                    _DashboardAction(
                      title: 'Monthly Reports',
                      subtitle:
                          'Open charts, date filters, exports, and sharing',
                      icon: Icons.bar_chart_rounded,
                      onTap: widget.onOpenReports,
                    ),
                    const SizedBox(height: 10),
                    _DashboardAction(
                      title: 'Inventory Dashboard',
                      subtitle: 'Track meter-based sales and selling prices',
                      icon: Icons.local_gas_station_rounded,
                      onTap: widget.onOpenInventory,
                    ),
                    const SizedBox(height: 10),
                    _DashboardAction(
                      title: 'Settings',
                      subtitle:
                          widget.user.role == 'superadmin'
                              ? 'Manage users, pricing, fuel types, and station setup'
                              : 'Manage station setup, pricing, and fuel catalog',
                      icon: Icons.settings_rounded,
                      onTap: widget.onOpenSettings ?? widget.onOpenUsers,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _ChartCard(
                title: 'Recent Entries Snapshot',
                subtitle: 'Visual revenue bars with live review status',
                child: Column(
                  children:
                      data.recentEntries.isEmpty
                          ? const [
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Text('No recent entries yet'),
                            ),
                          ]
                          : data.recentEntries
                              .map(
                                (entry) => _RecentEntryTile(
                                  entry: entry,
                                  maxRevenue: maxRevenue(data),
                                ),
                              )
                              .toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  int approvedEntryCount(ManagementDashboardModel data) {
    return data.recentEntries
        .where((entry) => entry.status == 'approved')
        .length;
  }

  double maxRevenue(ManagementDashboardModel data) {
    double max = 0;
    for (final entry in data.recentEntries) {
      if (entry.revenue > max) {
        max = entry.revenue;
      }
    }
    return max <= 0 ? 1 : max;
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
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
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _MiniKpiCard extends StatelessWidget {
  const _MiniKpiCard({
    required this.title,
    required this.value,
    required this.accent,
    required this.icon,
  });

  final String title;
  final String value;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: accent.withValues(alpha: 0.12),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF55606E),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF293340),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
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
          child,
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF55606E)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardAction extends StatelessWidget {
  const _DashboardAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8F9FF),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFE9EEF7),
                child: Icon(icon, color: const Color(0xFF1E5CBA)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF293340),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Color(0xFF55606E)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentEntryTile extends StatelessWidget {
  const _RecentEntryTile({required this.entry, required this.maxRevenue});

  final ShiftEntryModel entry;
  final double maxRevenue;

  @override
  Widget build(BuildContext context) {
    final Color statusColor =
        entry.flagged
            ? const Color(0xFFB91C1C)
            : entry.status == 'approved'
            ? const Color(0xFF0F9D58)
            : const Color(0xFF1E5CBA);
    final double ratio = (entry.revenue / maxRevenue).clamp(0, 1).toDouble();

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
              Expanded(
                child: Text(
                  formatDateLabel(entry.date),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF293340),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  entry.flagged ? 'flagged' : entry.status,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: ratio,
              backgroundColor: Colors.white,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              Text('Revenue ${formatCurrency(entry.revenue)}'),
              Text('Collected ${formatCurrency(entry.paymentTotal)}'),
              Text('Profit ${formatCurrency(entry.profit)}'),
              Text('Petrol ${formatLiters(entry.totals.sold.petrol)}'),
              Text('Diesel ${formatLiters(entry.totals.sold.diesel)}'),
              Text('2T Oil ${formatLiters(entry.totals.sold.twoT)}'),
            ],
          ),
          if (entry.varianceNote.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                entry.varianceNote,
                style: const TextStyle(color: Color(0xFFB91C1C)),
              ),
            ),
        ],
      ),
    );
  }
}
