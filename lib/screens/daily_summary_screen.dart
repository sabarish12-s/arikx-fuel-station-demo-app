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
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Summary')),
      body: FutureBuilder<DailySummaryModel>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatDateLabel(data.date),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('Revenue ${formatCurrency(data.revenue)}'),
                    Text('Profit ${formatCurrency(data.profit)}'),
                    Text('Petrol sold ${formatLiters(data.petrolSold)}'),
                    Text('Diesel sold ${formatLiters(data.dieselSold)}'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Shift Distribution',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              ...data.distribution.map(
                (item) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          formatShiftLabel(item.shift),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(formatCurrency(item.revenue)),
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
