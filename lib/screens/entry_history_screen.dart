import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/sales_service.dart';
import '../utils/formatters.dart';

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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: TextEditingController(text: _month),
              decoration: InputDecoration(
                labelText: 'Month (YYYY-MM)',
                suffixIcon: IconButton(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                ),
              ),
              onChanged: (value) => _month = value,
            ),
          ),
          Expanded(
            child: FutureBuilder<List<ShiftEntryModel>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      snapshot.error.toString().replaceFirst('Exception: ', ''),
                    ),
                  );
                }
                final entries = snapshot.data ?? [];
                if (entries.isEmpty) {
                  return const Center(
                    child: Text('No entries for this month.'),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  formatDateLabel(entry.date),
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              Chip(label: Text(entry.status)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Petrol ${formatLiters(entry.totals.sold.petrol)} - Diesel ${formatLiters(entry.totals.sold.diesel)} - 2T Oil ${formatLiters(entry.totals.sold.twoT)}',
                          ),
                          Text(
                            'Revenue ${formatCurrency(entry.revenue)} - Collected ${formatCurrency(entry.paymentTotal)}',
                          ),
                          if (entry.pumpAttendants.values.any(
                            (name) => name.isNotEmpty,
                          ))
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                entry.pumpAttendants.entries
                                    .where((item) => item.value.isNotEmpty)
                                    .map(
                                      (item) =>
                                          '${formatPumpLabel(item.key)}: ${item.value}',
                                    )
                                    .join('  •  '),
                                style: const TextStyle(
                                  color: Color(0xFF55606E),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          if (entry.varianceNote.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                entry.varianceNote,
                                style: const TextStyle(
                                  color: Color(0xFFB91C1C),
                                  fontSize: 12,
                                ),
                              ),
                            ),
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
