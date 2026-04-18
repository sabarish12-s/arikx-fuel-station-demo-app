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

  @override
  void dispose() {
    _dateController.dispose();
    _noteController.dispose();
    for (final controller in _petrolOpeningControllers.values) {
      controller.dispose();
    }
    for (final controller in _dieselOpeningControllers.values) {
      controller.dispose();
    }
    _petrolStockController.dispose();
    _dieselStockController.dispose();
    _twoTStockController.dispose();
    _petrolCostController.dispose();
    _petrolSellController.dispose();
    _dieselCostController.dispose();
    _dieselSellController.dispose();
    _twoTCostController.dispose();
    _twoTSellController.dispose();
    super.dispose();
  }

  double _valueOf(TextEditingController controller) =>
      double.tryParse(controller.text.trim()) ?? 0;

  String _dateValue(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<void> _pickDate() async {
    final parsedDate = DateTime.tryParse(_dateController.text.trim());
    final initialDate = parsedDate ?? DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(initialDate.year - 5),
      lastDate: DateTime(initialDate.year + 5),
      helpText: 'Select effective date',
    );
    if (selectedDate == null) {
      return;
    }
    _dateController.text = _dateValue(selectedDate);
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? suffixText,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      style: const TextStyle(
        color: kClayPrimary,
        fontWeight: FontWeight.w800,
      ),
      decoration: clayDialogInputDecoration(
        label: label,
        prefixIcon: Icon(icon, color: kClaySub, size: 20),
      ).copyWith(
        suffixText: suffixText,
        suffixStyle: const TextStyle(
          color: kClaySub,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _twoColumnFields(Widget first, Widget second) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 300) {
          return Column(
            children: [
              first,
              const SizedBox(height: 10),
              second,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: first),
            const SizedBox(width: 10),
            Expanded(child: second),
          ],
        );
      },
    );
  }

  Widget _miniHeader({
    required String label,
    required IconData icon,
    Color color = kClayPrimary,
  }) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: kClayPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }

  Widget _nestedCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E8F5)),
      ),
      child: child,
    );
  }

  Widget _dateSection() {
    return ClayDialogSection(
      title: 'Setup date',
      subtitle: 'This date anchors the next sales, stock, and price entries.',
      child: TextField(
        controller: _dateController,
        textInputAction: TextInputAction.next,
        style: const TextStyle(
          color: kClayPrimary,
          fontWeight: FontWeight.w800,
        ),
        decoration: clayDialogInputDecoration(
          label: 'Effective date',
          hintText: 'YYYY-MM-DD',
          prefixIcon: const Icon(Icons.event_rounded, color: kClaySub),
        ).copyWith(
          suffixIcon: IconButton(
            tooltip: 'Pick date',
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_month_rounded, color: kClayPrimary),
          ),
        ),
      ),
    );
  }

  Widget _pumpReadingsSection() {
    return ClayDialogSection(
      title: 'Pump opening readings',
      subtitle: 'Capture each pump meter before starting entries for the day.',
      child: Column(
        children: [
          for (final pump in widget.station.pumps) ...[
            _nestedCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _miniHeader(
                    label: pump.label,
                    icon: Icons.local_gas_station_rounded,
                  ),
                  const SizedBox(height: 12),
                  _twoColumnFields(
                    _numberField(
                      controller: _petrolOpeningControllers[pump.id]!,
                      label: 'Petrol reading',
                      icon: Icons.opacity_rounded,
                    ),
                    _numberField(
                      controller: _dieselOpeningControllers[pump.id]!,
                      label: 'Diesel reading',
                      icon: Icons.water_drop_outlined,
                    ),
                  ),
                ],
              ),
            ),
            if (pump != widget.station.pumps.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _startingStockSection() {
    return ClayDialogSection(
      title: 'Starting stock',
      subtitle: 'Opening tank and oil stock available for this date.',
      child: Column(
        children: [
          _twoColumnFields(
            _numberField(
              controller: _petrolStockController,
              label: 'Petrol stock',
              icon: Icons.inventory_2_outlined,
              suffixText: 'L',
            ),
            _numberField(
              controller: _dieselStockController,
              label: 'Diesel stock',
              icon: Icons.inventory_2_outlined,
              suffixText: 'L',
            ),
          ),
          const SizedBox(height: 10),
          _numberField(
            controller: _twoTStockController,
            label: '2T oil stock',
            icon: Icons.oil_barrel_outlined,
            suffixText: 'L',
          ),
        ],
      ),
    );
  }

  Widget _fuelPricesSection() {
    final fuels = [
      (
        label: 'Petrol',
        cost: _petrolCostController,
        selling: _petrolSellController,
        icon: Icons.local_gas_station_rounded,
      ),
      (
        label: 'Diesel',
        cost: _dieselCostController,
        selling: _dieselSellController,
        icon: Icons.local_shipping_outlined,
      ),
      (
        label: '2T Oil',
        cost: _twoTCostController,
        selling: _twoTSellController,
        icon: Icons.oil_barrel_outlined,
      ),
    ];

    return ClayDialogSection(
      title: 'Fuel prices',
      subtitle: 'Set cost and selling prices used for sales calculations.',
      child: Column(
        children: [
          for (final fuel in fuels) ...[
            _nestedCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _miniHeader(label: fuel.label, icon: fuel.icon),
                  const SizedBox(height: 12),
                  _twoColumnFields(
                    _numberField(
                      controller: fuel.cost,
                      label: 'Cost price',
                      icon: Icons.currency_rupee_rounded,
                    ),
                    _numberField(
                      controller: fuel.selling,
                      label: 'Selling price',
                      icon: Icons.sell_outlined,
                    ),
                  ),
                ],
              ),
            ),
            if (fuel.label != fuels.last.label) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _noteSection() {
    return ClayDialogSection(
      title: 'Note',
      subtitle: 'Optional reason or context for this setup change.',
      child: TextField(
        controller: _noteController,
        minLines: 2,
        maxLines: 4,
        textInputAction: TextInputAction.done,
        style: const TextStyle(
          color: kClayPrimary,
          fontWeight: FontWeight.w700,
        ),
        decoration: clayDialogInputDecoration(
          label: 'Reason / note',
          hintText: 'Example: Updated for next business day setup',
          prefixIcon: const Padding(
            padding: EdgeInsets.only(bottom: 22),
            child: Icon(Icons.notes_rounded, color: kClaySub),
          ),
        ),
      ),
    );
  }

  _DaySetupFormValue _formValue() {
    return _DaySetupFormValue(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClayDialogShell(
      title: 'Day Setup',
      subtitle: 'Prepare the operating day with readings, stock, and prices.',
      icon: Icons.event_note_rounded,
      actions: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: kClayPrimary,
              side: BorderSide(color: kClayPrimary.withValues(alpha: 0.16)),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(_formValue()),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4D66A9),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            icon: const Icon(Icons.check_rounded, size: 19),
            label: const Text('Save setup'),
          ),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dateSection(),
          const SizedBox(height: 14),
          _pumpReadingsSection(),
          const SizedBox(height: 14),
          _startingStockSection(),
          const SizedBox(height: 14),
          _fuelPricesSection(),
          const SizedBox(height: 14),
          _noteSection(),
        ],
      ),
    );
  }
}
