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

  String _price(String fuelKey, String field) {
    return formatCurrency(setup.fuelPrices[fuelKey]?[field] ?? 0);
  }

  String _auditName(String name, String id) {
    final trimmedName = name.trim();
    if (trimmedName.isNotEmpty) {
      return trimmedName;
    }
    return id.trim();
  }

  Widget _statusPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _detailGrid(List<_DaySetupDetailMetric> metrics) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth =
            constraints.maxWidth >= 440
                ? (constraints.maxWidth - 10) / 2
                : constraints.maxWidth;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children:
              metrics
                  .map(
                    (metric) => SizedBox(
                      width: itemWidth,
                      child: _DaySetupMetricTile(
                        label: metric.label,
                        value: metric.value,
                        icon: metric.icon,
                      ),
                    ),
                  )
                  .toList(),
        );
      },
    );
  }

  Widget _pumpReadingDetail(MapEntry<String, PumpReadings> entry) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E8F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: kClayPrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_gas_station_rounded,
                  color: kClayPrimary,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  formatPumpLabel(entry.key),
                  style: const TextStyle(
                    color: kClayPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _DaySetupInlineValue(
                  label: 'Petrol',
                  value: formatLiters(entry.value.petrol),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DaySetupInlineValue(
                  label: 'Diesel',
                  value: formatLiters(entry.value.diesel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _auditLine(String label, String name, String time) {
    final trimmedName = name.trim();
    final trimmedTime = time.trim();
    if (trimmedName.isEmpty && trimmedTime.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        '$label${trimmedName.isNotEmpty ? ' by $trimmedName' : ''}${trimmedTime.isNotEmpty ? ' on ${formatDateTimeLabel(trimmedTime)}' : ''}',
        style: const TextStyle(
          color: kClaySub,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
      ),
    );
  }

  Future<void> _showDetails(BuildContext context) async {
    final createdBy = _auditName(setup.createdByName, setup.createdBy);
    final updatedBy = _auditName(setup.updatedByName, setup.updatedBy);
    final deletedBy = _auditName(setup.deletedByName, setup.deletedBy);
    final lockedBy = _auditName(setup.lockedByName, setup.lockedBy);
    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => ClayDialogShell(
            title: formatDateLabel(setup.effectiveDate),
            subtitle: 'Day setup details',
            icon: Icons.fact_check_outlined,
            actions: [
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4D66A9),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClayDialogSection(
                  title: 'Starting stock',
                  child: _detailGrid([
                    _DaySetupDetailMetric(
                      label: 'Petrol',
                      value: formatLiters(setup.startingStock['petrol'] ?? 0),
                      icon: Icons.opacity_rounded,
                    ),
                    _DaySetupDetailMetric(
                      label: 'Diesel',
                      value: formatLiters(setup.startingStock['diesel'] ?? 0),
                      icon: Icons.water_drop_outlined,
                    ),
                    _DaySetupDetailMetric(
                      label: '2T Oil',
                      value: formatLiters(
                        setup.startingStock['two_t_oil'] ?? 0,
                      ),
                      icon: Icons.oil_barrel_outlined,
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                ClayDialogSection(
                  title: 'Fuel prices',
                  child: _detailGrid([
                    _DaySetupDetailMetric(
                      label: 'Petrol cost',
                      value: _price('petrol', 'costPrice'),
                      icon: Icons.currency_rupee_rounded,
                    ),
                    _DaySetupDetailMetric(
                      label: 'Petrol selling',
                      value: _price('petrol', 'sellingPrice'),
                      icon: Icons.sell_outlined,
                    ),
                    _DaySetupDetailMetric(
                      label: 'Diesel cost',
                      value: _price('diesel', 'costPrice'),
                      icon: Icons.currency_rupee_rounded,
                    ),
                    _DaySetupDetailMetric(
                      label: 'Diesel selling',
                      value: _price('diesel', 'sellingPrice'),
                      icon: Icons.sell_outlined,
                    ),
                    _DaySetupDetailMetric(
                      label: '2T Oil cost',
                      value: _price('two_t_oil', 'costPrice'),
                      icon: Icons.currency_rupee_rounded,
                    ),
                    _DaySetupDetailMetric(
                      label: '2T Oil selling',
                      value: _price('two_t_oil', 'sellingPrice'),
                      icon: Icons.sell_outlined,
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                ClayDialogSection(
                  title: 'Pump opening readings',
                  child: Column(
                    children: [
                      for (final entry in setup.openingReadings.entries) ...[
                        _pumpReadingDetail(entry),
                        if (entry.key != setup.openingReadings.keys.last)
                          const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
                if (setup.note.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClayDialogSection(
                    title: 'Note',
                    child: Text(
                      setup.note,
                      style: const TextStyle(
                        color: kClayPrimary,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                ClayDialogSection(
                  title: 'Status history',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _auditLine('Created', createdBy, setup.createdAt),
                      _auditLine('Updated', updatedBy, setup.updatedAt),
                      _auditLine('Locked', lockedBy, setup.lockedAt),
                      _auditLine('Deleted', deletedBy, setup.deletedAt),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusPills = [
      if (setup.isLocked) _statusPill('Locked', const Color(0xFF4D66A9)),
      if (setup.isDeleted) _statusPill('Deleted', const Color(0xFFAD5162)),
      if (!setup.isLocked && !setup.isDeleted)
        _statusPill('Active', const Color(0xFF0F8A73)),
    ];

    return ClayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatDateLabel(setup.effectiveDate),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: kClayPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${setup.openingReadings.length} pump readings saved',
                      style: const TextStyle(
                        color: kClaySub,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Wrap(spacing: 6, runSpacing: 6, children: statusPills),
            ],
          ),
          const SizedBox(height: 14),
          _detailGrid([
            _DaySetupDetailMetric(
              label: 'Petrol stock',
              value: formatLiters(setup.startingStock['petrol'] ?? 0),
              icon: Icons.opacity_rounded,
            ),
            _DaySetupDetailMetric(
              label: 'Diesel stock',
              value: formatLiters(setup.startingStock['diesel'] ?? 0),
              icon: Icons.water_drop_outlined,
            ),
            _DaySetupDetailMetric(
              label: 'Petrol price',
              value: _price('petrol', 'sellingPrice'),
              icon: Icons.sell_outlined,
            ),
            _DaySetupDetailMetric(
              label: 'Diesel price',
              value: _price('diesel', 'sellingPrice'),
              icon: Icons.sell_outlined,
            ),
          ]),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _showDetails(context),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('View'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4D66A9),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              if (canDelete) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFAD5162),
                      side: const BorderSide(color: Color(0xFFD8A8B1)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DaySetupDetailMetric {
  const _DaySetupDetailMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

class _DaySetupMetricTile extends StatelessWidget {
  const _DaySetupMetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8ECF7)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: kClayPrimary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: kClayPrimary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kClaySub,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kClayPrimary,
                    fontWeight: FontWeight.w900,
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

class _DaySetupInlineValue extends StatelessWidget {
  const _DaySetupInlineValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FD),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: kClaySub,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: kClayPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
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
    final defaultBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFD3DAEB), width: 1.2),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFF4D66A9), width: 1.8),
    );
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      cursorColor: const Color(0xFF4D66A9),
      style: const TextStyle(color: kClayPrimary, fontWeight: FontWeight.w800),
      decoration: clayDialogInputDecoration(
        label: label,
        prefixIcon: Icon(icon, color: kClaySub, size: 20),
      ).copyWith(
        filled: true,
        fillColor: const Color(0xFFFBFCFF),
        border: defaultBorder,
        enabledBorder: defaultBorder,
        focusedBorder: focusedBorder,
        suffixIcon: const Icon(Icons.edit_rounded, color: kClaySub, size: 18),
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
          return Column(children: [first, const SizedBox(height: 10), second]);
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
      subtitle:
          'Tap the reading boxes to edit each pump meter before starting entries for the day.',
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
