import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/inventory_service.dart';
import '../services/report_export_service.dart';
import '../utils/formatters.dart';
import '../utils/user_facing_errors.dart';
import '../widgets/clay_widgets.dart';
import '../widgets/responsive_text.dart';

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

class _OpeningReadingsData {
  const _OpeningReadingsData({required this.station, required this.logs});

  final StationConfigModel station;
  final List<PumpOpeningReadingLogModel> logs;
}

class _OpeningStockSettingsScreenState
    extends State<OpeningStockSettingsScreen> {
  final InventoryService _inventoryService = InventoryService();
  late Future<_OpeningReadingsData> _future;
  final TextEditingController _effectiveDateController =
      TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final Map<String, TextEditingController> _controllers = {};
  bool _seeded = false;
  bool _saving = false;

  String _readingKey(String pumpId, String fuelKey) => '${pumpId}_$fuelKey';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _effectiveDateController.dispose();
    _noteController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<_OpeningReadingsData> _load({bool forceRefresh = false}) async {
    final results = await Future.wait<dynamic>([
      _inventoryService.fetchStationConfig(forceRefresh: forceRefresh),
      _inventoryService.fetchOpeningReadingLogs(forceRefresh: forceRefresh),
    ]);
    return _OpeningReadingsData(
      station: results[0] as StationConfigModel,
      logs: results[1] as List<PumpOpeningReadingLogModel>,
    );
  }

  void _seedControllers(StationConfigModel station) {
    if (_seeded) return;
    _effectiveDateController.text = DateTime.now()
        .toIso8601String()
        .split('T')
        .first;
    _noteController.clear();
    for (final pump in station.pumps) {
      final readings =
          station.baseReadings[pump.id] ??
          const PumpReadings(petrol: 0, diesel: 0, twoT: 0);
      for (final fuelKey in ['petrol', 'diesel']) {
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

  Future<void> _pickEffectiveDate() async {
    final initialDate =
        DateTime.tryParse(_effectiveDateController.text.trim()) ??
        DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    _effectiveDateController.text = picked.toIso8601String().split('T').first;
  }

  double _valueForFuel(PumpReadings readings, String fuelKey) {
    switch (fuelKey) {
      case 'petrol':
        return readings.petrol;
      case 'diesel':
        return readings.diesel;
      default:
        return 0;
    }
  }

  Future<void> _reload() async {
    setState(() {
      _seeded = false;
      _future = _load(forceRefresh: true);
    });
    await _future;
  }

  Future<bool> _save(StationConfigModel station) async {
    final effectiveDate = _effectiveDateController.text.trim();
    if (effectiveDate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFB91C1C),
          content: Text('Select an effective date.'),
        ),
      );
      return false;
    }

    final readings = <String, PumpReadings>{};
    for (final pump in station.pumps) {
      final petrol = double.tryParse(
        _controllers[_readingKey(pump.id, 'petrol')]?.text ?? '',
      );
      final diesel = double.tryParse(
        _controllers[_readingKey(pump.id, 'diesel')]?.text ?? '',
      );
      if (petrol == null || petrol < 0 || diesel == null || diesel < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFFB91C1C),
            content: Text('Enter valid non-negative opening readings.'),
          ),
        );
        return false;
      }
      readings[pump.id] = PumpReadings(petrol: petrol, diesel: diesel, twoT: 0);
    }

    setState(() => _saving = true);
    try {
      await _inventoryService.createOpeningReadingLog(
        effectiveDate: effectiveDate,
        readings: readings,
        note: _noteController.text.trim(),
      );
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pump opening readings saved.')),
      );
      setState(() {
        _seeded = false;
        _future = _load(forceRefresh: true);
      });
      return true;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFB91C1C),
          content: Text(userFacingErrorMessage(error)),
        ),
      );
      return false;
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _openUpdateDialog(StationConfigModel station) async {
    _seeded = false;
    _seedControllers(station);
    var saving = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Update Opening Readings'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: saving ? null : _pickEffectiveDate,
                      child: AbsorbPointer(
                        child: TextField(
                          controller: _effectiveDateController,
                          enabled: widget.canEdit && !saving,
                          decoration: InputDecoration(
                            labelText: 'Effective date',
                            suffixIcon: const Icon(Icons.calendar_today),
                            filled: true,
                            fillColor: kClayBg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _noteController,
                      enabled: widget.canEdit && !saving,
                      minLines: 2,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Reason / note (optional)',
                        filled: true,
                        fillColor: kClayBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...station.pumps.map((pump) {
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
                            _NumericField(
                              controller:
                                  _controllers[_readingKey(pump.id, 'petrol')],
                              label: 'Petrol opening reading',
                              enabled: widget.canEdit && !saving,
                            ),
                            const SizedBox(height: 12),
                            _NumericField(
                              controller:
                                  _controllers[_readingKey(pump.id, 'diesel')],
                              label: 'Diesel opening reading',
                              enabled: widget.canEdit && !saving,
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          setDialogState(() => saving = true);
                          final saved = await _save(station);
                          if (!context.mounted) return;
                          setDialogState(() => saving = false);
                          if (saved && dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        },
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(saving ? 'Saving...' : 'Save Opening Readings'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openHistoryPage() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _OpeningReadingHistoryScreen(canEdit: widget.canEdit),
      ),
    );
    if (mounted) await _reload();
  }

  String _displayTimestamp(String raw) {
    final value = DateTime.tryParse(raw);
    if (value == null) {
      return raw.trim().isEmpty ? 'Unknown time' : raw;
    }
    final local = value.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour24 = local.hour;
    final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = hour24 >= 12 ? 'PM' : 'AM';
    return '${months[local.month - 1]} ${local.day}, ${local.year} $hour12:$minute $suffix';
  }

  Widget _buildContent() {
    return FutureBuilder<_OpeningReadingsData>(
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
            child: Center(child: Text(userFacingErrorMessage(snapshot.error))),
          );
        }

        final data = snapshot.data!;
        final station = data.station;
        final activeHistory = data.logs.reversed.toList(growable: false);
        final activeLog = activeHistory.isEmpty ? null : activeHistory.first;
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
                  ),
                // ── Per-pump cards ─────────────────────────────────
                ClayCard(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Active Opening Reading',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: kClayPrimary,
                              ),
                            ),
                          ),
                          if (widget.canEdit)
                            FilledButton(
                              onPressed: _saving
                                  ? null
                                  : () => _openUpdateDialog(station),
                              child: const Text('Update Opening Readings'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        activeLog == null
                            ? 'No opening reading log found yet.'
                            : 'Effective ${formatDateLabel(activeLog.effectiveDate)}',
                        style: const TextStyle(color: kClaySub, height: 1.4),
                      ),
                      if (activeLog != null) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _InfoChip(
                              label: 'Changed at',
                              value: _displayTimestamp(activeLog.createdAt),
                            ),
                            _InfoChip(
                              label: 'Changed by',
                              value: activeLog.createdByName.trim().isEmpty
                                  ? 'System'
                                  : activeLog.createdByName,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...station.pumps.map((pump) {
                          final readings = activeLog.readings[pump.id];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  formatPumpLabel(pump.id, pump.label),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: kClayPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _InfoChip(
                                      label: 'Petrol',
                                      value: (readings?.petrol ?? 0)
                                          .toStringAsFixed(2),
                                    ),
                                    _InfoChip(
                                      label: 'Diesel',
                                      value: (readings?.diesel ?? 0)
                                          .toStringAsFixed(2),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                        if (activeLog.note.trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            activeLog.note,
                            style: const TextStyle(
                              color: kClayPrimary,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),

                ClayCard(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Latest Opening Reading Log',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: kClayPrimary,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _openHistoryPage,
                            icon: const Icon(Icons.history_rounded),
                            label: const Text('View All'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Showing the newest opening reading log here. Open all history for filters, sorting, downloads, and deleted records.',
                        style: TextStyle(color: kClaySub, height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      if (activeLog == null)
                        Text(
                          'No opening reading logs yet.',
                          style: TextStyle(color: kClaySub),
                        )
                      else
                        _OpeningReadingLogRow(
                          log: activeLog,
                          pumps: station.pumps,
                          displayTimestamp: _displayTimestamp,
                        ),
                    ],
                  ),
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
      ),
      body: content,
    );
  }
}

// ─── Edit toggle pill ────────────────────────────────────────────────────────
enum _OpeningHistorySort {
  savedNewest,
  savedOldest,
  effectiveNewest,
  effectiveOldest,
}

class _OpeningHistoryData {
  const _OpeningHistoryData({
    required this.station,
    required this.active,
    required this.deleted,
  });

  final StationConfigModel station;
  final List<PumpOpeningReadingLogModel> active;
  final List<PumpOpeningReadingLogModel> deleted;
}

class _OpeningReadingHistoryScreen extends StatefulWidget {
  const _OpeningReadingHistoryScreen({required this.canEdit});

  final bool canEdit;

  @override
  State<_OpeningReadingHistoryScreen> createState() =>
      _OpeningReadingHistoryScreenState();
}

class _OpeningReadingHistoryScreenState
    extends State<_OpeningReadingHistoryScreen> {
  final InventoryService _inventoryService = InventoryService();
  final ReportExportService _reportExportService = ReportExportService();
  late Future<_OpeningHistoryData> _future;
  bool _showDeleted = false;
  bool _deleting = false;
  String _fromDate = '';
  String _toDate = '';
  _OpeningHistorySort _sort = _OpeningHistorySort.savedNewest;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_OpeningHistoryData> _load({bool forceRefresh = false}) async {
    final results = await Future.wait<dynamic>([
      _inventoryService.fetchStationConfig(forceRefresh: forceRefresh),
      _inventoryService.fetchOpeningReadingLogs(
        fromDate: _fromDate,
        toDate: _toDate,
        forceRefresh: forceRefresh,
      ),
      _inventoryService.fetchOpeningReadingLogs(
        fromDate: _fromDate,
        toDate: _toDate,
        deletedOnly: true,
        forceRefresh: forceRefresh,
      ),
    ]);
    return _OpeningHistoryData(
      station: results[0] as StationConfigModel,
      active: results[1] as List<PumpOpeningReadingLogModel>,
      deleted: results[2] as List<PumpOpeningReadingLogModel>,
    );
  }

  Future<void> _reload({bool forceRefresh = true}) async {
    setState(() => _future = _load(forceRefresh: forceRefresh));
    await _future;
  }

  List<PumpOpeningReadingLogModel> _sorted(
    List<PumpOpeningReadingLogModel> items,
  ) {
    final sorted = [...items];
    sorted.sort((left, right) {
      switch (_sort) {
        case _OpeningHistorySort.savedNewest:
          return right.createdAt.compareTo(left.createdAt);
        case _OpeningHistorySort.savedOldest:
          return left.createdAt.compareTo(right.createdAt);
        case _OpeningHistorySort.effectiveNewest:
          return right.effectiveDate.compareTo(left.effectiveDate);
        case _OpeningHistorySort.effectiveOldest:
          return left.effectiveDate.compareTo(right.effectiveDate);
      }
    });
    return sorted;
  }

  String _sortLabel(_OpeningHistorySort sort) {
    switch (sort) {
      case _OpeningHistorySort.savedNewest:
        return 'Saved newest';
      case _OpeningHistorySort.savedOldest:
        return 'Saved oldest';
      case _OpeningHistorySort.effectiveNewest:
        return 'Effective newest';
      case _OpeningHistorySort.effectiveOldest:
        return 'Effective oldest';
    }
  }

  Future<void> _pickDate({required bool from}) async {
    final current = DateTime.tryParse(from ? _fromDate : _toDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    final value = picked.toIso8601String().split('T').first;
    setState(() {
      if (from) {
        _fromDate = value;
      } else {
        _toDate = value;
      }
      _future = _load(forceRefresh: true);
    });
  }

  void _clearFilters() {
    setState(() {
      _fromDate = '';
      _toDate = '';
      _future = _load(forceRefresh: true);
    });
  }

  String _displayTimestamp(String raw) {
    final value = DateTime.tryParse(raw);
    if (value == null) {
      return raw.trim().isEmpty ? 'Unknown time' : raw;
    }
    final local = value.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour24 = local.hour;
    final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = hour24 >= 12 ? 'PM' : 'AM';
    return '${months[local.month - 1]} ${local.day}, ${local.year} $hour12:$minute $suffix';
  }

  Future<void> _downloadHistory(
    List<PumpOpeningReadingLogModel> history,
    List<StationPumpModel> pumps, {
    required bool deleted,
  }) async {
    final rows = <List<dynamic>>[];
    for (final log in history) {
      for (final pump in pumps) {
        final readings = log.readings[pump.id];
        rows.add([
          log.effectiveDate,
          formatPumpLabel(pump.id, pump.label),
          (readings?.petrol ?? 0).toStringAsFixed(2),
          (readings?.diesel ?? 0).toStringAsFixed(2),
          log.createdAt,
          log.createdByName,
          log.deletedAt,
          log.deletedByName,
          log.note,
        ]);
      }
    }
    try {
      final path = await _reportExportService.saveRowsToDownloads(
        title: deleted
            ? 'deleted_pump_opening_readings'
            : 'pump_opening_readings',
        notificationTitle: 'Opening reading history downloaded',
        headers: [
          'Effective Date',
          'Pump',
          'Petrol',
          'Diesel',
          'Saved At',
          'Saved By',
          'Deleted At',
          'Deleted By',
          'Note',
        ],
        rows: rows,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Opening reading history downloaded to $path')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFB91C1C),
          content: Text(userFacingErrorMessage(error)),
        ),
      );
    }
  }

  Future<void> _deleteHistory(PumpOpeningReadingLogModel log) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete opening reading history?'),
        content: const Text(
          'This log will move to Deleted History for 30 days and then be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _deleting = true);
    try {
      await _inventoryService.deleteOpeningReadingLog(log.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Opening reading history deleted.')),
      );
      await _reload(forceRefresh: true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFB91C1C),
          content: Text(userFacingErrorMessage(error)),
        ),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Widget _filterButton({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onTap,
        child: OneLineScaleText(
          value.isEmpty ? label : '$label: ${formatDateLabel(value)}',
          alignment: Alignment.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kClayBg,
      appBar: AppBar(
        backgroundColor: kClayBg,
        title: const Text('Opening Reading History'),
      ),
      body: FutureBuilder<_OpeningHistoryData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(userFacingErrorMessage(snapshot.error)));
          }
          final data = snapshot.data!;
          final source = _showDeleted ? data.deleted : data.active;
          final history = _sorted(source);
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                ClayCard(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _HistoryTabButton(
                            label: 'Active',
                            count: data.active.length,
                            selected: !_showDeleted,
                            onTap: () => setState(() => _showDeleted = false),
                          ),
                          const SizedBox(width: 8),
                          _HistoryTabButton(
                            label: 'Deleted',
                            count: data.deleted.length,
                            selected: _showDeleted,
                            onTap: () => setState(() => _showDeleted = true),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Download history',
                            onPressed: history.isEmpty
                                ? null
                                : () => _downloadHistory(
                                    history,
                                    data.station.pumps,
                                    deleted: _showDeleted,
                                  ),
                            icon: const Icon(Icons.download_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _filterButton(
                            label: 'From',
                            value: _fromDate,
                            onTap: () => _pickDate(from: true),
                          ),
                          const SizedBox(width: 8),
                          _filterButton(
                            label: 'To',
                            value: _toDate,
                            onTap: () => _pickDate(from: false),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<_OpeningHistorySort>(
                        initialValue: _sort,
                        decoration: InputDecoration(
                          labelText: 'Sort by',
                          filled: true,
                          fillColor: kClayBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: _OpeningHistorySort.values
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(_sortLabel(item)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _sort = value);
                        },
                      ),
                      if (_fromDate.isNotEmpty || _toDate.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: _clearFilters,
                          icon: const Icon(Icons.filter_alt_off_rounded),
                          label: const Text('Clear filters'),
                        ),
                      ],
                    ],
                  ),
                ),
                if (history.isEmpty)
                  const ClayCard(
                    margin: EdgeInsets.only(bottom: 14),
                    child: Text(
                      'No opening reading history for this filter.',
                      style: TextStyle(color: kClaySub),
                    ),
                  )
                else
                  ...history.map(
                    (item) => _OpeningReadingLogRow(
                      log: item,
                      pumps: data.station.pumps,
                      displayTimestamp: _displayTimestamp,
                      onDelete: widget.canEdit && !_showDeleted && !_deleting
                          ? () => _deleteHistory(item)
                          : null,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OpeningReadingLogRow extends StatelessWidget {
  const _OpeningReadingLogRow({
    required this.log,
    required this.pumps,
    required this.displayTimestamp,
    this.onDelete,
  });

  final PumpOpeningReadingLogModel log;
  final List<StationPumpModel> pumps;
  final String Function(String) displayTimestamp;
  final VoidCallback? onDelete;

  String _value(PumpReadings? readings, String fuelKey) {
    switch (fuelKey) {
      case 'petrol':
        return (readings?.petrol ?? 0).toStringAsFixed(2);
      case 'diesel':
        return (readings?.diesel ?? 0).toStringAsFixed(2);
      default:
        return '0.00';
    }
  }

  @override
  Widget build(BuildContext context) {
    final actor = log.createdByName.trim().isEmpty
        ? 'System'
        : log.createdByName;
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
          Row(
            children: [
              Expanded(
                child: Text(
                  formatDateLabel(log.effectiveDate),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: kClayPrimary,
                  ),
                ),
              ),
              Text(
                displayTimestamp(log.createdAt),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: kClaySub,
                ),
              ),
              if (onDelete != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Delete history',
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFB91C1C),
                    size: 20,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Saved by $actor',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: kClayPrimary,
            ),
          ),
          if (log.deletedAt.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Deleted by ${log.deletedByName.trim().isEmpty ? 'Unknown' : log.deletedByName} on ${displayTimestamp(log.deletedAt)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFFB91C1C),
              ),
            ),
          ],
          const SizedBox(height: 10),
          ...pumps.map((pump) {
            final readings = log.readings[pump.id];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatPumpLabel(pump.id, pump.label),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: kClayPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoChip(
                        label: 'Petrol',
                        value: _value(readings, 'petrol'),
                      ),
                      _InfoChip(
                        label: 'Diesel',
                        value: _value(readings, 'diesel'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          if (log.note.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              log.note,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: Color(0xFF5B6487),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryTabButton extends StatelessWidget {
  const _HistoryTabButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? kClayPrimary : Colors.white,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            color: selected ? Colors.white : kClayPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: kClaySub,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: kClayPrimary,
            ),
          ),
        ],
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
