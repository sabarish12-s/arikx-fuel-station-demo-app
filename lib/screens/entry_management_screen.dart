import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/management_service.dart';
import '../utils/formatters.dart';

class EntryManagementScreen extends StatefulWidget {
  const EntryManagementScreen({super.key});

  @override
  State<EntryManagementScreen> createState() => _EntryManagementScreenState();
}

class _EntryManagementScreenState extends State<EntryManagementScreen> {
  final ManagementService _managementService = ManagementService();
  late Future<List<ShiftEntryModel>> _future;
  String _month = currentMonthKey();

  @override
  void initState() {
    super.initState();
    _future = _managementService.fetchEntries(month: _month);
  }

  Future<void> _reload() async {
    setState(() {
      _future = _managementService.fetchEntries(month: _month);
    });
  }

  Future<void> _editEntry(ShiftEntryModel entry) async {
    final controllers = <String, TextEditingController>{};
    for (final item in entry.closingReadings.entries) {
      controllers['${item.key}_petrol'] = TextEditingController(
        text: item.value.petrol.toStringAsFixed(2),
      );
      controllers['${item.key}_diesel'] = TextEditingController(
        text: item.value.diesel.toStringAsFixed(2),
      );
    }

    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Edit ${formatDateLabel(entry.date)} ${formatShiftLabel(entry.shift)}',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: entry.closingReadings.keys
                .expand(
                  (pumpId) => [
                    TextField(
                      controller: controllers['${pumpId}_petrol'],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(labelText: '$pumpId petrol'),
                    ),
                    TextField(
                      controller: controllers['${pumpId}_diesel'],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(labelText: '$pumpId diesel'),
                    ),
                    const SizedBox(height: 8),
                  ],
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (shouldSave != true) {
      return;
    }

    final readings = <String, PumpReadings>{};
    for (final pumpId in entry.closingReadings.keys) {
      readings[pumpId] = PumpReadings(
        petrol:
            double.tryParse(controllers['${pumpId}_petrol']?.text ?? '') ?? 0,
        diesel:
            double.tryParse(controllers['${pumpId}_diesel']?.text ?? '') ?? 0,
      );
    }
    await _managementService.updateEntry(
      entryId: entry.id,
      closingReadings: readings,
    );
    await _reload();
  }

  Future<void> _approveEntry(ShiftEntryModel entry) async {
    await _managementService.approveEntry(entry.id);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Entry Management')),
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
            child: RefreshIndicator(
              onRefresh: _reload,
              child: FutureBuilder<List<ShiftEntryModel>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return ListView(
                      children: [Center(child: Text('${snapshot.error}'))],
                    );
                  }
                  final entries = snapshot.data ?? [];
                  if (entries.isEmpty) {
                    return ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('No entries yet.')),
                      ],
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${formatDateLabel(entry.date)} - ${formatShiftLabel(entry.shift)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                                Chip(label: Text(entry.status)),
                              ],
                            ),
                            Text(
                              'Petrol ${formatLiters(entry.totals.sold.petrol)} - Diesel ${formatLiters(entry.totals.sold.diesel)}',
                            ),
                            Text(
                              'Revenue ${formatCurrency(entry.revenue)} - Profit ${formatCurrency(entry.profit)}',
                            ),
                            if (entry.varianceNote.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  entry.varianceNote,
                                  style: const TextStyle(
                                    color: Color(0xFFB91C1C),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                OutlinedButton(
                                  onPressed: () => _editEntry(entry),
                                  child: const Text('Edit Entry'),
                                ),
                                const SizedBox(width: 10),
                                if (entry.status != 'approved')
                                  FilledButton(
                                    onPressed: () => _approveEntry(entry),
                                    child: const Text('Approve'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
