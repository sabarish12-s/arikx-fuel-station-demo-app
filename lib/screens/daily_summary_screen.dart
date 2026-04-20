import 'dart:async';

import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/api_response_cache.dart';
import '../services/sales_service.dart';
import '../utils/formatters.dart';
import '../utils/user_facing_errors.dart';
import '../widgets/clay_widgets.dart';
import '../widgets/responsive_text.dart';

class DailySummaryScreen extends StatefulWidget {
  const DailySummaryScreen({super.key});

  @override
  State<DailySummaryScreen> createState() => _DailySummaryScreenState();
}

class _DailySummaryScreenState extends State<DailySummaryScreen> {
  final SalesService _salesService = SalesService();
  late Future<DailySummaryModel> _future;
  late final StreamSubscription<ApiResponseCacheUpdate> _cacheSubscription;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _cacheSubscription = ApiResponseCache.updates.listen((update) {
      if (!mounted ||
          !update.background ||
          !update.path.startsWith('/sales/summary/daily')) {
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

  Future<DailySummaryModel> _load({bool forceRefresh = false}) {
    return _salesService.fetchDailySummary(forceRefresh: forceRefresh);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load(forceRefresh: true));
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kClayBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: kClayBg,
        iconTheme: const IconThemeData(color: kClayPrimary),
        title: const Text('Daily Summary'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<DailySummaryModel>(
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
                padding: const EdgeInsets.fromLTRB(16, 80, 16, 24),
                children: [
                  Text(
                    userFacingErrorMessage(snapshot.error),
                    style: const TextStyle(
                      color: kClayPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            }

            final data = snapshot.data!;
            final entry = data.entries.isEmpty ? null : data.entries.first;
            final totalLiters =
                data.petrolSold + data.dieselSold + data.twoTSold;

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
                        formatDateLabel(data.date),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        formatCurrency(data.revenue),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${formatLiters(totalLiters)} total liters',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _HeroChip(
                            label: 'Petrol',
                            value: formatLiters(data.petrolSold),
                          ),
                          _HeroChip(
                            label: 'Diesel',
                            value: formatLiters(data.dieselSold),
                          ),
                          _HeroChip(
                            label: '2T',
                            value: formatLiters(data.twoTSold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const _SectionLabel(label: 'FINANCIALS'),
                const SizedBox(height: 10),
                ClayCard(
                  child: Column(
                    children: [
                      _SummaryMetricRow(
                        label: 'Sales',
                        value: formatCurrency(data.revenue),
                      ),
                      const Divider(color: kClayBg, height: 24),
                      _SummaryMetricRow(
                        label: 'Collected',
                        value: formatCurrency(data.paymentTotal),
                      ),
                      const Divider(color: kClayBg, height: 24),
                      _SummaryMetricRow(
                        label: 'Profit',
                        value: formatCurrency(data.profit),
                      ),
                      const Divider(color: kClayBg, height: 24),
                      _SummaryMetricRow(
                        label: 'Flagged Entries',
                        value: '${data.flaggedCount}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const _SectionLabel(label: 'SHIFT BREAKDOWN'),
                const SizedBox(height: 10),
                if (data.distribution.isEmpty)
                  const ClayCard(
                    child: Text(
                      'No shift-level summary is available for this date.',
                      style: TextStyle(
                        color: kClaySub,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  ...data.distribution.map(
                    (item) => ClayCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.shift.toUpperCase(),
                                  style: const TextStyle(
                                    color: kClayPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              _DailyStatusBadge(status: item.status),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _MetricColumn(
                                  label: 'Sales',
                                  value: formatCurrency(item.revenue),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _MetricColumn(
                                  label: 'Petrol',
                                  value: formatLiters(item.petrolSold),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _MetricColumn(
                                  label: 'Diesel',
                                  value: formatLiters(item.dieselSold),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                const _SectionLabel(label: 'PAYMENTS'),
                const SizedBox(height: 10),
                ClayCard(
                  child: entry == null
                      ? const Text(
                          'No daily entry saved for this date.',
                          style: TextStyle(
                            color: kClaySub,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SummaryMetricRow(
                              label: 'Cash',
                              value: formatCurrency(
                                entry.paymentBreakdown.cash,
                              ),
                            ),
                            const Divider(color: kClayBg, height: 24),
                            _SummaryMetricRow(
                              label: 'HP Pay',
                              value: formatCurrency(
                                entry.paymentBreakdown.check,
                              ),
                            ),
                            const Divider(color: kClayBg, height: 24),
                            _SummaryMetricRow(
                              label: 'UPI',
                              value: formatCurrency(entry.paymentBreakdown.upi),
                            ),
                            const Divider(color: kClayBg, height: 24),
                            _SummaryMetricRow(
                              label: 'Credit',
                              value: formatCurrency(
                                entry.creditEntries.fold<double>(
                                  0,
                                  (sum, item) => sum + item.amount,
                                ),
                              ),
                            ),
                            if (entry.varianceNote.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  entry.varianceNote,
                                  style: const TextStyle(
                                    color: Color(0xFFB91C1C),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: kClaySub,
        letterSpacing: 1.1,
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label, required this.value});

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
      child: OneLineScaleText(
        '$label  $value',
        alignment: Alignment.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _SummaryMetricRow extends StatelessWidget {
  const _SummaryMetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OneLineScaleText(
            label,
            style: const TextStyle(
              color: kClaySub,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        OneLineScaleText(
          value,
          style: const TextStyle(
            color: kClayPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _MetricColumn extends StatelessWidget {
  const _MetricColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OneLineScaleText(
          label,
          style: const TextStyle(
            color: kClaySub,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        OneLineScaleText(
          value,
          style: const TextStyle(
            color: kClayPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _DailyStatusBadge extends StatelessWidget {
  const _DailyStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toLowerCase();
    final isApproved = normalized == 'approved';
    final bg = isApproved ? const Color(0xFFE8F8EF) : const Color(0xFFEEF2FF);
    final fg = isApproved ? const Color(0xFF2AA878) : const Color(0xFF1A3A7A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: OneLineScaleText(
        status.isEmpty ? 'Unknown' : status,
        alignment: Alignment.center,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}
