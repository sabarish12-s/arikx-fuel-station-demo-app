import 'dart:async';

import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/api_response_cache.dart';
import '../services/sales_service.dart';
import '../utils/formatters.dart';
import '../utils/user_facing_errors.dart';
import '../widgets/app_date_range_picker.dart';
import '../widgets/clay_widgets.dart';
import '../widgets/responsive_text.dart';

const String _notEntered = 'Not entered';

class EntryHistoryScreen extends StatefulWidget {
  const EntryHistoryScreen({super.key});

  @override
  State<EntryHistoryScreen> createState() => _EntryHistoryScreenState();
}

class _EntryHistoryScreenState extends State<EntryHistoryScreen> {
  final SalesService _salesService = SalesService();
  late Future<List<ShiftEntryModel>> _future;
  late final StreamSubscription<ApiResponseCacheUpdate> _cacheSubscription;
  late DateTime _fromDate;
  late DateTime _toDate;
  _EntryHistorySort _sort = _EntryHistorySort.dateNewest;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _toDate = DateTime(today.year, today.month, today.day);
    _fromDate = _toDate.subtract(const Duration(days: 29));
    _future = _loadEntries();
    _cacheSubscription = ApiResponseCache.updates.listen((update) {
      if (!mounted ||
          !update.background ||
          !update.path.startsWith('/sales/entries')) {
        return;
      }
      setState(() {
        _future = _loadEntries();
      });
    });
  }

  @override
  void dispose() {
    _cacheSubscription.cancel();
    super.dispose();
  }

  String _toApiDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<List<ShiftEntryModel>> _loadEntries({bool forceRefresh = false}) {
    return _salesService.fetchEntries(
      fromDate: _toApiDate(_fromDate),
      toDate: _toApiDate(_toDate),
      summary: true,
      forceRefresh: forceRefresh,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadEntries(forceRefresh: true);
    });
    await _future;
  }

  Future<void> _pickDateRange() async {
    final selected = await showAppDateRangePicker(
      context: context,
      fromDate: _fromDate,
      toDate: _toDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      helpText: 'Select entry range',
    );
    if (selected == null) {
      return;
    }

    setState(() {
      _fromDate = selected.start;
      _toDate = selected.end;
      _future = _loadEntries();
    });
  }

  Future<void> _showEntryDetails(ShiftEntryModel entry) async {
    final detailFuture = _salesService.fetchEntryDetail(
      entry.id,
      forceRefresh: true,
    );
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EntryDetailSheet(future: detailFuture),
    );
  }

  double _entryLiters(ShiftEntryModel entry) {
    return entry.totals.sold.petrol +
        entry.totals.sold.diesel +
        entry.totals.sold.twoT;
  }

  double _entryVariance(ShiftEntryModel entry) {
    return entry.paymentTotal - entry.computedRevenue;
  }

  int _compareDateValues(String left, String right) {
    final leftDate = DateTime.tryParse(left);
    final rightDate = DateTime.tryParse(right);
    if (leftDate != null && rightDate != null) {
      return leftDate.compareTo(rightDate);
    }
    return left.compareTo(right);
  }

  List<ShiftEntryModel> _sortedEntries(List<ShiftEntryModel> entries) {
    final sorted = [...entries];
    sorted.sort((left, right) {
      switch (_sort) {
        case _EntryHistorySort.dateNewest:
          return _compareDateValues(right.date, left.date);
        case _EntryHistorySort.dateOldest:
          return _compareDateValues(left.date, right.date);
        case _EntryHistorySort.submittedNewest:
          return _compareDateValues(
            right.latestActivityTimestamp,
            left.latestActivityTimestamp,
          );
        case _EntryHistorySort.submittedOldest:
          return _compareDateValues(
            left.latestActivityTimestamp,
            right.latestActivityTimestamp,
          );
        case _EntryHistorySort.salesHigh:
          return right.revenue.compareTo(left.revenue);
        case _EntryHistorySort.salesLow:
          return left.revenue.compareTo(right.revenue);
        case _EntryHistorySort.litersHigh:
          return _entryLiters(right).compareTo(_entryLiters(left));
        case _EntryHistorySort.litersLow:
          return _entryLiters(left).compareTo(_entryLiters(right));
        case _EntryHistorySort.varianceHigh:
          return _entryVariance(
            right,
          ).abs().compareTo(_entryVariance(left).abs());
        case _EntryHistorySort.varianceLow:
          return _entryVariance(
            left,
          ).abs().compareTo(_entryVariance(right).abs());
      }
    });
    return sorted;
  }

  String _sortLabel(_EntryHistorySort sort) {
    switch (sort) {
      case _EntryHistorySort.dateNewest:
        return 'Entry date - newest';
      case _EntryHistorySort.dateOldest:
        return 'Entry date - oldest';
      case _EntryHistorySort.submittedNewest:
        return 'Submitted - newest';
      case _EntryHistorySort.submittedOldest:
        return 'Submitted - oldest';
      case _EntryHistorySort.salesHigh:
        return 'Sales - high to low';
      case _EntryHistorySort.salesLow:
        return 'Sales - low to high';
      case _EntryHistorySort.litersHigh:
        return 'Liters - high to low';
      case _EntryHistorySort.litersLow:
        return 'Liters - low to high';
      case _EntryHistorySort.varianceHigh:
        return 'Variance - high to low';
      case _EntryHistorySort.varianceLow:
        return 'Variance - low to high';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kClayBg,
      body: SafeArea(child: _buildEntriesView()),
    );
  }

  Widget _buildEntriesView() {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<ShiftEntryModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done &&
              !snapshot.hasData) {
            return const ColoredBox(
              color: kClayBg,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError && !snapshot.hasData) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Center(
                  child: Text(
                    userFacingErrorMessage(snapshot.error),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: kClayPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          }

          final entries = _sortedEntries(snapshot.data ?? []);
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _buildHeroCard(),
              const SizedBox(height: 12),
              if (entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(
                    child: Text(
                      'No entries for the selected filters.',
                      style: TextStyle(
                        color: kClaySub,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
              else
                ...entries.map(_buildEntryCard),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
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
          const Text(
            'ENTRY HISTORY',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w800,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Review Submitted Entries',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Use the filter and sorting controls below to narrow entries.',
            style: TextStyle(
              color: Colors.white70,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Filter',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _pickDateRange,
              icon: const Icon(Icons.event_available_rounded, size: 18),
              label: Text(
                '${formatDateLabel(_toApiDate(_fromDate))} to '
                '${formatDateLabel(_toApiDate(_toDate))}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: _historyFilterButtonStyle(),
            ),
          ),
          const SizedBox(height: 12),
          ClayDropdownField<_EntryHistorySort>(
            label: 'Sorting',
            value: _sort,
            compact: true,
            items: _EntryHistorySort.values
                .map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text(_sortLabel(item)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() => _sort = value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(ShiftEntryModel entry) {
    final variance = entry.paymentTotal - entry.computedRevenue;
    final liters =
        entry.totals.sold.petrol +
        entry.totals.sold.diesel +
        entry.totals.sold.twoT;
    final weekday = formatWeekdayLabel(entry.date);
    final attendants = entry.pumpAttendants.entries
        .where((item) => item.value.trim().isNotEmpty)
        .map((item) => '${formatPumpLabel(item.key)}: ${item.value.trim()}')
        .join(', ');
    return ClayCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      weekday.isEmpty
                          ? formatDateLabel(entry.date)
                          : '${formatDateLabel(entry.date)} ($weekday)',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: kClayPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatShiftLabel(entry.shift).toUpperCase(),
                      style: const TextStyle(
                        color: kClaySub,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _EntryStatusBadge(status: entry.status, flagged: entry.flagged),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _HistoryMetric(
                  label: 'Sales',
                  value: formatCurrency(entry.revenue),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HistoryMetric(
                  label: 'Liters',
                  value: formatLiters(liters),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HistoryMetric(
                  label: 'Variance',
                  value: formatCurrency(variance),
                ),
              ),
            ],
          ),
          if (attendants.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              attendants,
              style: const TextStyle(
                color: kClaySub,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (entry.varianceNote.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                entry.varianceNote,
                style: const TextStyle(
                  color: Color(0xFFB91C1C),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              height: 38,
              child: OutlinedButton.icon(
                onPressed: () => _showEntryDetails(entry),
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('View'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kClayPrimary,
                  side: BorderSide(color: kClayPrimary.withValues(alpha: 0.15)),
                  backgroundColor: const Color(0xFFF7F8FD),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _EntryHistorySort {
  dateNewest,
  dateOldest,
  submittedNewest,
  submittedOldest,
  salesHigh,
  salesLow,
  litersHigh,
  litersLow,
  varianceHigh,
  varianceLow,
}

ButtonStyle _historyFilterButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: Colors.white,
    side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
    backgroundColor: Colors.white.withValues(alpha: 0.08),
    padding: const EdgeInsets.symmetric(horizontal: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
  );
}

class _HistoryMetric extends StatelessWidget {
  const _HistoryMetric({required this.label, required this.value});

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
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _EntryStatusBadge extends StatelessWidget {
  const _EntryStatusBadge({required this.status, required this.flagged});

  final String status;
  final bool flagged;

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
      fg = kClayPrimary;
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
        style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 11),
      ),
    );
  }
}

class _EntryDetailSheet extends StatelessWidget {
  const _EntryDetailSheet({required this.future});

  final Future<ShiftEntryModel> future;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Container(
        decoration: const BoxDecoration(
          color: kClayBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: kClaySub.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Entry Details',
                        style: TextStyle(
                          color: kClayPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: kClayPrimary,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<ShiftEntryModel>(
                  future: future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              userFacingErrorMessage(snapshot.error),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: kClayPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 42,
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Close'),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final entry = snapshot.data!;
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      children: [
                        _DetailSection(
                          title: 'Header',
                          child: Column(
                            children: [
                              _EntryHeaderHero(entry: entry),
                              const SizedBox(height: 12),
                              _HeaderInfoGrid(
                                items: [
                                  _HeaderInfoItem(
                                    label: 'Submitted by',
                                    value: _displayOrPlaceholder(
                                      entry.submittedByName,
                                    ),
                                  ),
                                  _HeaderInfoItem(
                                    label: 'Submitted at',
                                    value: _formatDateTimeOrPlaceholder(
                                      entry.submittedAt,
                                    ),
                                  ),
                                  _HeaderInfoItem(
                                    label: 'Updated at',
                                    value: _formatDateTimeOrPlaceholder(
                                      entry.updatedAt,
                                    ),
                                  ),
                                  _HeaderInfoItem(
                                    label: 'Approved at',
                                    value: _formatDateTimeOrPlaceholder(
                                      entry.approvedAt,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _DetailSection(
                          title: 'Stock',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FuelBreakdownTile(
                                title: 'Opening total',
                                totals: entry.totals.opening,
                              ),
                              const SizedBox(height: 10),
                              _FuelBreakdownTile(
                                title: 'Closing total',
                                totals: entry.totals.closing,
                              ),
                              const SizedBox(height: 10),
                              _FuelBreakdownTile(
                                title: 'Sold total',
                                totals: entry.totals.sold,
                              ),
                              const SizedBox(height: 14),
                              const _SubSectionLabel('Readings'),
                              const SizedBox(height: 8),
                              ..._buildPumpReadingCards(entry),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _DetailSection(
                          title: 'Pump Details',
                          child: Column(children: _buildPumpDetailCards(entry)),
                        ),
                        const SizedBox(height: 12),
                        _DetailSection(
                          title: 'Settlement',
                          child: Column(
                            children: [
                              _MoneyBreakdownTile(
                                title: 'Payments',
                                values: {
                                  'Cash': entry.paymentBreakdown.cash,
                                  'HP Pay': entry.paymentBreakdown.check,
                                  'UPI': entry.paymentBreakdown.upi,
                                  'Credit': entry.creditEntries.fold<double>(
                                    0,
                                    (sum, credit) => sum + credit.amount,
                                  ),
                                },
                              ),
                              const SizedBox(height: 10),
                              _DetailRow(
                                label: 'Computed revenue',
                                value: formatCurrency(entry.computedRevenue),
                              ),
                              _DetailRow(
                                label: 'Sales settlement',
                                value: formatCurrency(
                                  entry.salesSettlementTotal,
                                ),
                              ),
                              _DetailRow(
                                label: 'Mismatch amount',
                                value: formatCurrency(entry.mismatchAmount),
                              ),
                              if (entry.flagged)
                                _DetailRow(
                                  label: 'Mismatch reason',
                                  value: _displayOrPlaceholder(
                                    entry.mismatchReason,
                                  ),
                                ),
                              _DetailRow(
                                label: 'Profit',
                                value: formatCurrency(entry.profit),
                                isLast: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _DetailSection(
                          title: 'Credit',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SubSectionLabel('Issued'),
                              const SizedBox(height: 8),
                              ..._buildCreditEntryCards(entry.creditEntries),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _DetailSection(
                          title: 'Notes',
                          child: Column(
                            children: [
                              _DetailRow(
                                label: 'Variance note',
                                value: _displayOrPlaceholder(
                                  entry.varianceNote,
                                ),
                                isLast: !entry.flagged,
                              ),
                              if (entry.flagged)
                                _DetailRow(
                                  label: 'Mismatch reason',
                                  value: _displayOrPlaceholder(
                                    entry.mismatchReason,
                                  ),
                                  isLast: true,
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPumpReadingCards(ShiftEntryModel entry) {
    final pumpIds = _pumpIds(entry);
    if (pumpIds.isEmpty) {
      return const [_EmptySubCard(message: _notEntered)];
    }
    return [
      for (int index = 0; index < pumpIds.length; index++) ...[
        _SubCard(
          title: formatPumpLabel(pumpIds[index]),
          child: Column(
            children: [
              _FuelBreakdownTile(
                title: 'Opening',
                totals: entry.openingReadings[pumpIds[index]],
              ),
              const SizedBox(height: 10),
              _FuelBreakdownTile(
                title: 'Closing',
                totals: entry.closingReadings[pumpIds[index]],
              ),
              const SizedBox(height: 10),
              _FuelBreakdownTile(
                title: 'Sold',
                totals: entry.soldByPump[pumpIds[index]],
              ),
            ],
          ),
        ),
        if (index != pumpIds.length - 1) const SizedBox(height: 10),
      ],
    ];
  }

  List<Widget> _buildPumpDetailCards(ShiftEntryModel entry) {
    final pumpIds = _pumpIds(entry);
    if (pumpIds.isEmpty) {
      return const [_EmptySubCard(message: _notEntered)];
    }
    return [
      for (int index = 0; index < pumpIds.length; index++) ...[
        _SubCard(
          title: formatPumpLabel(pumpIds[index]),
          child: Column(
            children: [
              _DetailRow(
                label: 'Attendant',
                value: _displayOrPlaceholder(
                  entry.pumpAttendants[pumpIds[index]] ?? '',
                ),
              ),
              _DetailRow(
                label: 'Testing',
                value: _formatTesting(entry.pumpTesting[pumpIds[index]]),
              ),
              if (entry.pumpPayments.containsKey(pumpIds[index])) ...[
                _MoneyBreakdownTile(
                  title: 'Pump payments',
                  values: {
                    'Cash': entry.pumpPayments[pumpIds[index]]!.cash,
                    'HP Pay': entry.pumpPayments[pumpIds[index]]!.check,
                    'UPI': entry.pumpPayments[pumpIds[index]]!.upi,
                    'Credit': entry.pumpPayments[pumpIds[index]]!.credit,
                    'Total': entry.pumpPayments[pumpIds[index]]!.total,
                  },
                ),
                const SizedBox(height: 10),
              ] else ...[
                const _DetailRow(label: 'Pump payments', value: _notEntered),
              ],
              _DetailRow(
                label: 'Pump collection',
                value: entry.pumpCollections.containsKey(pumpIds[index])
                    ? formatCurrency(entry.pumpCollections[pumpIds[index]] ?? 0)
                    : _notEntered,
                isLast: true,
              ),
            ],
          ),
        ),
        if (index != pumpIds.length - 1) const SizedBox(height: 10),
      ],
    ];
  }

  List<Widget> _buildCreditEntryCards(List<CreditEntryModel> entries) {
    if (entries.isEmpty) {
      return const [_EmptySubCard(message: _notEntered)];
    }
    return [
      for (int index = 0; index < entries.length; index++) ...[
        _SubCard(
          title: entries[index].name.trim().isEmpty
              ? 'Credit entry ${index + 1}'
              : entries[index].name.trim(),
          child: Column(
            children: [
              _DetailRow(
                label: 'Pump',
                value: entries[index].pumpId.trim().isEmpty
                    ? _notEntered
                    : formatPumpLabel(entries[index].pumpId),
              ),
              _DetailRow(
                label: 'Amount',
                value: formatCurrency(entries[index].amount),
                isLast: true,
              ),
            ],
          ),
        ),
        if (index != entries.length - 1) const SizedBox(height: 10),
      ],
    ];
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: kClayPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _EntryHeaderHero extends StatelessWidget {
  const _EntryHeaderHero({required this.entry});

  final ShiftEntryModel entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FD),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E9F7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: OneLineScaleText(
                  formatDateLabel(entry.date),
                  style: const TextStyle(
                    color: kClayPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _HeaderBadge(
                label: _statusLabel(entry),
                accent: _statusAccent(entry),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderInfoItem {
  const _HeaderInfoItem({required this.label, required this.value});

  final String label;
  final String value;
}

class _HeaderInfoGrid extends StatelessWidget {
  const _HeaderInfoGrid({required this.items});

  final List<_HeaderInfoItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in items)
              SizedBox(
                width: itemWidth,
                child: _HeaderInfoCard(label: item.label, value: item.value),
              ),
          ],
        );
      },
    );
  }
}

class _HeaderInfoCard extends StatelessWidget {
  const _HeaderInfoCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E9F7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: kClaySub,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: kClayPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge({required this.label, this.accent = kClayPrimary});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SubSectionLabel extends StatelessWidget {
  const _SubSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: kClaySub,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(
                color: kClaySub,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: kClayPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FuelBreakdownTile extends StatelessWidget {
  const _FuelBreakdownTile({required this.title, required this.totals});

  final String title;
  final Object? totals;

  @override
  Widget build(BuildContext context) {
    if (totals == null) {
      return _DataBlock(
        title: title,
        child: const Text(
          _notEntered,
          style: TextStyle(
            color: kClaySub,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return _DataBlock(
      title: title,
      child: Column(
        children: [
          _MiniValueRow(
            label: 'Petrol',
            value: formatLiters(_fuelPetrol(totals)),
          ),
          const SizedBox(height: 8),
          _MiniValueRow(
            label: 'Diesel',
            value: formatLiters(_fuelDiesel(totals)),
          ),
          const SizedBox(height: 8),
          _MiniValueRow(
            label: '2T Oil',
            value: formatLiters(_fuelTwoT(totals)),
          ),
        ],
      ),
    );
  }
}

class _MoneyBreakdownTile extends StatelessWidget {
  const _MoneyBreakdownTile({required this.title, required this.values});

  final String title;
  final Map<String, double> values;

  @override
  Widget build(BuildContext context) {
    return _DataBlock(
      title: title,
      child: Column(
        children: [
          for (int index = 0; index < values.entries.length; index++) ...[
            _MiniValueRow(
              label: values.entries.elementAt(index).key,
              value: formatCurrency(values.entries.elementAt(index).value),
            ),
            if (index != values.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _DataBlock extends StatelessWidget {
  const _DataBlock({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E9F7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: kClayPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _MiniValueRow extends StatelessWidget {
  const _MiniValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: const TextStyle(
              color: kClaySub,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 6,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: kClayPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SubCard extends StatelessWidget {
  const _SubCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FD),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E9F7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: kClayPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _EmptySubCard extends StatelessWidget {
  const _EmptySubCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _SubCard(
      title: 'Details',
      child: Text(
        message,
        style: const TextStyle(
          color: kClaySub,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _statusLabel(ShiftEntryModel entry) {
  if (entry.flagged) {
    return 'Flagged';
  }
  if (entry.status.trim().isEmpty) {
    return _notEntered;
  }
  return formatShiftCase(entry.status);
}

Color _statusAccent(ShiftEntryModel entry) {
  if (entry.flagged) {
    return const Color(0xFFB91C1C);
  }
  if (entry.status.trim().toLowerCase() == 'approved') {
    return const Color(0xFF2AA878);
  }
  return kClayPrimary;
}

String _displayOrPlaceholder(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? _notEntered : trimmed;
}

String _formatDateTimeOrPlaceholder(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? _notEntered : formatDateTimeLabel(trimmed);
}

String _formatTesting(PumpTestingModel? testing) {
  if (testing == null || !testing.enabled) {
    return _notEntered;
  }
  return 'Petrol ${formatLiters(testing.petrol)}   Diesel ${formatLiters(testing.diesel)}';
}

double _fuelPetrol(Object? totals) {
  if (totals is FuelTotals) {
    return totals.petrol;
  }
  if (totals is PumpReadings) {
    return totals.petrol;
  }
  return 0;
}

double _fuelDiesel(Object? totals) {
  if (totals is FuelTotals) {
    return totals.diesel;
  }
  if (totals is PumpReadings) {
    return totals.diesel;
  }
  return 0;
}

double _fuelTwoT(Object? totals) {
  if (totals is FuelTotals) {
    return totals.twoT;
  }
  if (totals is PumpReadings) {
    return totals.twoT;
  }
  return 0;
}

List<String> _pumpIds(ShiftEntryModel entry) {
  final ids = <String>{
    ...entry.openingReadings.keys,
    ...entry.closingReadings.keys,
    ...entry.soldByPump.keys,
    ...entry.pumpAttendants.keys,
    ...entry.pumpTesting.keys,
    ...entry.pumpPayments.keys,
    ...entry.pumpCollections.keys,
  }.toList()..sort();
  return ids;
}

String formatShiftCase(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return _notEntered;
  }
  return trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
}
