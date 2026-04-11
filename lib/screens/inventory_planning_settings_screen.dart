import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/domain_models.dart';
import '../services/inventory_service.dart';
import '../utils/user_facing_errors.dart';
import '../widgets/responsive_text.dart';
import '../utils/formatters.dart';
import '../widgets/clay_widgets.dart';

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
  final TextEditingController _petrolController = TextEditingController();
  final TextEditingController _dieselController = TextEditingController();
  final TextEditingController _twoTController = TextEditingController();
  final TextEditingController _deliveryLeadController = TextEditingController();
  final TextEditingController _alertBeforeController = TextEditingController();
  bool _seeded = false;
  bool _isEditing = false;
  bool _saving = false;

  String _errorText(Object? error) {
    return userFacingErrorMessage(error);
  }

  @override
  void initState() {
    super.initState();
    _future = _inventoryService.fetchStationConfig();
  }

  @override
  void dispose() {
    _petrolController.dispose();
    _dieselController.dispose();
    _twoTController.dispose();
    _deliveryLeadController.dispose();
    _alertBeforeController.dispose();
    super.dispose();
  }

  void _seedControllers(StationConfigModel station) {
    if (_seeded) return;
    final planning = station.inventoryPlanning;
    _petrolController.text = (planning.openingStock['petrol'] ?? 0)
        .toStringAsFixed(2);
    _dieselController.text = (planning.openingStock['diesel'] ?? 0)
        .toStringAsFixed(2);
    _twoTController.text = (planning.openingStock['two_t_oil'] ?? 0)
        .toStringAsFixed(2);
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
    final petrol = double.tryParse(_petrolController.text.trim());
    final diesel = double.tryParse(_dieselController.text.trim());
    final twoT = double.tryParse(_twoTController.text.trim());
    final deliveryLead = int.tryParse(_deliveryLeadController.text.trim());
    final alertBefore = int.tryParse(_alertBeforeController.text.trim());

    if ([petrol, diesel, twoT].any((value) => value == null || value < 0) ||
        deliveryLead == null ||
        deliveryLead < 0 ||
        alertBefore == null ||
        alertBefore < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFB91C1C),
          content: Text('Enter valid non-negative stock and alert values.'),
        ),
      );
      return;
    }

    final petrolValue = petrol ?? 0;
    final dieselValue = diesel ?? 0;
    final twoTValue = twoT ?? 0;

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
          openingStock: {
            'petrol': petrolValue,
            'diesel': dieselValue,
            'two_t_oil': twoTValue,
          },
          currentStock: {
            'petrol': petrolValue,
            'diesel': dieselValue,
            'two_t_oil': twoTValue,
          },
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
      ).showSnackBar(const SnackBar(content: Text('Planning rules saved.')));
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
              children: [Text('Failed to load: ${_errorText(snapshot.error)}')],
            ),
          );
        }

        final station = snapshot.data!;
        _seedControllers(station);
        final planning = station.inventoryPlanning;

        return RefreshIndicator(
          onRefresh: _reload,
          child: ColoredBox(
            color: kClayBg,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                if (widget.embedded)
                  ClaySubHeader(
                    title: 'Tank Stock & Reorder Planning',
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

                // ── Hero ───────────────────────────────────────────
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
                        'REORDER PLANNING',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${planning.deliveryLeadDays} day delivery lead',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Alerts start ${planning.alertBeforeDays} day(s) before projected order date.',
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                      if (planning.updatedAt.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Baseline updated ${formatDateLabel(planning.updatedAt.split('T').first)}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── Tank stock baseline ────────────────────────────
                ClayCard(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Tank Stock Baseline',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: kClayPrimary,
                              ),
                            ),
                          ),
                          if (!widget.canEdit)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: kClayBg,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'View only',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: kClaySub,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Separate from pump opening meter readings. Deliveries add to this and saved sales reduce inventory automatically.',
                        style: TextStyle(color: kClaySub, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      _PlanningNumberField(
                        label: 'Petrol stock liters',
                        controller: _petrolController,
                        enabled: widget.canEdit && _isEditing && !_saving,
                      ),
                      const SizedBox(height: 12),
                      _PlanningNumberField(
                        label: 'Diesel stock liters',
                        controller: _dieselController,
                        enabled: widget.canEdit && _isEditing && !_saving,
                      ),
                      const SizedBox(height: 12),
                      _PlanningNumberField(
                        label: '2T oil stock liters',
                        controller: _twoTController,
                        enabled: widget.canEdit && _isEditing && !_saving,
                      ),
                    ],
                  ),
                ),

                // ── Alert timing ───────────────────────────────────
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
                        'Shared for petrol, diesel, and 2T oil reorder prediction.',
                        style: TextStyle(color: kClaySub, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      _PlanningNumberField(
                        label: 'Delivery lead days after ordering',
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

                if (widget.canEdit) ...[
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
                            : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Saving...' : 'Save Planning Rules'),
                  ),
                ],
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
        title: const Text('Tank Stock & Reorder Planning'),
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
