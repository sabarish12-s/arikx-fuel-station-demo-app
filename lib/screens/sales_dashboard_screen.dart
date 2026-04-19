import 'dart:async';

import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/api_response_cache.dart';
import '../services/sales_service.dart';
import '../utils/formatters.dart';
import '../utils/user_facing_errors.dart';
import '../widgets/clay_widgets.dart';
import '../widgets/daily_fuel_widgets.dart';
import '../widgets/responsive_text.dart';
import 'credit_ledger_screen.dart';
import 'daily_fuel_history_screen.dart';

class SalesDashboardScreen extends StatefulWidget {
  const SalesDashboardScreen({super.key, this.onOpenSalesEntry});

  final Future<void> Function()? onOpenSalesEntry;

  @override
  State<SalesDashboardScreen> createState() => _SalesDashboardScreenState();
}

class _SalesDashboardScreenState extends State<SalesDashboardScreen> {
  final SalesService _salesService = SalesService();
  late Future<_SalesDashboardBundle> _future;
  late final StreamSubscription<ApiResponseCacheUpdate> _cacheSubscription;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _cacheSubscription = ApiResponseCache.updates.listen((update) {
      if (!mounted ||
          !update.background ||
          !update.path.startsWith('/sales/dashboard')) {
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

  String _errorText(Object? error) {
    return userFacingErrorMessage(error);
  }

  String _apiDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  DateTime _previousDay(DateTime base) {
    return DateTime(
      base.year,
      base.month,
      base.day,
    ).subtract(const Duration(days: 1));
  }

  Future<_SalesDashboardBundle> _load({bool forceRefresh = false}) async {
    final today = await _salesService.fetchDashboard(
      forceRefresh: forceRefresh,
    );
    final parsedToday = DateTime.tryParse(today.date) ?? DateTime.now();
    final yesterday = await _salesService.fetchDashboardForDate(
      date: _apiDate(_previousDay(parsedToday)),
      forceRefresh: forceRefresh,
    );
    return _SalesDashboardBundle(today: today, yesterday: yesterday);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load(forceRefresh: true);
    });
    await _future;
  }

  Future<void> _openCreditLedger() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const CreditLedgerScreen()));
  }

  Future<void> _openSalesEntryPage() async {
    final onOpenSalesEntry = widget.onOpenSalesEntry;
    if (onOpenSalesEntry == null) {
      return;
    }
    await onOpenSalesEntry();
    if (!mounted) return;
    await _refresh();
  }

  Future<void> _openDailyFuelHistory() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const DailyFuelHistoryScreen()),
    );
    if (!mounted) {
      return;
    }
    await _refresh();
  }

  List<_PumpCashSummary> _todayCashByPump(SalesDashboardModel data) {
    final totals = <String, double>{};
    for (final entry in data.todaysEntries) {
      entry.pumpPayments.forEach((pumpId, payments) {
        totals[pumpId] = (totals[pumpId] ?? 0) + payments.cash;
      });
    }

    return data.station.pumps
        .map(
          (pump) => _PumpCashSummary(
            label: formatPumpLabel(pump.id, pump.label),
            cash: totals[pump.id] ?? 0,
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<_SalesDashboardBundle>(
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
              physics: const AlwaysScrollableScrollPhysics(),
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

          final bundle = snapshot.data!;
          final today = bundle.today;
          final yesterday = bundle.yesterday;
          final cashByPump = _todayCashByPump(today);
          final approvedEntries =
              today.todaysEntries.where((entry) => entry.isFinalized).length;
          final pendingEntries = today.todaysEntries.length - approvedEntries;
          final flaggedEntries =
              today.todaysEntries.where((entry) => entry.flagged).length;

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
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
                      formatDateLabel(today.date),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      today.station.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _HeroStatChip(
                            label: 'Liters',
                            value: formatLiters(
                              today.petrolSold +
                                  today.dieselSold +
                                  today.twoTSold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _HeroStatChip(
                            label: 'Flagged',
                            value: '$flaggedEntries',
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _HeroStatChip(
                            label: 'Pending',
                            value: '$pendingEntries',
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _HeroStatChip(
                            label: 'Approved',
                            value: '$approvedEntries',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _openCreditLedger,
                style: FilledButton.styleFrom(
                  backgroundColor: kClayHeroStart,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.account_balance_wallet_rounded),
                label: const Text(
                  'Credit Ledger',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 10),
              DailyFuelStatusCard(
                title: 'Daily Fuel Status',
                targetDate: today.date,
                record: today.dailyFuelRecord,
                pendingMessage:
                    'Density is separate from today\'s sales entry.',
                primaryActionLabel:
                    today.dailyFuelRecordComplete
                        ? 'Edit Density'
                        : 'Enter Density',
                onPrimaryAction: _openSalesEntryPage,
                onHistory: _openDailyFuelHistory,
              ),
              const SizedBox(height: 16),
              const Text(
                'YESTERDAY\'S SALES',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w800,
                  color: kClaySub,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                formatDateLabel(yesterday.date),
                style: const TextStyle(
                  color: kClaySub,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  const gap = 10.0;
                  final itemWidth = (constraints.maxWidth - gap) / 2;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      SizedBox(
                        width: itemWidth,
                        child: _FuelCard(
                          label: 'Petrol',
                          liters: yesterday.petrolSold,
                          icon: Icons.local_gas_station_rounded,
                          color: const Color(0xFF1A3A7A),
                          bgColor: const Color(0xFFD7E8FB),
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _FuelCard(
                          label: 'Diesel',
                          liters: yesterday.dieselSold,
                          icon: Icons.oil_barrel_rounded,
                          color: const Color(0xFF2AA878),
                          bgColor: const Color(0xFFD4F5E9),
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _FuelCard(
                          label: '2T Oil',
                          liters: yesterday.twoTSold,
                          icon: Icons.opacity_rounded,
                          color: const Color(0xFFCE5828),
                          bgColor: const Color(0xFFFDE8DF),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 22),
              const Text(
                'TODAY\'S CASH BY PUMP',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w800,
                  color: kClaySub,
                ),
              ),
              const SizedBox(height: 8),
              ClayCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatDateLabel(today.date),
                      style: const TextStyle(
                        color: kClayPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Cash collected from each pump for today.',
                      style: TextStyle(
                        color: kClaySub,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...cashByPump.map(
                      (pump) =>
                          _PumpCashRow(label: pump.label, cash: pump.cash),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SalesDashboardBundle {
  const _SalesDashboardBundle({required this.today, required this.yesterday});

  final SalesDashboardModel today;
  final SalesDashboardModel yesterday;
}

class _PumpCashSummary {
  const _PumpCashSummary({required this.label, required this.cash});

  final String label;
  final double cash;
}

class _FuelCard extends StatelessWidget {
  const _FuelCard({
    required this.label,
    required this.liters,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  final String label;
  final double liters;
  final IconData icon;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB8C0DC).withValues(alpha: 0.7),
            offset: const Offset(4, 4),
            blurRadius: 12,
          ),
          const BoxShadow(
            color: Colors.white,
            offset: Offset(-3, -3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          OneLineScaleText(
            formatLiters(liters),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kClaySub,
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: OneLineScaleText(
        '$label  $value',
        alignment: Alignment.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PumpCashRow extends StatelessWidget {
  const _PumpCashRow({required this.label, required this.cash});

  final String label;
  final double cash;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFECEFF8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFD4F5E9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.payments_rounded,
              color: Color(0xFF2AA878),
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: kClayPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          OneLineScaleText(
            formatCurrency(cash),
            alignment: Alignment.centerRight,
            style: const TextStyle(
              color: kClayPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
