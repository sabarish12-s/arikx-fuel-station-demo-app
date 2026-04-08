import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/domain_models.dart';
import '../services/inventory_service.dart';
import '../utils/formatters.dart';

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
    return error.toString().replaceFirst('Exception: ', '');
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
    if (_seeded) {
      return;
    }
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
      _future = _inventoryService.fetchStationConfig();
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
      if (!mounted) {
        return;
      }
      setState(() {
        _isEditing = false;
        _seeded = false;
        _future = _inventoryService.fetchStationConfig();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Planning rules saved.')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFB91C1C),
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
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
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [Text('Failed to load: ${_errorText(snapshot.error)}')],
          );
        }

        final station = snapshot.data!;
        _seedControllers(station);
        final planning = station.inventoryPlanning;

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
                          'Tank Stock & Reorder Planning',
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
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF153A8A), Color(0xFF1E5CBA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
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
                        'Baseline stock updated ${formatDateLabel(planning.updatedAt.split('T').first)}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
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
                            'Tank Stock Baseline',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF293340),
                            ),
                          ),
                        ),
                        if (!widget.canEdit)
                          const Chip(label: Text('View only')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This stock is separate from pump opening meter readings. Deliveries add to this baseline and saved sales reduce inventory automatically.',
                      style: TextStyle(color: Color(0xFF55606E), height: 1.4),
                    ),
                    const SizedBox(height: 18),
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
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Alert Timing',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF293340),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'These settings are shared for petrol, diesel, and 2T oil reorder prediction.',
                      style: TextStyle(color: Color(0xFF55606E), height: 1.4),
                    ),
                    const SizedBox(height: 18),
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
                const SizedBox(height: 20),
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
        );
      },
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
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
        fillColor: enabled ? const Color(0xFFF8F9FF) : const Color(0xFFF2F4F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
