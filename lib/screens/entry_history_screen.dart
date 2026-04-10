import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/sales_service.dart';
import '../utils/formatters.dart';
import '../widgets/clay_widgets.dart';

class EntryHistoryScreen extends StatefulWidget {
  const EntryHistoryScreen({super.key});

  @override
  State<EntryHistoryScreen> createState() => _EntryHistoryScreenState();
}

class _EntryHistoryScreenState extends State<EntryHistoryScreen> {
  final SalesService _salesService = SalesService();
  final TextEditingController _monthController = TextEditingController(
    text: currentMonthKey(),
  );
  late Future<List<ShiftEntryModel>> _future;
  String _month = currentMonthKey();
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _future = _loadEntries();
  }

  @override
  void dispose() {
    _monthController.dispose();
    super.dispose();
  }

  String _toApiDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<List<ShiftEntryModel>> _loadEntries() {
    return _salesService.fetchEntries(
      month: _month.trim(),
      fromDate: _fromDate == null ? null : _toApiDate(_fromDate!),
      toDate: _toDate == null ? null : _toApiDate(_toDate!),
      summary: true,
    );
  }

  void _reload() {
    FocusScope.of(context).unfocus();
    setState(() {
      _month = _monthController.text.trim();
      _future = _loadEntries();
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initialDate =
        isFrom
            ? (_fromDate ?? _toDate ?? DateTime.now())
            : (_toDate ?? _fromDate ?? DateTime.now());
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      helpText: isFrom ? 'Select from date' : 'Select to date',
    );
    if (selected == null) {
      return;
    }

    setState(() {
      if (isFrom) {
        _fromDate = selected;
      } else {
        _toDate = selected;
      }
      _future = _loadEntries();
    });
  }

  void _clearDateRange() {
    setState(() {
      _fromDate = null;
      _toDate = null;
      _future = _loadEntries();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kClayBg,
      appBar: AppBar(
        backgroundColor: kClayBg,
        iconTheme: const IconThemeData(color: kClayPrimary),
        title: const Text('Entry History'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Container(
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
                    'Use the filters here to narrow entries by month and date range.',
                    style: TextStyle(
                      color: Colors.white70,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _monthController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Month (YYYY-MM)',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Colors.white70),
                      ),
                      suffixIcon: IconButton(
                        onPressed: _reload,
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _reload(),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _pickDate(isFrom: true),
                        icon: const Icon(Icons.event_available_rounded),
                        label: Text(
                          _fromDate == null
                              ? 'From date'
                              : 'From: ${formatDateLabel(_toApiDate(_fromDate!))}',
                        ),
                        style: _historyFilterButtonStyle(),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _pickDate(isFrom: false),
                        icon: const Icon(Icons.event_rounded),
                        label: Text(
                          _toDate == null
                              ? 'To date'
                              : 'To: ${formatDateLabel(_toApiDate(_toDate!))}',
                        ),
                        style: _historyFilterButtonStyle(),
                      ),
                      if (_fromDate != null || _toDate != null)
                        TextButton(
                          onPressed: _clearDateRange,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.08,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('Clear dates'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
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
                      snapshot.error.toString().replaceFirst('Exception: ', ''),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: kClayPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }
                final entries = snapshot.data ?? [];
                if (entries.isEmpty) {
                  return const Center(
                    child: Text(
                      'No entries for the selected filters.',
                      style: TextStyle(
                        color: kClaySub,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
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
                              _EntryStatusBadge(
                                status: entry.status,
                                flagged: entry.flagged,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _HistoryMetric(
                                  label: 'Revenue',
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
                          if (entry.pumpAttendants.values.any(
                            (name) => name.isNotEmpty,
                          )) ...[
                            const SizedBox(height: 12),
                            Text(
                              entry.pumpAttendants.entries
                                  .where((item) => item.value.isNotEmpty)
                                  .map(
                                    (item) =>
                                        '${formatPumpLabel(item.key)}: ${item.value}',
                                  )
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
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
                  },
                );
              },
            ),
          ),
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
        Text(
          label,
          style: const TextStyle(
            color: kClaySub,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
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
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 11),
      ),
    );
  }
}
