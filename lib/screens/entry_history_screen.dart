import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/sales_service.dart';
import '../utils/formatters.dart';
import '../utils/user_facing_errors.dart';
import '../widgets/app_date_range_picker.dart';
import '../widgets/responsive_text.dart';
import '../widgets/clay_widgets.dart';

class EntryHistoryScreen extends StatefulWidget {
  const EntryHistoryScreen({super.key});

  @override
  State<EntryHistoryScreen> createState() => _EntryHistoryScreenState();
}

class _EntryHistoryScreenState extends State<EntryHistoryScreen> {
  final SalesService _salesService = SalesService();
  late Future<List<ShiftEntryModel>> _future;
  late DateTime _fromDate;
  late DateTime _toDate;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _toDate = DateTime(today.year, today.month, today.day);
    _fromDate = _toDate.subtract(const Duration(days: 29));
    _future = _loadEntries();
  }

  @override
  void dispose() {
    super.dispose();
  }

  String _toApiDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<List<ShiftEntryModel>> _loadEntries() {
    return _salesService.fetchEntries(
      fromDate: _toApiDate(_fromDate),
      toDate: _toApiDate(_toDate),
      summary: true,
    );
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

  void _clearDateRange() {
    final today = DateTime.now();
    setState(() {
      _toDate = DateTime(today.year, today.month, today.day);
      _fromDate = _toDate.subtract(const Duration(days: 29));
      _future = _loadEntries();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kClayBg,
      body: SafeArea(
        child: FutureBuilder<List<ShiftEntryModel>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const ColoredBox(
                color: kClayBg,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  userFacingErrorMessage(snapshot.error),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: kClayPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }

            final entries = snapshot.data ?? [];
            return ListView(
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
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
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
            'Use the date filters here to narrow entries. The default view shows the last 30 days.',
            style: TextStyle(
              color: Colors.white70,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width - 32,
                ),
                child: OutlinedButton.icon(
                  onPressed: _pickDateRange,
                  icon: const Icon(Icons.event_available_rounded),
                  label: Text(
                    '${formatDateLabel(_toApiDate(_fromDate))} to '
                    '${formatDateLabel(_toApiDate(_toDate))}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: _historyFilterButtonStyle(),
                ),
              ),
              TextButton(
                onPressed: _clearDateRange,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Last 30 days'),
              ),
            ],
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
                      formatDateLabel(entry.date),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: kClayPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.shift.toUpperCase(),
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
          if (entry.pumpAttendants.values.any((name) => name.isNotEmpty)) ...[
            const SizedBox(height: 12),
            Text(
              entry.pumpAttendants.entries
                  .where((item) => item.value.isNotEmpty)
                  .map((item) => '${formatPumpLabel(item.key)}: ${item.value}')
                  .join('  •  '),
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
        ],
      ),
    );
  }
}

ButtonStyle _historyFilterButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: Colors.white,
    side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
    backgroundColor: Colors.white.withValues(alpha: 0.08),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
