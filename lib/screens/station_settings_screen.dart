import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/inventory_service.dart';
import '../utils/formatters.dart';
import '../utils/user_facing_errors.dart';
import '../widgets/clay_widgets.dart';

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
    if (_seeded) return;
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Station profile saved.')),
    );
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
                userFacingErrorMessage(snapshot.error),
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
                    title: 'Station Profile & Pumps',
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

                // ── Station overview ───────────────────────────────
                ClayCard(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Station Overview',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: kClayPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Pump count is fixed. Edit station details only when needed.',
                        style: TextStyle(color: kClaySub, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      _ClayField(
                        controller: _nameController,
                        label: 'Station Name',
                        enabled: widget.canEdit && _isEditing,
                      ),
                      const SizedBox(height: 12),
                      _ClayField(
                        controller: _cityController,
                        label: 'City',
                        enabled: widget.canEdit && _isEditing,
                      ),
                      const SizedBox(height: 12),
                      _ClayField(
                        controller: _codeController,
                        label: 'Code',
                        enabled: widget.canEdit && _isEditing,
                      ),
                      const SizedBox(height: 12),
                      _ClayField(
                        controller: _shiftsController,
                        label: 'Entry cycle',
                        enabled: false,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Fixed pumps: ${station.pumps.map((pump) => formatPumpLabel(pump.id, pump.label)).join(', ')}',
                        style: const TextStyle(
                          color: kClaySub,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Pump labels ────────────────────────────────────
                ClayCard(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pump Labels',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: kClayPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Only pump names are managed here.',
                        style: TextStyle(color: kClaySub),
                      ),
                      const SizedBox(height: 16),
                      ...station.pumps.map(
                        (pump) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ClayField(
                            controller: _controllers['${pump.id}_label'],
                            label: '${formatPumpLabel(pump.id, pump.label)} label',
                            enabled: widget.canEdit && _isEditing,
                            prefixIcon: Icons.local_gas_station_rounded,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Meter limits ───────────────────────────────────
                ClayCard(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Daily Meter Limits',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: kClayPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Set the maximum daily meter sale per pump. Use 0 to disable.',
                        style: TextStyle(color: kClaySub),
                      ),
                      const SizedBox(height: 16),
                      ...station.pumps.map((pump) {
                        final supportsTwoT = pump.id == 'pump2';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: kClayBg,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                formatPumpLabel(pump.id, pump.label),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: kClayPrimary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _ClayField(
                                controller:
                                    _controllers[_limitKey(pump.id, 'petrol')],
                                label: 'Petrol daily meter limit',
                                enabled: widget.canEdit && _isEditing,
                                prefixIcon: Icons.speed_rounded,
                                numeric: true,
                              ),
                              const SizedBox(height: 12),
                              _ClayField(
                                controller:
                                    _controllers[_limitKey(pump.id, 'diesel')],
                                label: 'Diesel daily meter limit',
                                enabled: widget.canEdit && _isEditing,
                                prefixIcon: Icons.speed_rounded,
                                numeric: true,
                              ),
                              if (supportsTwoT) ...[
                                const SizedBox(height: 12),
                                _ClayField(
                                  controller:
                                      _controllers[_limitKey(pump.id, 'twoT')],
                                  label: '2T oil daily meter limit',
                                  enabled: widget.canEdit && _isEditing,
                                  prefixIcon: Icons.speed_rounded,
                                  numeric: true,
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
          ),
        );
      },
    );

    if (widget.embedded) return content;

    return Scaffold(
      backgroundColor: kClayBg,
      appBar: AppBar(
        backgroundColor: kClayBg,
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

// ─── Clay-styled text field ──────────────────────────────────────────────────
class _ClayField extends StatelessWidget {
  const _ClayField({
    required this.label,
    this.controller,
    this.enabled = true,
    this.prefixIcon,
    this.numeric = false,
  });

  final String label;
  final TextEditingController? controller;
  final bool enabled;
  final IconData? prefixIcon;
  final bool numeric;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : null,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: enabled ? kClayBg : const Color(0xFFE8EBF4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
      ),
    );
  }
}
