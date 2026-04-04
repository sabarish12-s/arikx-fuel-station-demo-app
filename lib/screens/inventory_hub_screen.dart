import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/inventory_service.dart';
import '../services/management_service.dart';
import '../utils/formatters.dart';

class InventoryHubScreen extends StatefulWidget {
  const InventoryHubScreen({super.key});

  @override
  State<InventoryHubScreen> createState() => _InventoryHubScreenState();
}

class _InventoryHubScreenState extends State<InventoryHubScreen> {
  final InventoryService _inventoryService = InventoryService();
  final ManagementService _managementService = ManagementService();
  late Future<_InventoryDashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_InventoryDashboardData> _load() async {
    final results = await Future.wait([
      _inventoryService.fetchStationConfig(),
      _inventoryService.fetchPrices(),
      _managementService.fetchEntries(month: currentMonthKey()),
    ]);

    final station = results[0] as StationConfigModel;
    final prices = results[1] as List<FuelPriceModel>;
    final entries = results[2] as List<ShiftEntryModel>;
    final today = DateTime.now().toIso8601String().split('T').first;
    final todaysEntries = entries.where((entry) => entry.date == today).toList();
    final latestEntry = entries.isEmpty ? null : entries.last;

    final currentPetrol = latestEntry?.totals.closing.petrol ?? 0;
    final currentDiesel = latestEntry?.totals.closing.diesel ?? 0;
    final currentTwoT = latestEntry?.totals.closing.twoT ?? 0;

    final pumpSales = <String, PumpReadings>{};
    for (final pump in station.pumps) {
      double petrol = 0;
      double diesel = 0;
      double twoT = 0;
      for (final entry in todaysEntries) {
        petrol += entry.soldByPump[pump.id]?.petrol ?? 0;
        diesel += entry.soldByPump[pump.id]?.diesel ?? 0;
        twoT += entry.soldByPump[pump.id]?.twoT ?? 0;
      }
      pumpSales[pump.id] = PumpReadings(petrol: petrol, diesel: diesel, twoT: twoT);
    }

    final priceMap = {for (final price in prices) price.fuelTypeId: price};

    return _InventoryDashboardData(
      station: station,
      latestEntry: latestEntry,
      prices: priceMap,
      currentPetrol: currentPetrol,
      currentDiesel: currentDiesel,
      currentTwoT: currentTwoT,
      pumpSales: pumpSales,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<_InventoryDashboardData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [Text('Failed to load inventory\n${snapshot.error}')],
            );
          }

          final data = snapshot.data!;
          final petrolPrice = data.prices['petrol'];
          final dieselPrice = data.prices['diesel'];
          final twoTPrice = data.prices['two_t_oil'];

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 120),
            children: [
              Text(
                data.station.name,
                style: const TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF55606E),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _InventoryStatCard(
                    title: 'Current Petrol',
                    value: formatLiters(data.currentPetrol),
                    accent: const Color(0xFF1E5CBA),
                  ),
                  _InventoryStatCard(
                    title: 'Current Diesel',
                    value: formatLiters(data.currentDiesel),
                    accent: const Color(0xFF006C5C),
                  ),
                  _InventoryStatCard(
                    title: 'Current 2T Oil',
                    value: formatLiters(data.currentTwoT),
                    accent: const Color(0xFFB45309),
                  ),
                  _InventoryStatCard(
                    title: 'Petrol Sell Price',
                    value: formatCurrency(petrolPrice?.sellingPrice ?? 0),
                    accent: const Color(0xFF695781),
                  ),
                  _InventoryStatCard(
                    title: 'Diesel Sell Price',
                    value: formatCurrency(dieselPrice?.sellingPrice ?? 0),
                    accent: const Color(0xFFB45309),
                  ),
                  _InventoryStatCard(
                    title: '2T Oil Sell Price',
                    value: formatCurrency(twoTPrice?.sellingPrice ?? 0),
                    accent: const Color(0xFFA16207),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Station Snapshot',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data.latestEntry == null
                          ? 'No completed shift entry yet for station-level stock.'
                          : 'Latest stock update: ${formatDateLabel(data.latestEntry!.date)}',
                      style: const TextStyle(color: Color(0xFF55606E)),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Pumps configured: ${data.station.pumps.length}',
                      style: const TextStyle(color: Color(0xFF55606E)),
                    ),
                    Text(
                      'Cycle configured: 1 daily entry',
                      style: const TextStyle(color: Color(0xFF55606E)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pump Sales Today',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Pump cards now track current sales only. No pump stock is shown anywhere.',
                      style: TextStyle(color: Color(0xFF55606E)),
                    ),
                    const SizedBox(height: 14),
                    ...data.station.pumps.map(
                      (pump) {
                        final sales = data.pumpSales[pump.id] ??
                            const PumpReadings(petrol: 0, diesel: 0, twoT: 0);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pump.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  color: Color(0xFF293340),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _PumpMetric(
                                      label: 'Petrol sold',
                                      value: formatLiters(sales.petrol),
                                      color: const Color(0xFF1E5CBA),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                              Expanded(
                                child: _PumpMetric(
                                  label: 'Diesel sold',
                                  value: formatLiters(sales.diesel),
                                  color: const Color(0xFF006C5C),
                                ),
                              ),
                              if (pump.id == 'pump2') ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _PumpMetric(
                                    label: '2T oil sold',
                                    value: formatLiters(sales.twoT),
                                    color: const Color(0xFFB45309),
                                  ),
                                ),
                              ],
                            ],
                          ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InventoryDashboardData {
  const _InventoryDashboardData({
    required this.station,
    required this.latestEntry,
    required this.prices,
    required this.currentPetrol,
    required this.currentDiesel,
    required this.currentTwoT,
    required this.pumpSales,
  });

  final StationConfigModel station;
  final ShiftEntryModel? latestEntry;
  final Map<String, FuelPriceModel> prices;
  final double currentPetrol;
  final double currentDiesel;
  final double currentTwoT;
  final Map<String, PumpReadings> pumpSales;
}

class _InventoryStatCard extends StatelessWidget {
  const _InventoryStatCard({
    required this.title,
    required this.value,
    required this.accent,
  });

  final String title;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border(bottom: BorderSide(color: accent, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF55606E))),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
        ],
      ),
    );
  }
}

class _PumpMetric extends StatelessWidget {
  const _PumpMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF55606E),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}
