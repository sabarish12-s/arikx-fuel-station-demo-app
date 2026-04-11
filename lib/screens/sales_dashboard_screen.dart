import 'dart:async';

import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/api_response_cache.dart';
import '../services/sales_service.dart';
import '../utils/formatters.dart';
import '../utils/user_facing_errors.dart';
import '../widgets/clay_widgets.dart';
import '../widgets/responsive_text.dart';

class SalesDashboardScreen extends StatefulWidget {
  const SalesDashboardScreen({super.key});

  @override
  State<SalesDashboardScreen> createState() => _SalesDashboardScreenState();
}

class _SalesDashboardScreenState extends State<SalesDashboardScreen> {
  final SalesService _salesService = SalesService();
  late Future<SalesDashboardModel> _future;
  late final StreamSubscription<ApiResponseCacheUpdate> _cacheSubscription;

  String _errorText(Object? error) {
    return userFacingErrorMessage(error);
  }

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

  Future<SalesDashboardModel> _load({bool forceRefresh = false}) {
    return _salesService.fetchDashboard(forceRefresh: forceRefresh);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load(forceRefresh: true);
    });
    await _future;
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

          final data = snapshot.data!;
          final approvedEntries =
              data.todaysEntries
                  .where((entry) => entry.status == 'approved')
                  .length;
          final pendingEntries = data.todaysEntries.length - approvedEntries;
          final flaggedEntries =
              data.todaysEntries.where((entry) => entry.flagged).length;

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              // ── Hero header ────────────────────────────────────────────
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
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _HeroStatChip(
                            label: 'Liters',
                            value: formatLiters(
                              data.petrolSold + data.dieselSold + data.twoTSold,
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

              // ── Fuel sales cards ───────────────────────────────────────
              const Text(
                'FUEL DISPENSED',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w800,
                  color: kClaySub,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _FuelCard(
                      label: 'Petrol',
                      liters: data.petrolSold,
                      icon: Icons.local_gas_station_rounded,
                      color: const Color(0xFF1A3A7A),
                      bgColor: const Color(0xFFD7E8FB),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FuelCard(
                      label: 'Diesel',
                      liters: data.dieselSold,
                      icon: Icons.oil_barrel_rounded,
                      color: const Color(0xFF2AA878),
                      bgColor: const Color(0xFFD4F5E9),
                    ),
                  ),
                  if (data.twoTSold > 0) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: _FuelCard(
                        label: '2T Oil',
                        liters: data.twoTSold,
                        icon: Icons.opacity_rounded,
                        color: const Color(0xFFCE5828),
                        bgColor: const Color(0xFFFDE8DF),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 22),

              // ── Recently submitted ─────────────────────────────────────
              const Text(
                'RECENTLY SUBMITTED',
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
                    'No entries submitted yet.',
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
                            color:
                                entry.flagged
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
                            color:
                                entry.flagged
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
                                '${formatLiters(entry.totals.sold.petrol)} petrol  •  ${formatLiters(entry.totals.sold.diesel)} diesel'
                                '${entry.totals.sold.twoT > 0 ? '  •  ${formatLiters(entry.totals.sold.twoT)} 2T' : ''}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: kClayPrimary,
                                  fontSize: 13,
                                ),
                              ),
                              if (entry.flagged &&
                                  entry.varianceNote.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  entry.varianceNote,
                                  style: const TextStyle(
                                    color: Color(0xFFCE5828),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
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

// ── Fuel dispensed card ────────────────────────────────────────────────────────
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

// ── Hero stat chip ─────────────────────────────────────────────────────────────
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

// ── Entry badge ────────────────────────────────────────────────────────────────
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
      child: OneLineScaleText(
        label,
        alignment: Alignment.center,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}
