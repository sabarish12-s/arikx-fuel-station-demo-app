import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/inventory_service.dart';
import '../utils/formatters.dart';

class OpeningStockSettingsScreen extends StatefulWidget {
  const OpeningStockSettingsScreen({
    super.key,
    required this.canEdit,
    this.embedded = false,
    this.onBack,
  });

  final bool canEdit;
  final bool embedded;
  final VoidCallback? onBack;

  @override
  State<OpeningStockSettingsScreen> createState() =>
      _OpeningStockSettingsScreenState();
}

class _OpeningStockSettingsScreenState
    extends State<OpeningStockSettingsScreen> {
  final InventoryService _inventoryService = InventoryService();
  late Future<StationConfigModel> _future;
  final Map<String, TextEditingController> _controllers = {};
  bool _seeded = false;
  bool _isEditing = false;

  String _readingKey(String pumpId, String fuelKey) => '${pumpId}_$fuelKey';

  bool _supportsTwoT(String pumpId) => pumpId == 'pump2';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<StationConfigModel> _load() async {
    return _inventoryService.fetchStationConfig();
  }

  void _seedControllers(StationConfigModel station) {
    if (_seeded) {
      return;
    }
    for (final pump in station.pumps) {
      final readings =
          station.baseReadings[pump.id] ??
          const PumpReadings(petrol: 0, diesel: 0, twoT: 0);
      for (final fuelKey in ['petrol', 'diesel', 'twoT']) {
        final key = _readingKey(pump.id, fuelKey);
        final controller =
            _controllers[key] ??
            TextEditingController(
              text: _valueForFuel(readings, fuelKey).toStringAsFixed(2),
            );
        controller.text = _valueForFuel(readings, fuelKey).toStringAsFixed(2);
        _controllers[key] = controller;
      }
    }
    _seeded = true;
  }

  double _valueForFuel(PumpReadings readings, String fuelKey) {
    switch (fuelKey) {
      case 'petrol':
        return readings.petrol;
      case 'diesel':
        return readings.diesel;
      case 'twoT':
        return readings.twoT;
      default:
        return 0;
    }
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
      name: station.name,
      code: station.code,
      city: station.city,
      shifts: station.shifts,
      pumps: station.pumps,
      baseReadings: {
        for (final pump in station.pumps)
          pump.id: PumpReadings(
            petrol:
                double.tryParse(
                  _controllers[_readingKey(pump.id, 'petrol')]?.text ?? '',
                ) ??
                0,
            diesel:
                double.tryParse(
                  _controllers[_readingKey(pump.id, 'diesel')]?.text ?? '',
                ) ??
                0,
            twoT: _supportsTwoT(pump.id)
                ? double.tryParse(
                        _controllers[_readingKey(pump.id, 'twoT')]?.text ?? '',
                      ) ??
                      0
                : 0,
          ),
      },
      meterLimits: station.meterLimits,
      inventoryPlanning: station.inventoryPlanning,
      flagThreshold: station.flagThreshold,
    );

    await _inventoryService.saveStationConfig(updated);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pump opening readings saved.')),
    );
    setState(() {
      _isEditing = false;
      _seeded = false;
      _future = _load();
    });
  }

  Widget _buildContent() {
    return FutureBuilder<StationConfigModel>(
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

        final station = snapshot.data!;
        _seedControllers(station);

        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              if (widget.embedded)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: widget.onBack,
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const Expanded(
                        child: Text(
                          'Pump Opening Readings',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF293340),
                          ),
                        ),
                      ),
                      if (widget.canEdit)
                        TextButton(
                          onPressed: () {
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
                        ),
                    ],
                  ),
                ),
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
                            'Current Pump Opening Readings',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF293340),
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
                      'Use this to set the opening meter reading for each pump. '
                      'These values are used whenever a day has no previous entry to carry forward.',
                      style: const TextStyle(color: Color(0xFF55606E)),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Station: ${station.name}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF293340),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...station.pumps.map((pump) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatPumpLabel(pump.id, pump.label),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF293340),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Edit the opening reading that should be treated as the pump starting value.',
                        style: TextStyle(color: Color(0xFF55606E)),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller:
                            _controllers[_readingKey(pump.id, 'petrol')],
                        enabled: widget.canEdit && _isEditing,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Petrol opening reading',
                          prefixIcon: Icon(Icons.local_gas_station_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller:
                            _controllers[_readingKey(pump.id, 'diesel')],
                        enabled: widget.canEdit && _isEditing,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Diesel opening reading',
                          prefixIcon: Icon(Icons.local_gas_station_rounded),
                        ),
                      ),
                      if (_supportsTwoT(pump.id)) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller:
                              _controllers[_readingKey(pump.id, 'twoT')],
                          enabled: widget.canEdit && _isEditing,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: '2T oil opening reading',
                            prefixIcon: Icon(Icons.local_gas_station_rounded),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
              if (widget.canEdit && _isEditing)
                FilledButton(
                  onPressed: () => _save(station),
                  child: const Text('Save Opening Readings'),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent();

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pump Opening Readings'),
        actions: [
          if (widget.canEdit)
            FutureBuilder<StationConfigModel>(
              future: _future,
              builder: (context, snapshot) {
                final station = snapshot.data;
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
      body: content,
    );
  }
}
