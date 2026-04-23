import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/inventory_service.dart';
import '../utils/formatters.dart';
import '../utils/user_facing_errors.dart';
import '../widgets/clay_widgets.dart';
import '../widgets/responsive_text.dart';

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

  Future<StationConfigModel> _load({bool forceRefresh = false}) async {
    return _inventoryService.fetchStationConfig(forceRefresh: forceRefresh);
  }

  void _seedControllers(StationConfigModel station) {
    if (_seeded) return;
    _resetProfileControllers(station);
    _seeded = true;
  }

  void _resetProfileControllers(StationConfigModel station) {
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
    }
  }

  Future<void> _reload() async {
    setState(() {
      _seeded = false;
      _future = _load(forceRefresh: true);
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
      inventoryPlanning: station.inventoryPlanning,
      flagThreshold: station.flagThreshold,
    );

    await _inventoryService.saveStationConfig(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Station profile saved.')));
    setState(() {
      _isEditing = false;
      _seeded = false;
      _future = _load(forceRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = FutureBuilder<StationConfigModel>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done &&
            !snapshot.hasData) {
          return const ColoredBox(
            color: kClayBg,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError && !snapshot.hasData) {
          return ColoredBox(
            color: kClayBg,
            child: Center(child: Text(userFacingErrorMessage(snapshot.error))),
          );
        }
        final station = snapshot.data!;
        _seedControllers(station);

        return RefreshIndicator(
          onRefresh: _reload,
          child: ColoredBox(
            color: kClayBg,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                if (widget.embedded) ...[
                  _StationProfileHeroCard(
                    station: station,
                    canEdit: widget.canEdit,
                    isEditing: _isEditing,
                    onBack: widget.onBack,
                    onEdit: () {
                      setState(() {
                        if (_isEditing) {
                          _isEditing = false;
                          _resetProfileControllers(station);
                        } else {
                          _isEditing = true;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                ],

                // ── Station overview ───────────────────────────────
                ClayCard(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Station Details',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: kClayPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
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
                            label:
                                '${formatPumpLabel(pump.id, pump.label)} label',
                            enabled: widget.canEdit && _isEditing,
                            prefixIcon: Icons.local_gas_station_rounded,
                          ),
                        ),
                      ),
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
        automaticallyImplyLeading: false,
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
                              _resetProfileControllers(station);
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
class _StationProfileHeroCard extends StatelessWidget {
  const _StationProfileHeroCard({
    required this.station,
    required this.canEdit,
    required this.isEditing,
    required this.onEdit,
    this.onBack,
  });

  final StationConfigModel station;
  final bool canEdit;
  final bool isEditing;
  final VoidCallback onEdit;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [kClayHeroStart, kClayHeroEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: kClayHeroEnd.withValues(alpha: 0.45),
            offset: const Offset(0, 10),
            blurRadius: 24,
          ),
        ],
      ),
      child: Stack(
        children: [
          if (canEdit)
            Positioned(
              top: 0,
              right: 0,
              child: _HeroActionPill(
                icon: isEditing ? Icons.close_rounded : Icons.edit_rounded,
                label: isEditing ? 'Cancel' : 'Edit',
                onTap: onEdit,
              ),
            ),
          const Padding(
            padding: EdgeInsets.only(top: 2, right: 118),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SETTINGS',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 8),
                OneLineScaleText(
                  'Station Profile & Pumps',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroActionPill extends StatelessWidget {
  const _HeroActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            OneLineScaleText(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
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
  });

  final String label;
  final TextEditingController? controller;
  final bool enabled;
  final IconData? prefixIcon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
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
