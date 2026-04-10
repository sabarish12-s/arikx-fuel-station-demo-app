import 'dart:async';

import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/sales_service.dart';
import '../utils/formatters.dart';
import '../widgets/clay_widgets.dart';

class SalesDashboardScreen extends StatefulWidget {
  const SalesDashboardScreen({
    super.key,
    this.onOpenClosingStock,
    this.onOpenEntryHistory,
    this.onOpenDailySummary,
  });

  final FutureOr<void> Function()? onOpenClosingStock;
  final FutureOr<void> Function()? onOpenEntryHistory;
  final FutureOr<void> Function()? onOpenDailySummary;

  @override
  State<SalesDashboardScreen> createState() => _SalesDashboardScreenState();
}

class _SalesDashboardScreenState extends State<SalesDashboardScreen> {
  final SalesService _salesService = SalesService();
  late Future<SalesDashboardModel> _future;
  String? _busyAction;

  String _errorText(Object? error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

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

  Future<void> _runAction(
    String actionKey,
    FutureOr<void> Function()? action,
  ) async {
    if (_busyAction != null || action == null) {
      return;
    }
    setState(() {
      _busyAction = actionKey;
    });
    try {
      await Future<void>.sync(action);
    } finally {
      if (mounted) {
        setState(() {
          _busyAction = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<SalesDashboardModel>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const ColoredBox(
              color: kClayBg,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                ClayCard(
                  margin: const EdgeInsets.only(top: 80),
                  child: Text(
                    'Failed to load dashboard\n${_errorText(snapshot.error)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: kClayPrimary,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            );
          }

          final data = snapshot.data!;
          final approvedEntries = data.todaysEntries
              .where((entry) => entry.status == 'approved')
              .length;
          final pendingEntries = data.todaysEntries.length - approvedEntries;
          final flaggedEntries = data.todaysEntries
              .where((entry) => entry.flagged)
              .length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Text(
                data.station.name,
                style: const TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w800,
                  color: kClaySub,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [kClayHeroStart, kClayHeroEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: kClayHeroEnd.withValues(alpha: 0.45),
                      offset: const Offset(0, 10),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatDateLabel(data.date),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data.station.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Today Revenue ${formatCurrency(data.revenue)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _HeroStatChip(
                          label: 'Revenue',
                          value: formatCurrency(data.revenue),
                        ),
                        _HeroStatChip(
                          label: 'Liters',
                          value: formatLiters(
                            data.petrolSold + data.dieselSold + data.twoTSold,
                          ),
                        ),
                        _HeroStatChip(
                          label: 'Flagged',
                          value: '$flaggedEntries',
                        ),
                        _HeroStatChip(
                          label: 'Pending',
                          value: '$pendingEntries',
                        ),
                        _HeroStatChip(
                          label: 'Approved',
                          value: '$approvedEntries',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _ActionCard(
                title: 'Enter Daily Sales',
                icon: Icons.propane_tank_outlined,
                iconBg: const Color(0xFFD7F2FB),
                loading: _busyAction == 'sales',
                onTap: () => _runAction('sales', widget.onOpenClosingStock),
              ),
              const SizedBox(height: 12),
              _ActionCard(
                title: 'Entry History',
                icon: Icons.list_alt_rounded,
                iconBg: const Color(0xFFE8ECF9),
                loading: _busyAction == 'history',
                onTap: () => _runAction('history', widget.onOpenEntryHistory),
              ),
              const SizedBox(height: 12),
              _ActionCard(
                title: 'Daily Summary',
                icon: Icons.analytics_outlined,
                iconBg: const Color(0xFFEDE4FF),
                loading: _busyAction == 'summary',
                onTap: () => _runAction('summary', widget.onOpenDailySummary),
              ),
              const SizedBox(height: 18),
              const Text(
                'TODAY\'S ENTRIES',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w800,
                  color: kClaySub,
                ),
              ),
              const SizedBox(height: 8),
              if (data.todaysEntries.isEmpty)
                const ClayCard(
                  child: Text(
                    'No entries have been created today.',
                    style: TextStyle(
                      color: kClaySub,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                ...data.todaysEntries.map(
                  (entry) => ClayCard(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: entry.flagged
                                ? const Color(
                                    0xFFCE5828,
                                  ).withValues(alpha: 0.14)
                                : const Color(
                                    0xFF1A3A7A,
                                  ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            entry.flagged
                                ? Icons.flag_rounded
                                : Icons.receipt_long_rounded,
                            color: entry.flagged
                                ? const Color(0xFFCE5828)
                                : kClayHeroStart,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Daily Entry',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: kClayPrimary,
                                      ),
                                    ),
                                  ),
                                  _DashboardEntryBadge(
                                    flagged: entry.flagged,
                                    status: entry.status,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${formatLiters(entry.totals.sold.petrol)} petrol, ${formatLiters(entry.totals.sold.diesel)} diesel, ${formatLiters(entry.totals.sold.twoT)} 2T oil',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: kClayPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                entry.flagged
                                    ? entry.varianceNote
                                    : 'Collected ${formatCurrency(entry.paymentTotal)} • ${entry.status}',
                                style: const TextStyle(
                                  color: kClaySub,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
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

class _HeroStatChip extends StatelessWidget {
  const _HeroStatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label  $value',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.icon,
    required this.iconBg,
    required this.loading,
    this.onTap,
  });

  final String title;
  final IconData icon;
  final Color iconBg;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: loading ? null : onTap,
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
                  child: Icon(icon, color: kClayPrimary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    loading ? '$title  Loading...' : title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: kClayPrimary,
                    ),
                  ),
                ),
                loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            kClayHeroStart,
                          ),
                        ),
                      )
                    : const Icon(Icons.chevron_right_rounded, color: kClaySub),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardEntryBadge extends StatelessWidget {
  const _DashboardEntryBadge({required this.flagged, required this.status});

  final bool flagged;
  final String status;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final String label;
    if (flagged) {
      bg = const Color(0xFFCE5828);
      fg = Colors.white;
      label = 'FLAGGED';
    } else if (status.trim().toLowerCase() == 'approved') {
      bg = const Color(0xFF2AA878);
      fg = Colors.white;
      label = 'APPROVED';
    } else {
      bg = const Color(0xFFE8ECF9);
      fg = kClayHeroStart;
      label = status.toUpperCase();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}
