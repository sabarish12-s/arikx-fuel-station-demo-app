import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/inventory_service.dart';
import '../utils/formatters.dart';

class SettingsHomeScreen extends StatefulWidget {
  const SettingsHomeScreen({super.key});

  @override
  State<SettingsHomeScreen> createState() => _SettingsHomeScreenState();
}

class _SettingsHomeScreenState extends State<SettingsHomeScreen> {
  final InventoryService _inventoryService = InventoryService();
  late Future<StationConfigModel> _future;

  @override
  void initState() {
    super.initState();
    _future = _inventoryService.fetchStationConfig();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings Home')),
      body: FutureBuilder<StationConfigModel>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          final station = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      station.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                      ),
                    ),
                    Text('${station.city} - ${station.code}'),
                    const SizedBox(height: 14),
                    Text('Shifts: ${station.shifts.map(formatShiftLabel).join(', ')}'),
                    const SizedBox(height: 8),
                    Text('Pumps: ${station.pumps.map((pump) => pump.label).join(', ')}'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...station.baseReadings.entries.map(
                (entry) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Text(
                    '${entry.key}: Petrol ${formatLiters(entry.value.petrol)} - Diesel ${formatLiters(entry.value.diesel)}',
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
