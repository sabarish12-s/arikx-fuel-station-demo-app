import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/inventory_service.dart';
import '../services/management_service.dart';
import '../utils/formatters.dart';

class StationSettingsScreen extends StatefulWidget {
  const StationSettingsScreen({
    super.key,
    required this.canEdit,
  });

  final bool canEdit;

  @override
  State<StationSettingsScreen> createState() => _StationSettingsScreenState();
}

class _StationSettingsScreenState extends State<StationSettingsScreen> {
  final InventoryService _inventoryService = InventoryService();
  final ManagementService _managementService = ManagementService();
  late Future<_StationSettingsData> _future;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _shiftsController = TextEditingController();
  final Map<String, TextEditingController> _controllers = {};
  bool _seeded = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _cityController.dispose();
    _shiftsController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<_StationSettingsData> _load() async {
    final results = await Future.wait([
      _inventoryService.fetchStationConfig(),
      _managementService.fetchEntries(month: currentMonthKey()),
    ]);
    final station = results[0] as StationConfigModel;
    final entries = results[1] as List<ShiftEntryModel>;
    final today = DateTime.now().toIso8601String().split('T').first;
    final todaysEntries = entries.where((entry) => entry.date == today).toList();
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
    return _StationSettingsData(station: station, pumpSales: pumpSales);
  }

  void _seedControllers(StationConfigModel station) {
    if (_seeded) {
      return;
    }
    _nameController.text = station.name;
    _codeController.text = station.code;
    _cityController.text = station.city;
    _shiftsController.text = '1 daily entry';
    for (final pump in station.pumps) {
      _controllers.putIfAbsent(
        '${pump.id}_label',
        () => TextEditingController(text: pump.label),
      );
    }
    _seeded = true;
  }

  void _resetFromStation(StationConfigModel station) {
    _seeded = false;
    _seedControllers(station);
  }

  Future<void> _reload() async {
    setState(() {
      _seeded = false;
      _future = _load();
    });
    await _future;
  }

  Future<void> _save(StationConfigModel station) async {
    final updated = StationConfigModel(
      id: station.id,
      name: _nameController.text.trim(),
      code: _codeController.text.trim(),
      city: _cityController.text.trim(),
      shifts: _shiftsController.text
          .contains('daily')
          ? const ['daily']
          : const ['daily'],
      pumps: station.pumps
          .map(
            (pump) => StationPumpModel(
              id: pump.id,
              label: _controllers['${pump.id}_label']?.text.trim() ?? pump.label,
            ),
          )
          .toList(),
      baseReadings: station.baseReadings,
    );

    await _inventoryService.saveStationConfig(updated);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Station settings saved.')),
    );
    setState(() {
      _isEditing = false;
      _seeded = false;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Station Settings'),
        actions: [
          if (widget.canEdit)
            FutureBuilder<_StationSettingsData>(
              future: _future,
              builder: (context, snapshot) {
                final station = snapshot.data?.station;
                return TextButton(
                  onPressed: station == null
                      ? null
                      : () {
                          setState(() {
                            if (_isEditing) {
                              _isEditing = false;
                              _resetFromStation(station);
                            } else {
                              _isEditing = true;
                            }
                          });
                        },
                  child: Text(_isEditing ? 'Cancel' : 'Edit'),
                );
              },
            ),
        ],
      ),
      body: FutureBuilder<_StationSettingsData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          final data = snapshot.data!;
          final station = data.station;
          _seedControllers(station);

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
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
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Station Overview',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _isEditing
                                  ? const Color(0xFFE0E7FF)
                                  : const Color(0xFFE5F7EE),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _isEditing ? 'Editing' : 'View only',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _isEditing
                                    ? const Color(0xFF1E40AF)
                                    : const Color(0xFF047857),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pump count is fixed. This screen is for viewing first, then editing station details only when needed.',
                        style: const TextStyle(color: Color(0xFF55606E)),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _nameController,
                        enabled: widget.canEdit && _isEditing,
                        decoration: const InputDecoration(labelText: 'Station Name'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _cityController,
                        enabled: widget.canEdit && _isEditing,
                        decoration: const InputDecoration(labelText: 'City'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _codeController,
                        enabled: widget.canEdit && _isEditing,
                        decoration: const InputDecoration(labelText: 'Code'),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _shiftsController,
                        enabled: false,
                        decoration: const InputDecoration(
                          labelText: 'Entry cycle',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Fixed pumps: ${station.pumps.map((pump) => pump.label).join(', ')}',
                        style: const TextStyle(
                          color: Color(0xFF55606E),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ...station.pumps.map(
                  (pump) {
                    final sales = data.pumpSales[pump.id] ??
                        const PumpReadings(petrol: 0, diesel: 0, twoT: 0);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  pump.id.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF55606E),
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.local_gas_station_rounded,
                                color: Color(0xFF1E5CBA),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _controllers['${pump.id}_label'],
                            enabled: widget.canEdit && _isEditing,
                            decoration: InputDecoration(
                              labelText: '${pump.id} label',
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Today\'s Sales',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF293340),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _PumpSalesCard(
                                  title: 'Petrol',
                                  value: formatLiters(sales.petrol),
                                  color: const Color(0xFF1E5CBA),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _PumpSalesCard(
                                  title: 'Diesel',
                                  value: formatLiters(sales.diesel),
                                  color: const Color(0xFF006C5C),
                                ),
                              ),
                              if (pump.id == 'pump2') ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _PumpSalesCard(
                                    title: '2T Oil',
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
                if (widget.canEdit && _isEditing)
                  FilledButton(
                    onPressed: () => _save(station),
                    child: const Text('Save Station Settings'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StationSettingsData {
  const _StationSettingsData({
    required this.station,
    required this.pumpSales,
  });

  final StationConfigModel station;
  final Map<String, PumpReadings> pumpSales;
}

class _PumpSalesCard extends StatelessWidget {
  const _PumpSalesCard({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
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
            title,
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
