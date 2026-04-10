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
  late Future<List<ShiftEntryModel>> _future;
  String _month = currentMonthKey();

  @override
  void initState() {
    super.initState();
    _future = _salesService.fetchEntries(month: _month, summary: true);
  }

  void _reload() {
    setState(() {
      _future = _salesService.fetchEntries(month: _month, summary: true);
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
            child: ClayCard(
              child: TextField(
                controller: TextEditingController(text: _month),
                decoration: InputDecoration(
                  labelText: 'Month (YYYY-MM)',
                  filled: true,
                  fillColor: kClayBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded),
                    color: kClayPrimary,
                  ),
                ),
                onChanged: (value) => _month = value,
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
                      'No entries for this month.',
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
