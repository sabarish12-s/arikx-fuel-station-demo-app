import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/inventory_service.dart';
import '../utils/formatters.dart';
import '../widgets/clay_widgets.dart';

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
    if (_seeded) return;
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
    if (!mounted) return;
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
          return const ColoredBox(
            color: kClayBg,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return ColoredBox(
            color: kClayBg,
            child: Center(
              child: Text(
                snapshot.error.toString().replaceFirst('Exception: ', ''),
              ),
            ),
          );
        }

        final station = snapshot.data!;
        _seedControllers(station);

        return RefreshIndicator(
          onRefresh: _reload,
          child: ColoredBox(
            color: kClayBg,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                if (widget.embedded)
                  ClaySubHeader(
                    title: 'Pump Opening Readings',
                    onBack: widget.onBack,
                    trailing: widget.canEdit
                        ? _EditTogglePill(
                            isEditing: _isEditing,
                            onTap: () {
                              setState(() {
                                if (_isEditing) {
                                  _isEditing = false;
                                  _resetFromStation(station);
                                } else {
                                  _isEditing = true;
                                }
                              });
                            },
                          )
                        : null,
                  ),

                // ── Info card ──────────────────────────────────────
                ClayCard(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Opening Meter Readings',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: kClayPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'These values are used whenever a day has no previous entry to carry forward.',
                        style: TextStyle(color: kClaySub, height: 1.4),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Station: ${station.name}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: kClayPrimary,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Per-pump cards ─────────────────────────────────
                ...station.pumps.map((pump) {
                  return ClayCard(
                    margin: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A3A7A).withValues(
                                  alpha: 0.10,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.speed_rounded,
                                color: Color(0xFF1A3A7A),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              formatPumpLabel(pump.id, pump.label),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: kClayPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _NumericField(
                          controller:
                              _controllers[_readingKey(pump.id, 'petrol')],
                          label: 'Petrol opening reading',
                          enabled: widget.canEdit && _isEditing,
                        ),
                        const SizedBox(height: 12),
                        _NumericField(
                          controller:
                              _controllers[_readingKey(pump.id, 'diesel')],
                          label: 'Diesel opening reading',
                          enabled: widget.canEdit && _isEditing,
                        ),
                        if (_supportsTwoT(pump.id)) ...[
                          const SizedBox(height: 12),
                          _NumericField(
                            controller:
                                _controllers[_readingKey(pump.id, 'twoT')],
                            label: '2T oil opening reading',
                            enabled: widget.canEdit && _isEditing,
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
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent();
    if (widget.embedded) return content;

    return Scaffold(
      backgroundColor: kClayBg,
      appBar: AppBar(
        backgroundColor: kClayBg,
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

// ─── Edit toggle pill ────────────────────────────────────────────────────────
class _EditTogglePill extends StatelessWidget {
  const _EditTogglePill({required this.isEditing, required this.onTap});
  final bool isEditing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFB8C0DC).withValues(alpha: 0.65),
              offset: const Offset(4, 4),
              blurRadius: 10,
            ),
            const BoxShadow(
              color: Colors.white,
              offset: Offset(-3, -3),
              blurRadius: 8,
            ),
          ],
        ),
        child: Text(
          isEditing ? 'Cancel' : 'Edit',
          style: TextStyle(
            color: isEditing ? const Color(0xFFCE5828) : kClayPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ─── Numeric field ───────────────────────────────────────────────────────────
class _NumericField extends StatelessWidget {
  const _NumericField({
    required this.label,
    required this.controller,
    required this.enabled,
  });

  final String label;
  final TextEditingController? controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.local_gas_station_rounded),
        filled: true,
        fillColor: enabled ? kClayBg : const Color(0xFFE8EBF4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
