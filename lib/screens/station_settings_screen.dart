import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/inventory_service.dart';
import '../utils/formatters.dart';

class StationSettingsScreen extends StatefulWidget {
  const StationSettingsScreen({
    super.key,
    required this.canEdit,
    this.embedded = false,
    this.onBack,
  });

  final bool canEdit;
  final bool embedded;
  final VoidCallback? onBack;

  @override
  State<StationSettingsScreen> createState() => _StationSettingsScreenState();
}

class _StationSettingsScreenState extends State<StationSettingsScreen> {
  final InventoryService _inventoryService = InventoryService();
  late Future<StationConfigModel> _future;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _shiftsController = TextEditingController();
  final Map<String, TextEditingController> _controllers = {};
  bool _seeded = false;
  bool _isEditing = false;

  String _limitKey(String pumpId, String fuelKey) =>
      '${pumpId}_${fuelKey}_limit';

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

  Future<StationConfigModel> _load() async {
    return _inventoryService.fetchStationConfig();
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
      final labelKey = '${pump.id}_label';
      final labelController =
          _controllers[labelKey] ?? TextEditingController(text: pump.label);
      labelController.text = pump.label;
      _controllers[labelKey] = labelController;
      final limits =
          station.meterLimits[pump.id] ??
          const PumpReadings(petrol: 0, diesel: 0, twoT: 0);
      final petrolKey = _limitKey(pump.id, 'petrol');
      final petrolController =
          _controllers[petrolKey] ??
          TextEditingController(text: limits.petrol.toStringAsFixed(2));
      petrolController.text = limits.petrol.toStringAsFixed(2);
      _controllers[petrolKey] = petrolController;
      final dieselKey = _limitKey(pump.id, 'diesel');
      final dieselController =
          _controllers[dieselKey] ??
          TextEditingController(text: limits.diesel.toStringAsFixed(2));
      dieselController.text = limits.diesel.toStringAsFixed(2);
      _controllers[dieselKey] = dieselController;
      final twoTKey = _limitKey(pump.id, 'twoT');
      final twoTController =
          _controllers[twoTKey] ??
          TextEditingController(text: limits.twoT.toStringAsFixed(2));
      twoTController.text = limits.twoT.toStringAsFixed(2);
      _controllers[twoTKey] = twoTController;
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
      shifts: _shiftsController.text.contains('daily')
          ? const ['daily']
          : const ['daily'],
      pumps: station.pumps
          .map(
            (pump) => StationPumpModel(
              id: pump.id,
              label:
                  _controllers['${pump.id}_label']?.text.trim() ?? pump.label,
            ),
          )
          .toList(),
      baseReadings: station.baseReadings,
      meterLimits: {
        for (final pump in station.pumps)
          pump.id: PumpReadings(
            petrol:
                double.tryParse(
                  _controllers[_limitKey(pump.id, 'petrol')]?.text ?? '',
                ) ??
                0,
            diesel:
                double.tryParse(
                  _controllers[_limitKey(pump.id, 'diesel')]?.text ?? '',
                ) ??
                0,
            twoT:
                double.tryParse(
                  _controllers[_limitKey(pump.id, 'twoT')]?.text ?? '',
                ) ??
                0,
          ),
      },
      inventoryPlanning: station.inventoryPlanning,
      flagThreshold: station.flagThreshold,
    );

    await _inventoryService.saveStationConfig(updated);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Station profile saved.')));
    setState(() {
      _isEditing = false;
      _seeded = false;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = FutureBuilder<StationConfigModel>(
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
                          'Station Profile & Pumps',
                          style: TextStyle(
                            fontSize: 22,
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
                        const Expanded(
                          child: Text(
                            'Station Overview',
                            style: TextStyle(
                              fontSize: 18,
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
                      decoration: const InputDecoration(
                        labelText: 'Station Name',
                      ),
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
                    const SizedBox(height: 12),
                    TextField(
                      controller: _shiftsController,
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: 'Entry cycle',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Fixed pumps: ${station.pumps.map((pump) => formatPumpLabel(pump.id, pump.label)).join(', ')}',
                      style: const TextStyle(
                        color: Color(0xFF55606E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pump Labels',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF293340),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Only pump names are managed here. Sales details are not shown on this page.',
                      style: TextStyle(color: Color(0xFF55606E)),
                    ),
                    const SizedBox(height: 16),
                    ...station.pumps.map(
                      (pump) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextField(
                          controller: _controllers['${pump.id}_label'],
                          enabled: widget.canEdit && _isEditing,
                          decoration: InputDecoration(
                            labelText:
                                '${formatPumpLabel(pump.id, pump.label)} label',
                            prefixIcon: const Icon(
                              Icons.local_gas_station_rounded,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Daily Meter Limits',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF293340),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Set the maximum daily meter sale per pump. Use 0 to keep the limit disabled.',
                      style: TextStyle(color: Color(0xFF55606E)),
                    ),
                    const SizedBox(height: 16),
                    ...station.pumps.map((pump) {
                      final supportsTwoT = pump.id == 'pump2';
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
                              formatPumpLabel(pump.id, pump.label),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF293340),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller:
                                  _controllers[_limitKey(pump.id, 'petrol')],
                              enabled: widget.canEdit && _isEditing,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Petrol daily meter limit',
                                prefixIcon: Icon(Icons.speed_rounded),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller:
                                  _controllers[_limitKey(pump.id, 'diesel')],
                              enabled: widget.canEdit && _isEditing,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Diesel daily meter limit',
                                prefixIcon: Icon(Icons.speed_rounded),
                              ),
                            ),
                            if (supportsTwoT) ...[
                              const SizedBox(height: 12),
                              TextField(
                                controller:
                                    _controllers[_limitKey(pump.id, 'twoT')],
                                enabled: widget.canEdit && _isEditing,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: '2T oil daily meter limit',
                                  prefixIcon: Icon(Icons.speed_rounded),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              if (widget.canEdit && _isEditing)
                FilledButton(
                  onPressed: () => _save(station),
                  child: const Text('Save Station Profile'),
                ),
            ],
          ),
        );
      },
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Station Profile & Pumps'),
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
