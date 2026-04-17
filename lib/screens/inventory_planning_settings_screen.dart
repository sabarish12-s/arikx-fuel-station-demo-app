import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/domain_models.dart';
import '../services/inventory_service.dart';
import '../utils/user_facing_errors.dart';
import '../widgets/clay_widgets.dart';
import '../widgets/responsive_text.dart';

class InventoryPlanningSettingsScreen extends StatefulWidget {
  const InventoryPlanningSettingsScreen({
    super.key,
    required this.canEdit,
    this.embedded = false,
    this.onBack,
  });

  final bool canEdit;
  final bool embedded;
  final VoidCallback? onBack;

  @override
  State<InventoryPlanningSettingsScreen> createState() =>
      _InventoryPlanningSettingsScreenState();
}

class _InventoryPlanningSettingsScreenState
    extends State<InventoryPlanningSettingsScreen> {
  final InventoryService _inventoryService = InventoryService();
  late Future<StationConfigModel> _future;
  final TextEditingController _deliveryLeadController = TextEditingController();
  final TextEditingController _alertBeforeController = TextEditingController();
  bool _seeded = false;
  bool _isEditing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _inventoryService.fetchStationConfig();
  }

  @override
  void dispose() {
    _deliveryLeadController.dispose();
    _alertBeforeController.dispose();
    super.dispose();
  }

  void _seedControllers(StationConfigModel station) {
    if (_seeded) return;
    final planning = station.inventoryPlanning;
    _deliveryLeadController.text = planning.deliveryLeadDays.toString();
    _alertBeforeController.text = planning.alertBeforeDays.toString();
    _seeded = true;
  }

  void _resetFromStation(StationConfigModel station) {
    _seeded = false;
    _seedControllers(station);
  }

  Future<void> _reload() async {
    setState(() {
      _seeded = false;
      _future = _inventoryService.fetchStationConfig(forceRefresh: true);
    });
    await _future;
  }

  Future<void> _save(StationConfigModel station) async {
    final deliveryLead = int.tryParse(_deliveryLeadController.text.trim());
    final alertBefore = int.tryParse(_alertBeforeController.text.trim());

    if (deliveryLead == null ||
        deliveryLead < 0 ||
        alertBefore == null ||
        alertBefore < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFB91C1C),
          content: Text('Enter valid non-negative alert values.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final updated = StationConfigModel(
        id: station.id,
        name: station.name,
        code: station.code,
        city: station.city,
        shifts: station.shifts,
        pumps: station.pumps,
        baseReadings: station.baseReadings,
        meterLimits: station.meterLimits,
        inventoryPlanning: InventoryPlanningModel(
          openingStock: station.inventoryPlanning.openingStock,
          currentStock: station.inventoryPlanning.currentStock,
          deliveryLeadDays: deliveryLead,
          alertBeforeDays: alertBefore,
          updatedAt: station.inventoryPlanning.updatedAt,
        ),
        flagThreshold: station.flagThreshold,
      );
      await _inventoryService.saveStationConfig(updated);
      if (!mounted) return;
      setState(() {
        _isEditing = false;
        _seeded = false;
        _future = _inventoryService.fetchStationConfig(forceRefresh: true);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Alert rules saved.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFB91C1C),
          content: Text(userFacingErrorMessage(error)),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Text(
                  'Failed to load: ${userFacingErrorMessage(snapshot.error)}',
                ),
              ],
            ),
          );
        }

        final station = snapshot.data!;
        final planning = station.inventoryPlanning;
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
                    title: 'Reorder Alert Rules',
                    onBack: widget.onBack,
                    trailing:
                        widget.canEdit
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
                Container(
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'REORDER ALERTS',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${planning.deliveryLeadDays} day lead time',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Alerts begin ${planning.alertBeforeDays} day(s) before the recommended order date.',
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ClayCard(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Alert Timing',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: kClayPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'These values control reorder warnings. Manual stock history is managed from Stock Management.',
                        style: TextStyle(color: kClaySub, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      _PlanningNumberField(
                        label: 'Purchase lead days after ordering',
                        controller: _deliveryLeadController,
                        enabled: widget.canEdit && _isEditing && !_saving,
                        decimals: false,
                      ),
                      const SizedBox(height: 12),
                      _PlanningNumberField(
                        label: 'Alert this many days before order date',
                        controller: _alertBeforeController,
                        enabled: widget.canEdit && _isEditing && !_saving,
                        decimals: false,
                      ),
                    ],
                  ),
                ),
                if (widget.canEdit)
                  FilledButton.icon(
                    onPressed:
                        _isEditing && !_saving ? () => _save(station) : null,
                    icon:
                        _saving
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.notifications_active_outlined),
                    label: Text(_saving ? 'Saving...' : 'Save Alert Rules'),
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
        title: const Text('Reorder Alert Rules'),
        actions: [
          if (widget.canEdit)
            FutureBuilder<StationConfigModel>(
              future: _future,
              builder: (context, snapshot) {
                final station = snapshot.data;
                return TextButton(
                  onPressed:
                      station == null
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
        child: OneLineScaleText(
          isEditing ? 'Cancel' : 'Edit',
          alignment: Alignment.center,
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

class _PlanningNumberField extends StatelessWidget {
  const _PlanningNumberField({
    required this.label,
    required this.controller,
    required this.enabled,
    this.decimals = true,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;
  final bool decimals;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.numberWithOptions(decimal: decimals),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          RegExp(decimals ? r'[0-9.]' : r'[0-9]'),
        ),
      ],
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: enabled ? kClayBg : const Color(0xFFE8EBF4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
