import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/inventory_service.dart';
import '../utils/formatters.dart';
import '../utils/user_facing_errors.dart';
import '../widgets/clay_widgets.dart';

class DaySetupScreen extends StatefulWidget {
  const DaySetupScreen({
    super.key,
    required this.canEdit,
    this.embedded = false,
    this.onBack,
  });

  final bool canEdit;
  final bool embedded;
  final VoidCallback? onBack;

  @override
  State<DaySetupScreen> createState() => _DaySetupScreenState();
}

class _DaySetupScreenState extends State<DaySetupScreen> {
  final InventoryService _inventoryService = InventoryService();

  StationConfigModel? _station;
  DaySetupStateModel? _state;
  List<StationDaySetupModel> _activeHistory = const [];
  List<StationDaySetupModel> _deletedHistory = const [];
  bool _showDeleted = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        _inventoryService.fetchStationConfig(forceRefresh: forceRefresh),
        _inventoryService.fetchDaySetupState(forceRefresh: forceRefresh),
        _inventoryService.fetchDaySetups(forceRefresh: forceRefresh),
        _inventoryService.fetchDaySetups(
          deletedOnly: true,
          forceRefresh: forceRefresh,
        ),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _station = results[0] as StationConfigModel;
        _state = results[1] as DaySetupStateModel;
        _activeHistory = results[2] as List<StationDaySetupModel>;
        _deletedHistory = results[3] as List<StationDaySetupModel>;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = userFacingErrorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _openSetupDialog() async {
    final station = _station;
    final state = _state;
    if (station == null || state == null) {
      return;
    }

    final targetDate =
        state.nextAllowedSetupDate.trim().isNotEmpty
            ? state.nextAllowedSetupDate
            : state.allowedEntryDate;
    final matching =
        _activeHistory
            .where((item) => item.effectiveDate == targetDate)
            .toList();
    final existing = matching.isEmpty ? null : matching.first;
    final fallback =
        existing ?? (_activeHistory.isEmpty ? null : _activeHistory.last);
    final result = await showDialog<_DaySetupFormValue>(
      context: context,
      builder:
          (context) => _DaySetupDialog(
            station: station,
            initialDate: targetDate,
            initialSetup: existing,
            fallbackSetup: fallback,
          ),
    );
    if (result == null) {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _inventoryService.saveDaySetup(
        effectiveDate: result.effectiveDate,
        openingReadings: result.openingReadings,
        startingStock: result.startingStock,
        fuelPrices: result.fuelPrices,
        note: result.note,
      );
      if (!mounted) {
        return;
      }
      await _load(forceRefresh: true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = userFacingErrorMessage(error);
      });
    }
  }

  Future<void> _deleteSetup(StationDaySetupModel setup) async {
    final confirmed = await showClayConfirmDialog(
      context: context,
      title: 'Delete Day Setup',
      message:
          'Delete the day setup for ${formatDateLabel(setup.effectiveDate)}? This only works before sales are approved for that date.',
      confirmLabel: 'Delete',
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _inventoryService.deleteDaySetup(setup.effectiveDate);
      if (!mounted) {
        return;
      }
      await _load(forceRefresh: true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = userFacingErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final station = _station;
    final history = _showDeleted ? _deletedHistory : _activeHistory;

    if (_busy && state == null) {
      return const Scaffold(
        backgroundColor: kClayBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (station == null || state == null) {
      return Scaffold(
        backgroundColor: kClayBg,
        appBar: AppBar(
          backgroundColor: kClayBg,
          title: const Text('Day Setup'),
        ),
        body: Center(child: Text(_error ?? 'Unable to load day setup.')),
      );
    }

    return Scaffold(
      backgroundColor: kClayBg,
      appBar:
          widget.embedded
              ? null
              : AppBar(
                backgroundColor: kClayBg,
                title: const Text('Day Setup'),
              ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (widget.embedded)
            ClaySubHeader(title: 'Day Setup', onBack: widget.onBack),
          if (widget.embedded) const SizedBox(height: 16),
          ClayCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Operational Start Chain',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: kClayPrimary,
                        ),
                      ),
                    ),
                    if (widget.canEdit)
                      FilledButton.icon(
                        onPressed: _busy ? null : _openSetupDialog,
                        icon: const Icon(Icons.event_note_rounded),
                        label: const Text('Update Day Setup'),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  state.setupExists
                      ? 'Sales entry is enforced from one dated setup chain. The next pending sales date is fixed from this setup history.'
                      : 'Create the first day setup to start the sales, stock, and pricing chain.',
                  style: const TextStyle(
                    color: kClaySub,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _InfoPill(
                      label: 'Next setup date',
                      value:
                          state.nextAllowedSetupDate.isEmpty
                              ? 'Not ready'
                              : formatDateLabel(state.nextAllowedSetupDate),
                    ),
                    _InfoPill(
                      label: 'Allowed sales date',
                      value:
                          state.allowedEntryDate.isEmpty
                              ? 'Blocked'
                              : formatDateLabel(state.allowedEntryDate),
                    ),
                    _InfoPill(
                      label: 'Active setup',
                      value:
                          state.activeSetupDate.isEmpty
                              ? 'Not set'
                              : formatDateLabel(state.activeSetupDate),
                    ),
                  ],
                ),
                if (state.entryLockedReason.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F4FB),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      state.entryLockedReason,
                      style: const TextStyle(
                        color: kClayPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _showDeleted = false),
                  style: OutlinedButton.styleFrom(
                    backgroundColor:
                        !_showDeleted ? const Color(0xFFE8EDF9) : Colors.white,
                  ),
                  child: Text('Active (${_activeHistory.length})'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _showDeleted = true),
                  style: OutlinedButton.styleFrom(
                    backgroundColor:
                        _showDeleted ? const Color(0xFFE8EDF9) : Colors.white,
                  ),
                  child: Text('Deleted (${_deletedHistory.length})'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_error != null) ...[
            Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFFB42318),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (history.isEmpty)
            const ClayCard(
              child: Text(
                'No day setup history for this view.',
                style: TextStyle(color: kClaySub, fontWeight: FontWeight.w600),
              ),
            )
          else
            ...history.map(
              (setup) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _DaySetupHistoryCard(
                  setup: setup,
                  canDelete: widget.canEdit && !_showDeleted && !setup.isLocked,
                  onDelete: () => _deleteSetup(setup),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4FB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: kClaySub,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: kClayPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DaySetupHistoryCard extends StatelessWidget {
  const _DaySetupHistoryCard({
    required this.setup,
    required this.canDelete,
    required this.onDelete,
  });

  final StationDaySetupModel setup;
  final bool canDelete;
  final VoidCallback onDelete;

  Widget _metric(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FD),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: kClaySub,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: kClayPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  formatDateLabel(setup.effectiveDate),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: kClayPrimary,
                  ),
                ),
              ),
              if (setup.isLocked)
                const _InfoPill(label: 'Status', value: 'Locked'),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _metric(
                'Stock',
                'P ${formatLiters(setup.startingStock['petrol'] ?? 0)}  D ${formatLiters(setup.startingStock['diesel'] ?? 0)}  2T ${formatLiters(setup.startingStock['two_t_oil'] ?? 0)}',
              ),
              _metric(
                'Prices',
                'P ${formatCurrency(setup.fuelPrices['petrol']?['sellingPrice'] ?? 0)}  D ${formatCurrency(setup.fuelPrices['diesel']?['sellingPrice'] ?? 0)}  2T ${formatCurrency(setup.fuelPrices['two_t_oil']?['sellingPrice'] ?? 0)}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...setup.openingReadings.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${entry.key}: Petrol ${formatLiters(entry.value.petrol)}, Diesel ${formatLiters(entry.value.diesel)}',
                style: const TextStyle(
                  color: kClayPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (setup.note.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              setup.note,
              style: const TextStyle(
                color: kClaySub,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (canDelete) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Delete'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DaySetupFormValue {
  const _DaySetupFormValue({
    required this.effectiveDate,
    required this.openingReadings,
    required this.startingStock,
    required this.fuelPrices,
    required this.note,
  });

  final String effectiveDate;
  final Map<String, PumpReadings> openingReadings;
  final Map<String, double> startingStock;
  final Map<String, Map<String, double>> fuelPrices;
  final String note;
}

class _DaySetupDialog extends StatefulWidget {
  const _DaySetupDialog({
    required this.station,
    required this.initialDate,
    this.initialSetup,
    this.fallbackSetup,
  });

  final StationConfigModel station;
  final String initialDate;
  final StationDaySetupModel? initialSetup;
  final StationDaySetupModel? fallbackSetup;

  @override
  State<_DaySetupDialog> createState() => _DaySetupDialogState();
}

class _DaySetupDialogState extends State<_DaySetupDialog> {
  late final TextEditingController _dateController;
  late final TextEditingController _noteController;
  late final Map<String, TextEditingController> _petrolOpeningControllers;
  late final Map<String, TextEditingController> _dieselOpeningControllers;
  late final TextEditingController _petrolStockController;
  late final TextEditingController _dieselStockController;
  late final TextEditingController _twoTStockController;
  late final TextEditingController _petrolCostController;
  late final TextEditingController _petrolSellController;
  late final TextEditingController _dieselCostController;
  late final TextEditingController _dieselSellController;
  late final TextEditingController _twoTCostController;
  late final TextEditingController _twoTSellController;

  @override
  void initState() {
    super.initState();
    final seed = widget.initialSetup ?? widget.fallbackSetup;
    _dateController = TextEditingController(text: widget.initialDate);
    _noteController = TextEditingController(
      text: widget.initialSetup?.note ?? '',
    );
    _petrolOpeningControllers = {
      for (final pump in widget.station.pumps)
        pump.id: TextEditingController(
          text:
              '${seed?.openingReadings[pump.id]?.petrol ?? widget.station.baseReadings[pump.id]?.petrol ?? 0}',
        ),
    };
    _dieselOpeningControllers = {
      for (final pump in widget.station.pumps)
        pump.id: TextEditingController(
          text:
              '${seed?.openingReadings[pump.id]?.diesel ?? widget.station.baseReadings[pump.id]?.diesel ?? 0}',
        ),
    };
    _petrolStockController = TextEditingController(
      text: '${seed?.startingStock['petrol'] ?? 0}',
    );
    _dieselStockController = TextEditingController(
      text: '${seed?.startingStock['diesel'] ?? 0}',
    );
    _twoTStockController = TextEditingController(
      text: '${seed?.startingStock['two_t_oil'] ?? 0}',
    );
    _petrolCostController = TextEditingController(
      text: '${seed?.fuelPrices['petrol']?['costPrice'] ?? 0}',
    );
    _petrolSellController = TextEditingController(
      text: '${seed?.fuelPrices['petrol']?['sellingPrice'] ?? 0}',
    );
    _dieselCostController = TextEditingController(
      text: '${seed?.fuelPrices['diesel']?['costPrice'] ?? 0}',
    );
    _dieselSellController = TextEditingController(
      text: '${seed?.fuelPrices['diesel']?['sellingPrice'] ?? 0}',
    );
    _twoTCostController = TextEditingController(
      text: '${seed?.fuelPrices['two_t_oil']?['costPrice'] ?? 0}',
    );
    _twoTSellController = TextEditingController(
      text: '${seed?.fuelPrices['two_t_oil']?['sellingPrice'] ?? 0}',
    );
  }

  double _valueOf(TextEditingController controller) =>
      double.tryParse(controller.text.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Day Setup'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _dateController,
                decoration: const InputDecoration(
                  labelText: 'Effective date',
                  hintText: 'YYYY-MM-DD',
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Pump opening readings',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              ...widget.station.pumps.map(
                (pump) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pump.label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _petrolOpeningControllers[pump.id],
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Petrol',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _dieselOpeningControllers[pump.id],
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Diesel',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Starting stock',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _petrolStockController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Petrol stock'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _dieselStockController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Diesel stock'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _twoTStockController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: '2T oil stock'),
              ),
              const SizedBox(height: 16),
              const Text(
                'Fuel prices',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              ...[
                ('Petrol', _petrolCostController, _petrolSellController),
                ('Diesel', _dieselCostController, _dieselSellController),
                ('2T Oil', _twoTCostController, _twoTSellController),
              ].map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$1,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: item.$2,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Cost',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: item.$3,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Selling',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(labelText: 'Reason / note'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              _DaySetupFormValue(
                effectiveDate: _dateController.text.trim(),
                openingReadings: {
                  for (final pump in widget.station.pumps)
                    pump.id: PumpReadings(
                      petrol: _valueOf(_petrolOpeningControllers[pump.id]!),
                      diesel: _valueOf(_dieselOpeningControllers[pump.id]!),
                      twoT: 0,
                    ),
                },
                startingStock: {
                  'petrol': _valueOf(_petrolStockController),
                  'diesel': _valueOf(_dieselStockController),
                  'two_t_oil': _valueOf(_twoTStockController),
                },
                fuelPrices: {
                  'petrol': {
                    'costPrice': _valueOf(_petrolCostController),
                    'sellingPrice': _valueOf(_petrolSellController),
                  },
                  'diesel': {
                    'costPrice': _valueOf(_dieselCostController),
                    'sellingPrice': _valueOf(_dieselSellController),
                  },
                  'two_t_oil': {
                    'costPrice': _valueOf(_twoTCostController),
                    'sellingPrice': _valueOf(_twoTSellController),
                  },
                },
                note: _noteController.text.trim(),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
