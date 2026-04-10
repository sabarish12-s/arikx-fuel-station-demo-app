import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/sales_service.dart';
import '../utils/formatters.dart';

class DailySummaryScreen extends StatefulWidget {
  const DailySummaryScreen({super.key});

  @override
  State<DailySummaryScreen> createState() => _DailySummaryScreenState();
}

class _DailySummaryScreenState extends State<DailySummaryScreen> {
  final SalesService _salesService = SalesService();
  late Future<DailySummaryModel> _future;

  @override
  void initState() {
    super.initState();
    _future = _salesService.fetchDailySummary();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DailySummaryModel>(
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
        final data = snapshot.data!;
        final entry = data.entries.isEmpty ? null : data.entries.first;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatDateLabel(data.date),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Revenue ${formatCurrency(data.revenue)}'),
                  Text('Collected ${formatCurrency(data.paymentTotal)}'),
                  Text('Profit ${formatCurrency(data.profit)}'),
                  Text('Petrol sold ${formatLiters(data.petrolSold)}'),
                  Text('Diesel sold ${formatLiters(data.dieselSold)}'),
                  Text('2T oil sold ${formatLiters(data.twoTSold)}'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: entry == null
                  ? const Text('No daily entry saved for this date.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payment Breakdown',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Cash ${formatCurrency(entry.paymentBreakdown.cash)}',
                        ),
                        Text(
                          'HP Pay ${formatCurrency(entry.paymentBreakdown.check)}',
                        ),
                        Text(
                          'UPI ${formatCurrency(entry.paymentBreakdown.upi)}',
                        ),
                        Text(
                          'Credit ${formatCurrency(entry.creditEntries.fold<double>(0, (sum, item) => sum + item.amount))}',
                        ),
                        if (entry.varianceNote.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            entry.varianceNote,
                            style: const TextStyle(color: Color(0xFFB91C1C)),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}
