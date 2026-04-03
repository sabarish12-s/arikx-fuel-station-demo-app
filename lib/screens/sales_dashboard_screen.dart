import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/sales_service.dart';
import '../utils/formatters.dart';

class SalesDashboardScreen extends StatefulWidget {
  const SalesDashboardScreen({
    super.key,
    this.onOpenClosingStock,
    this.onOpenEntryHistory,
    this.onOpenDailySummary,
  });

  final VoidCallback? onOpenClosingStock;
  final VoidCallback? onOpenEntryHistory;
  final VoidCallback? onOpenDailySummary;

  @override
  State<SalesDashboardScreen> createState() => _SalesDashboardScreenState();
}

class _SalesDashboardScreenState extends State<SalesDashboardScreen> {
  final SalesService _salesService = SalesService();
  late Future<SalesDashboardModel> _future;

  @override
  void initState() {
    super.initState();
    _future = _salesService.fetchDashboard();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _salesService.fetchDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<SalesDashboardModel>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 80),
                Text(
                  'Failed to load dashboard\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ],
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
              const SizedBox(height: 6),
              const Text(
                'Sales Dashboard',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF293340),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6799FB), Color(0xFF1E5CBA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'REVENUE TODAY',
                      style: TextStyle(
                        color: Color(0xCCFFFFFF),
                        fontSize: 11,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formatCurrency(data.revenue),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniMetric(
                            label: 'Petrol Sold',
                            value: formatLiters(data.petrolSold),
                          ),
                        ),
                        Expanded(
                          child: _MiniMetric(
                            label: 'Diesel Sold',
                            value: formatLiters(data.dieselSold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniMetric(
                            label: 'Profit',
                            value: formatCurrency(data.profit),
                          ),
                        ),
                        Expanded(
                          child: _MiniMetric(
                            label: 'Shifts Done',
                            value: '${data.shiftsCompleted}/3',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _ActionCard(
                title: 'Enter Closing Stock',
                subtitle:
                    'Next shift: ${formatShiftLabel(data.nextShift)} for ${formatDateLabel(data.date)}',
                icon: Icons.propane_tank_outlined,
                iconBg: const Color(0xFF88F6DD),
                onTap: widget.onOpenClosingStock,
              ),
              const SizedBox(height: 12),
              _ActionCard(
                title: 'Entry History',
                subtitle: 'Review past submissions and adjustments',
                icon: Icons.list_alt_rounded,
                iconBg: const Color(0xFFD8E3F4),
                onTap: widget.onOpenEntryHistory,
              ),
              const SizedBox(height: 12),
              _ActionCard(
                title: 'Daily Summary',
                subtitle: 'Sales and inventory analytics',
                icon: Icons.analytics_outlined,
                iconBg: const Color(0xFFE5CEFF),
                onTap: widget.onOpenDailySummary,
              ),
              const SizedBox(height: 20),
              const Text(
                'Live Shift Status',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF293340),
                ),
              ),
              const SizedBox(height: 10),
              ...data.todaysEntries.map(
                (entry) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: entry.flagged
                              ? const Color(0xFFFEE2E2)
                              : const Color(0xFFDFF7EE),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          formatShiftLabel(entry.shift),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: entry.flagged
                                ? const Color(0xFFB91C1C)
                                : const Color(0xFF047857),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${formatLiters(entry.totals.sold.petrol)} petrol, ${formatLiters(entry.totals.sold.diesel)} diesel',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF293340),
                              ),
                            ),
                            Text(
                              entry.flagged ? entry.varianceNote : entry.status,
                              style: const TextStyle(
                                color: Color(0xFF55606E),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});

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
            color: Color(0xCCFFFFFF),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconBg,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconBg;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: const Color(0xFF293340)),
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
                        fontSize: 18,
                        color: Color(0xFF293340),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF55606E),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF55606E)),
            ],
          ),
        ),
      ),
    );
  }
}
