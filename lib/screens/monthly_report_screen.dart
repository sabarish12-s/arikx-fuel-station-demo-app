import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/management_service.dart';
import '../utils/formatters.dart';

class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  final ManagementService _managementService = ManagementService();
  late Future<MonthlyReportModel> _future;
  String _month = currentMonthKey();

  @override
  void initState() {
    super.initState();
    _future = _managementService.fetchMonthlyReport(month: _month);
  }

  void _reload() {
    setState(() {
      _future = _managementService.fetchMonthlyReport(month: _month);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Monthly Report')),
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
            child: FutureBuilder<MonthlyReportModel>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('${snapshot.error}'));
                }
                final report = snapshot.data!;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Month ${report.month}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 24,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text('Revenue ${formatCurrency(report.revenue)}'),
                          Text('Profit ${formatCurrency(report.profit)}'),
                          Text('Petrol sold ${formatLiters(report.petrolSold)}'),
                          Text('Diesel sold ${formatLiters(report.dieselSold)}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Trend',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    ...report.trend.map(
                      (point) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: Text(formatDateLabel(point.date))),
                            Text(formatCurrency(point.revenue)),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
