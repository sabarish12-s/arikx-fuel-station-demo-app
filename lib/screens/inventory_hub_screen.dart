import 'dart:async';

import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/api_response_cache.dart';
import '../services/inventory_service.dart';
import '../services/management_service.dart';
import '../services/report_export_service.dart';
import '../utils/formatters.dart';
import '../utils/user_facing_errors.dart';
import '../widgets/clay_widgets.dart';
import '../widgets/responsive_text.dart';
import 'delivery_history_screen.dart';
import 'delivery_receipt_screen.dart';

class InventoryHubScreen extends StatefulWidget {
  const InventoryHubScreen({
    super.key,
    this.canManagePlanning = false,
    this.showStockManagement = true,
    this.stockManagementOnly = false,
    this.embedded = false,
    this.onBack,
  });

  static void resetToHome(GlobalKey key) {
    final state = key.currentState;
    if (state is _InventoryHubScreenState) {
      state._resetInlinePage();
    }
  }

  final bool canManagePlanning;
  final bool showStockManagement;
  final bool stockManagementOnly;
  final bool embedded;
  final VoidCallback? onBack;

  @override
  State<InventoryHubScreen> createState() => _InventoryHubScreenState();
}

class _InventoryHubData {
  const _InventoryHubData({
    required this.dashboard,
    required this.snapshots,
    required this.daySetups,
  });

  final InventoryDashboardModel dashboard;
  final List<InventoryStockSnapshotModel> snapshots;
  final List<StationDaySetupModel> daySetups;
}

String _visibleStockNote(String note) {
  final trimmed = note.trim();
  if (trimmed.toLowerCase() == 'migrated stock baseline') {
    return '';
  }
  return trimmed;
}

class _InventoryHubScreenState extends State<InventoryHubScreen> {
  final InventoryService _inventoryService = InventoryService();
  final TextEditingController _effectiveDateController =
      TextEditingController();
  final TextEditingController _petrolController = TextEditingController();
  final TextEditingController _dieselController = TextEditingController();
  final TextEditingController _twoTController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  late Future<_InventoryHubData> _future;
  late final StreamSubscription<ApiResponseCacheUpdate> _cacheSubscription;
  bool _snapshotSeeded = false;
  bool _savingSnapshot = false;
  List<StationDaySetupModel>? _openingHistorySetups;

  void _resetInlinePage() {
    if (_openingHistorySetups == null) return;
    setState(() => _openingHistorySetups = null);
  }

  @override
  void initState() {
    super.initState();
    _future = _load();
    _cacheSubscription = ApiResponseCache.updates.listen((update) {
      if (!mounted ||
          !update.background ||
          !update.path.startsWith('/inventory/')) {
        return;
      }
      setState(() {
        _future = _load();
      });
    });
  }

  @override
  void dispose() {
    _cacheSubscription.cancel();
    _effectiveDateController.dispose();
    _petrolController.dispose();
    _dieselController.dispose();
    _twoTController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<_InventoryHubData> _load({bool forceRefresh = false}) async {
    final results = await Future.wait<dynamic>([
      _inventoryService.fetchInventoryDashboard(forceRefresh: forceRefresh),
      _inventoryService.fetchStockSnapshots(forceRefresh: forceRefresh),
      _inventoryService.fetchDaySetups(forceRefresh: forceRefresh),
    ]);
    return _InventoryHubData(
      dashboard: results[0] as InventoryDashboardModel,
      snapshots: results[1] as List<InventoryStockSnapshotModel>,
      daySetups: results[2] as List<StationDaySetupModel>,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _snapshotSeeded = false;
      _future = _load(forceRefresh: true);
    });
    await _future;
  }

  void _seedSnapshotForm(_InventoryHubData data) {
    if (_snapshotSeeded) return;
    final activeSnapshot = data.dashboard.activeStockSnapshot;
    final stock =
        activeSnapshot?.stock ?? data.dashboard.inventoryPlanning.currentStock;
    _effectiveDateController.text = DateTime.now()
        .toIso8601String()
        .split('T')
        .first;
    _petrolController.text = (stock['petrol'] ?? 0).toStringAsFixed(2);
    _dieselController.text = (stock['diesel'] ?? 0).toStringAsFixed(2);
    _twoTController.text = (stock['two_t_oil'] ?? 0).toStringAsFixed(2);
    _noteController.clear();
    _snapshotSeeded = true;
  }

  Future<void> _openDeliveryReceipt(
    List<FuelInventoryForecastModel> fuels,
  ) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => DeliveryReceiptScreen(fuels: fuels),
      ),
    );
    if (saved == true && mounted) await _refresh();
  }

  Future<void> _openDeliveryHistory() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const DeliveryHistoryScreen()),
    );
    if (mounted) await _refresh();
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

  Future<bool> _saveSnapshot() async {
    final effectiveDate = _effectiveDateController.text.trim();
    final petrol = double.tryParse(_petrolController.text.trim());
    final diesel = double.tryParse(_dieselController.text.trim());
    final twoT = double.tryParse(_twoTController.text.trim());

    if (effectiveDate.isEmpty ||
        petrol == null ||
        petrol < 0 ||
        diesel == null ||
        diesel < 0 ||
        twoT == null ||
        twoT < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFB91C1C),
          content: Text('Enter a valid date and non-negative stock values.'),
        ),
      );
      return false;
    }

    setState(() => _savingSnapshot = true);
    try {
      await _inventoryService.createStockSnapshot(
        effectiveDate: effectiveDate,
        stock: {'petrol': petrol, 'diesel': diesel, 'two_t_oil': twoT},
        note: _noteController.text.trim(),
      );
      if (!mounted) return false;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Stock saved.')));
      setState(() {
        _snapshotSeeded = false;
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
        setState(() => _savingSnapshot = false);
      }
    }
  }

  Future<void> _openStockUpdateDialog(_InventoryHubData data) async {
    _snapshotSeeded = false;
    _seedSnapshotForm(data);
    var saving = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 24,
              ),
              titlePadding: const EdgeInsets.fromLTRB(22, 20, 22, 6),
              contentPadding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
              actionsPadding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text(
                'Update Current Stock',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Set the stock used for inventory calculations.',
                        style: TextStyle(
                          color: kClaySub,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: saving ? null : _pickEffectiveDate,
                        child: AbsorbPointer(
                          child: TextField(
                            controller: _effectiveDateController,
                            decoration: InputDecoration(
                              labelText: 'Effective date',
                              prefixIcon: const Icon(Icons.event_rounded),
                              suffixIcon: const Icon(Icons.calendar_today),
                              filled: true,
                              fillColor: const Color(0xFFECEFF8),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECEFF8),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFDDE2F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.inventory_2_rounded,
                                  color: kClayPrimary,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Stock levels',
                                  style: TextStyle(
                                    color: kClayPrimary,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _StockNumberField(
                                    label: 'Petrol',
                                    controller: _petrolController,
                                    enabled: !saving,
                                    color: const Color(0xFF1298B8),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _StockNumberField(
                                    label: 'Diesel',
                                    controller: _dieselController,
                                    enabled: !saving,
                                    color: const Color(0xFF2AA878),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _StockNumberField(
                              label: '2T Oil',
                              controller: _twoTController,
                              enabled: !saving,
                              color: const Color(0xFF7048A8),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _noteController,
                        enabled: !saving,
                        minLines: 1,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Reason / note (optional)',
                          prefixIcon: const Icon(Icons.notes_rounded),
                          filled: true,
                          fillColor: const Color(0xFFECEFF8),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: saving
                            ? null
                            : () => Navigator.of(dialogContext).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: saving
                            ? null
                            : () async {
                                setDialogState(() => saving = true);
                                final saved = await _saveSnapshot();
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(saving ? 'Saving...' : 'Save Stock'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _displayDate(String raw) =>
      raw.trim().isEmpty ? 'Not available' : formatDateLabel(raw);

  String _dateKey(DateTime date) => date.toIso8601String().split('T').first;

  List<StationDaySetupModel> _activeDaySetups(
    List<StationDaySetupModel> setups,
  ) {
    final todayKey = _dateKey(DateTime.now());
    final items = setups
        .where(
          (setup) =>
              !setup.isDeleted && setup.effectiveDate.compareTo(todayKey) <= 0,
        )
        .toList();
    items.sort(
      (left, right) => left.effectiveDate.compareTo(right.effectiveDate),
    );
    return items;
  }

  Future<void> _openStockHistoryPage(_InventoryHubData data) async {
    final setups = _activeDaySetups(data.daySetups);
    if (setups.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No day setup history available yet.')),
      );
      return;
    }
    setState(() => _openingHistorySetups = setups);
  }

  Color _fuelColor(String id) {
    switch (id) {
      case 'petrol':
        return const Color(0xFF1A3A7A);
      case 'diesel':
        return const Color(0xFF2AA878);
      case 'two_t_oil':
        return const Color(0xFFCE5828);
      default:
        return const Color(0xFF7048A8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final openingHistorySetups = _openingHistorySetups;
    final child = openingHistorySetups != null
        ? _InventoryOpeningStockHistoryScreen(
            setups: openingHistorySetups,
            embedded: true,
            onBack: () => setState(() => _openingHistorySetups = null),
          )
        : ColoredBox(
            color: const Color(0xFFECEFF8),
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<_InventoryHubData>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError && !snapshot.hasData) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      children: [Text(userFacingErrorMessage(snapshot.error))],
                    );
                  }

                  final data = snapshot.data!;
                  final dashboard = data.dashboard;
                  final planning = dashboard.inventoryPlanning;
                  final activeSnapshot = dashboard.activeStockSnapshot;
                  final showStockManagement =
                      widget.showStockManagement || widget.stockManagementOnly;
                  if (showStockManagement) _seedSnapshotForm(data);

                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      if (widget.embedded)
                        ClaySubHeader(
                          title: 'Stock Management',
                          onBack: widget.onBack,
                        ),
                      if (!widget.stockManagementOnly) ...[
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1A3A7A), Color(0xFF0D2460)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF0D2460,
                                ).withValues(alpha: 0.45),
                                offset: const Offset(0, 10),
                                blurRadius: 24,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Inventory',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  GestureDetector(
                                    onTap: () => _openStockHistoryPage(data),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.14,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.2,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(
                                            Icons.history_rounded,
                                            color: Colors.white70,
                                            size: 14,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            'Stock History',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                height: 1,
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: dashboard.forecast.map((item) {
                                  final isLast =
                                      item == dashboard.forecast.last;
                                  return Expanded(
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.label,
                                                style: const TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                formatLiters(item.currentStock),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (!isLast)
                                          Container(
                                            width: 1,
                                            height: 32,
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                            ),
                                            color: Colors.white.withValues(
                                              alpha: 0.15,
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _InvActionBtn(
                                icon: Icons.local_shipping_outlined,
                                label: 'Record Purchase',
                                onTap: () =>
                                    _openDeliveryReceipt(dashboard.forecast),
                                filled: true,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _InvActionBtn(
                                icon: Icons.history_rounded,
                                label: 'Purchase Record',
                                onTap: _openDeliveryHistory,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                      ],
                      if (showStockManagement) ...[
                        _ClayCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Stock Details',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF1A2561),
                                      ),
                                    ),
                                  ),
                                  if (widget.canManagePlanning)
                                    FilledButton(
                                      onPressed: _savingSnapshot
                                          ? null
                                          : () => _openStockUpdateDialog(data),
                                      child: const Text('Update Current Stock'),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                activeSnapshot == null
                                    ? 'No manual stock found.'
                                    : 'Current stock used for inventory calculations and reports.',
                                style: const TextStyle(
                                  color: Color(0xFF8A93B8),
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 14),
                              _StockSummaryTable(
                                petrol:
                                    activeSnapshot?.stock['petrol'] ??
                                    planning.currentStock['petrol'] ??
                                    0,
                                diesel:
                                    activeSnapshot?.stock['diesel'] ??
                                    planning.currentStock['diesel'] ??
                                    0,
                                twoT:
                                    activeSnapshot?.stock['two_t_oil'] ??
                                    planning.currentStock['two_t_oil'] ??
                                    0,
                              ),
                              const SizedBox(height: 12),
                              _StockMetaRow(
                                effectiveDate: activeSnapshot == null
                                    ? 'Not set'
                                    : _displayDate(
                                        activeSnapshot.effectiveDate,
                                      ),
                                setBy:
                                    activeSnapshot?.createdByName
                                            .trim()
                                            .isNotEmpty ==
                                        true
                                    ? activeSnapshot!.createdByName
                                    : 'System',
                                leadAlert:
                                    '${planning.deliveryLeadDays}d / ${planning.alertBeforeDays}d',
                              ),
                              if (activeSnapshot != null &&
                                  _visibleStockNote(
                                    activeSnapshot.note,
                                  ).isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECEFF8),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(
                                    _visibleStockNote(activeSnapshot.note),
                                    style: const TextStyle(
                                      color: Color(0xFF4A5598),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      if (!widget.stockManagementOnly) ...[
                        ...dashboard.forecast.map(
                          (item) => _FuelForecastCard(
                            item: item,
                            accentColor: _fuelColor(item.fuelTypeId),
                            displayDate: _displayDate,
                          ),
                        ),
                        _ClayCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Recent Purchase',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF1A2561),
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _openDeliveryHistory,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFECEFF8),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFFB8C0DC,
                                            ).withValues(alpha: 0.5),
                                            offset: const Offset(2, 2),
                                            blurRadius: 5,
                                          ),
                                          const BoxShadow(
                                            color: Colors.white,
                                            offset: Offset(-2, -2),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.history_rounded,
                                            size: 13,
                                            color: Color(0xFF4A5598),
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Purchase Record',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF4A5598),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (dashboard.deliveries.isEmpty)
                                const Text(
                                  'No purchases recorded yet.',
                                  style: TextStyle(
                                    color: Color(0xFF8A93B8),
                                    fontSize: 13,
                                  ),
                                )
                              else
                                DeliveryReceiptSummaryCard(
                                  delivery: dashboard.deliveries.first,
                                  margin: EdgeInsets.zero,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          );

    return PopScope(
      canPop: openingHistorySetups == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || openingHistorySetups == null) {
          return;
        }
        setState(() => _openingHistorySetups = null);
      },
      child: child,
    );
  }
}

enum _StockHistorySort {
  savedNewest,
  savedOldest,
  effectiveNewest,
  effectiveOldest,
}

class _StockHistoryData {
  const _StockHistoryData({required this.active, required this.deleted});

  final List<InventoryStockSnapshotModel> active;
  final List<InventoryStockSnapshotModel> deleted;
}

class _StockHistoryScreen extends StatefulWidget {
  const _StockHistoryScreen({required this.canManagePlanning});

  final bool canManagePlanning;

  @override
  State<_StockHistoryScreen> createState() => _StockHistoryScreenState();
}

class _StockHistoryScreenState extends State<_StockHistoryScreen> {
  final InventoryService _inventoryService = InventoryService();
  final ReportExportService _reportExportService = ReportExportService();
  late Future<_StockHistoryData> _future;
  bool _showDeleted = false;
  bool _deleting = false;
  String _fromDate = '';
  String _toDate = '';
  _StockHistorySort _sort = _StockHistorySort.savedNewest;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_StockHistoryData> _load({bool forceRefresh = false}) async {
    final results = await Future.wait<dynamic>([
      _inventoryService.fetchStockSnapshots(
        fromDate: _fromDate,
        toDate: _toDate,
        forceRefresh: forceRefresh,
      ),
      if (widget.canManagePlanning)
        _inventoryService.fetchStockSnapshots(
          fromDate: _fromDate,
          toDate: _toDate,
          deletedOnly: true,
          forceRefresh: forceRefresh,
        ),
    ]);
    return _StockHistoryData(
      active: results[0] as List<InventoryStockSnapshotModel>,
      deleted: widget.canManagePlanning
          ? results[1] as List<InventoryStockSnapshotModel>
          : const <InventoryStockSnapshotModel>[],
    );
  }

  Future<void> _reload({bool forceRefresh = true}) async {
    setState(() {
      _future = _load(forceRefresh: forceRefresh);
    });
    await _future;
  }

  List<InventoryStockSnapshotModel> _sorted(
    List<InventoryStockSnapshotModel> items,
  ) {
    final sorted = [...items];
    int compareText(String left, String right) => left.compareTo(right);
    sorted.sort((left, right) {
      switch (_sort) {
        case _StockHistorySort.savedNewest:
          return compareText(right.createdAt, left.createdAt);
        case _StockHistorySort.savedOldest:
          return compareText(left.createdAt, right.createdAt);
        case _StockHistorySort.effectiveNewest:
          return compareText(right.effectiveDate, left.effectiveDate);
        case _StockHistorySort.effectiveOldest:
          return compareText(left.effectiveDate, right.effectiveDate);
      }
    });
    return sorted;
  }

  String _sortLabel(_StockHistorySort sort) {
    switch (sort) {
      case _StockHistorySort.savedNewest:
        return 'Saved newest';
      case _StockHistorySort.savedOldest:
        return 'Saved oldest';
      case _StockHistorySort.effectiveNewest:
        return 'Effective newest';
      case _StockHistorySort.effectiveOldest:
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

  String _displayDate(String raw) =>
      raw.trim().isEmpty ? 'Not available' : formatDateLabel(raw);

  String _displayTimestamp(String raw) {
    final trimmed = raw.trim();
    return trimmed.isEmpty ? 'Unknown time' : formatDateTimeLabel(trimmed);
  }

  Future<void> _download(
    List<InventoryStockSnapshotModel> history, {
    required bool deleted,
  }) async {
    try {
      final path = await _reportExportService.saveRowsToDownloads(
        title: deleted ? 'deleted_stock_history' : 'stock_history',
        notificationTitle: 'Stock history downloaded',
        headers: [
          'Effective Date',
          'Petrol',
          'Diesel',
          '2T Oil',
          'Saved At',
          'Saved By',
          'Deleted At',
          'Deleted By',
          'Note',
        ],
        rows: history
            .map(
              (item) => [
                item.effectiveDate,
                (item.stock['petrol'] ?? 0).toStringAsFixed(2),
                (item.stock['diesel'] ?? 0).toStringAsFixed(2),
                (item.stock['two_t_oil'] ?? 0).toStringAsFixed(2),
                item.createdAt,
                item.createdByName,
                item.deletedAt,
                item.deletedByName,
                item.note,
              ],
            )
            .toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stock history downloaded to $path')),
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

  Future<void> _deleteStockHistory(InventoryStockSnapshotModel snapshot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete stock history?'),
        content: const Text(
          'This record will move to Deleted History for 30 days and then be permanently removed.',
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
      await _inventoryService.deleteStockSnapshot(snapshot.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Stock history deleted.')));
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFFECEFF8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFDDE2F0)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.event_rounded,
                size: 18,
                color: Color(0xFF1A2561),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF8A93B8),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    OneLineScaleText(
                      value.isEmpty ? 'Any date' : formatDateLabel(value),
                      style: const TextStyle(
                        color: Color(0xFF1A2561),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECEFF8),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFECEFF8),
        title: const Text('Stock History'),
      ),
      body: FutureBuilder<_StockHistoryData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError && !snapshot.hasData) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Center(child: Text(userFacingErrorMessage(snapshot.error))),
              ],
            );
          }
          final data = snapshot.data!;
          final showDeletedTab = widget.canManagePlanning;
          if (!showDeletedTab && _showDeleted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() => _showDeleted = false);
              }
            });
          }
          final source = showDeletedTab && _showDeleted
              ? data.deleted
              : data.active;
          final history = _sorted(source);
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _ClayCard(
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
                                  _showDeleted
                                      ? 'Deleted Stock Records'
                                      : 'Active Stock Records',
                                  style: const TextStyle(
                                    color: Color(0xFF1A2561),
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${history.length} record${history.length == 1 ? '' : 's'} shown',
                                  style: const TextStyle(
                                    color: Color(0xFF8A93B8),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton.filledTonal(
                            tooltip: 'Download history',
                            onPressed: history.isEmpty
                                ? null
                                : () =>
                                      _download(history, deleted: _showDeleted),
                            icon: const Icon(Icons.download_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _HistoryTabButton(
                            label: 'Active',
                            count: data.active.length,
                            selected: !_showDeleted,
                            onTap: () => setState(() => _showDeleted = false),
                          ),
                          if (showDeletedTab)
                            _HistoryTabButton(
                              label: 'Deleted',
                              count: data.deleted.length,
                              selected: _showDeleted,
                              onTap: () => setState(() => _showDeleted = true),
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
                      ClayDropdownField<_StockHistorySort>(
                        label: 'Sort by',
                        value: _sort,
                        compact: true,
                        items: _StockHistorySort.values
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
                        TextButton(
                          onPressed: _clearFilters,
                          child: const Text('Clear filter'),
                        ),
                      ],
                      if (_showDeleted) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'Deleted records are kept here for 30 days before permanent removal.',
                          style: TextStyle(
                            color: Color(0xFF8A93B8),
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (history.isEmpty)
                  _ClayCard(
                    child: Text(
                      _showDeleted
                          ? 'No deleted stock records for this filter.'
                          : 'No stock records for this filter.',
                      style: const TextStyle(
                        color: Color(0xFF8A93B8),
                        fontSize: 13,
                      ),
                    ),
                  )
                else
                  ...history.map(
                    (item) => _SnapshotHistoryRow(
                      snapshot: item,
                      displayDate: _displayDate,
                      displayTimestamp: _displayTimestamp,
                      onDelete:
                          widget.canManagePlanning &&
                              !_showDeleted &&
                              !_deleting
                          ? () => _deleteStockHistory(item)
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

class _FuelForecastCard extends StatelessWidget {
  const _FuelForecastCard({
    required this.item,
    required this.accentColor,
    required this.displayDate,
  });

  final FuelInventoryForecastModel item;
  final Color accentColor;
  final String Function(String) displayDate;

  String _daysLabel(double? value) {
    if (value == null) return 'Not enough data';
    return '${value.toStringAsFixed(1)} day(s)';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB8C0DC).withValues(alpha: 0.75),
            offset: const Offset(6, 6),
            blurRadius: 16,
          ),
          const BoxShadow(
            color: Colors.white,
            offset: Offset(-5, -5),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(right: 8, top: 1),
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A2561),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFECEFF8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _MetricCell(
                      label: 'Current stock',
                      value: formatLiters(item.currentStock),
                    ),
                    const _MDivider(),
                    _MetricCell(
                      label: '7 day avg sales',
                      value: formatLiters(item.averageDailySales),
                    ),
                  ],
                ),
                const _MRowDivider(),
                Row(
                  children: [
                    _MetricCell(
                      label: 'Days remaining',
                      value: _daysLabel(item.daysRemaining),
                    ),
                    const _MDivider(),
                    _MetricCell(
                      label: 'Projected runout',
                      value: displayDate(item.projectedRunoutDate),
                    ),
                  ],
                ),
                const _MRowDivider(),
                _MetricCell(
                  label: 'Recommended order by',
                  value: displayDate(item.recommendedOrderDate),
                  full: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SnapshotHistoryRow extends StatelessWidget {
  const _SnapshotHistoryRow({
    required this.snapshot,
    required this.displayDate,
    required this.displayTimestamp,
    this.onDelete,
  });

  final InventoryStockSnapshotModel snapshot;
  final String Function(String) displayDate;
  final String Function(String) displayTimestamp;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final actor = snapshot.createdByName.trim().isEmpty
        ? 'System'
        : snapshot.createdByName;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E7F2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A2561).withValues(alpha: 0.06),
            offset: const Offset(0, 8),
            blurRadius: 18,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  displayDate(snapshot.effectiveDate),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A2561),
                  ),
                ),
              ),
              Text(
                displayTimestamp(snapshot.createdAt),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8A93B8),
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
          const SizedBox(height: 10),
          _StockSummaryTable(
            petrol: snapshot.stock['petrol'] ?? 0,
            diesel: snapshot.stock['diesel'] ?? 0,
            twoT: snapshot.stock['two_t_oil'] ?? 0,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFECEFF8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _StockMetaCell(label: 'Saved by', value: actor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StockMetaCell(
                    label: 'Logged at',
                    value: displayTimestamp(snapshot.createdAt),
                  ),
                ),
              ],
            ),
          ),
          if (snapshot.deletedAt.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Deleted by ${snapshot.deletedByName.trim().isEmpty ? 'Unknown' : snapshot.deletedByName} on ${displayTimestamp(snapshot.deletedAt)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFFB91C1C),
              ),
            ),
          ],
          if (_visibleStockNote(snapshot.note).isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _visibleStockNote(snapshot.note),
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
          color: selected ? const Color(0xFF1A3A7A) : const Color(0xFFECEFF8),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF4A5598),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _StockNumberField extends StatelessWidget {
  const _StockNumberField({
    required this.label,
    required this.controller,
    required this.enabled,
    required this.color,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 12, right: 8),
          child: Icon(Icons.circle, color: color, size: 12),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 32),
        suffixText: 'L',
        suffixStyle: const TextStyle(
          color: kClaySub,
          fontWeight: FontWeight.w800,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({
    required this.label,
    required this.value,
    this.full = false,
  });

  final String label;
  final String value;
  final bool full;

  @override
  Widget build(BuildContext context) {
    final child = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OneLineScaleText(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF8A93B8),
          ),
        ),
        const SizedBox(height: 3),
        OneLineScaleText(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A2561),
          ),
        ),
      ],
    );
    return full
        ? SizedBox(width: double.infinity, child: child)
        : Expanded(child: child);
  }
}

class _MDivider extends StatelessWidget {
  const _MDivider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 32,
    margin: const EdgeInsets.symmetric(horizontal: 12),
    color: const Color(0xFFD8DCF0),
  );
}

class _MRowDivider extends StatelessWidget {
  const _MRowDivider();

  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    margin: const EdgeInsets.symmetric(vertical: 10),
    color: const Color(0xFFD8DCF0),
  );
}

class _InventoryOpeningStockHistoryScreen extends StatefulWidget {
  const _InventoryOpeningStockHistoryScreen({
    required this.setups,
    this.embedded = false,
    this.onBack,
  });

  final List<StationDaySetupModel> setups;
  final bool embedded;
  final VoidCallback? onBack;

  @override
  State<_InventoryOpeningStockHistoryScreen> createState() =>
      _InventoryOpeningStockHistoryScreenState();
}

class _InventoryOpeningStockHistoryData {
  const _InventoryOpeningStockHistoryData({
    required this.entries,
    required this.deliveries,
  });

  final List<ShiftEntryModel> entries;
  final List<DeliveryReceiptModel> deliveries;
}

class _InventoryOpeningStockHistoryScreenState
    extends State<_InventoryOpeningStockHistoryScreen> {
  final InventoryService _inventoryService = InventoryService();
  final ManagementService _managementService = ManagementService();
  late DateTime _selectedDate;
  late Future<_InventoryOpeningStockHistoryData> _future;

  @override
  void initState() {
    super.initState();
    _selectedDate = _parseDate(widget.setups.last.effectiveDate);
    _future = _load();
  }

  DateTime _parseDate(String value) =>
      DateTime.tryParse(value) ?? DateTime.now();

  String _dateKey(DateTime date) => date.toIso8601String().split('T').first;

  double _round2(double value) => double.parse(value.toStringAsFixed(2));

  Future<_InventoryOpeningStockHistoryData> _load() async {
    final firstSetupDate = widget.setups.first.effectiveDate;
    final today = _dateKey(DateTime.now());
    final results = await Future.wait<dynamic>([
      _managementService.fetchEntries(
        fromDate: firstSetupDate,
        toDate: today,
        approvedOnly: true,
      ),
      _inventoryService.fetchDeliveries(),
    ]);
    return _InventoryOpeningStockHistoryData(
      entries: results[0] as List<ShiftEntryModel>,
      deliveries: results[1] as List<DeliveryReceiptModel>,
    );
  }

  List<ShiftEntryModel> _normalizeEntries(List<ShiftEntryModel> entries) {
    final latestByDate = <String, ShiftEntryModel>{};
    for (final entry in entries) {
      if (!entry.isFinalized) continue;
      final existing = latestByDate[entry.date];
      if (existing == null ||
          entry.latestActivityTimestamp.compareTo(
                existing.latestActivityTimestamp,
              ) >=
              0) {
        latestByDate[entry.date] = entry;
      }
    }
    final normalized = latestByDate.values.toList()
      ..sort((left, right) => left.date.compareTo(right.date));
    return normalized;
  }

  StationDaySetupModel _setupForDate(DateTime date) {
    final target = _dateKey(date);
    StationDaySetupModel selected = widget.setups.first;
    for (final setup in widget.setups) {
      if (setup.effectiveDate.compareTo(target) <= 0) {
        selected = setup;
      } else {
        break;
      }
    }
    return selected;
  }

  Map<String, double> _openingStockForDate(
    DateTime date,
    _InventoryOpeningStockHistoryData data,
  ) {
    final target = _dateKey(date);
    final baselineSetup = _setupForDate(date);
    final stock = <String, double>{
      'petrol': baselineSetup.startingStock['petrol'] ?? 0,
      'diesel': baselineSetup.startingStock['diesel'] ?? 0,
      'two_t_oil': baselineSetup.startingStock['two_t_oil'] ?? 0,
    };

    for (final delivery in data.deliveries.where(
      (item) =>
          item.date.compareTo(baselineSetup.effectiveDate) >= 0 &&
          item.date.compareTo(target) < 0,
    )) {
      for (final fuelTypeId in ['petrol', 'diesel', 'two_t_oil']) {
        stock[fuelTypeId] = _round2(
          (stock[fuelTypeId] ?? 0) + (delivery.quantities[fuelTypeId] ?? 0),
        );
      }
    }

    for (final entry in _normalizeEntries(data.entries).where(
      (item) =>
          item.date.compareTo(baselineSetup.effectiveDate) >= 0 &&
          item.date.compareTo(target) < 0,
    )) {
      stock['petrol'] = _round2(
        (stock['petrol'] ?? 0) - entry.inventoryTotals.petrol,
      );
      stock['diesel'] = _round2(
        (stock['diesel'] ?? 0) - entry.inventoryTotals.diesel,
      );
      stock['two_t_oil'] = _round2(
        (stock['two_t_oil'] ?? 0) - entry.inventoryTotals.twoT,
      );
    }

    return stock;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: _parseDate(widget.setups.first.effectiveDate),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final selectedDateLabel = formatDateLabel(_dateKey(_selectedDate));

    final body = FutureBuilder<_InventoryOpeningStockHistoryData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError && !snapshot.hasData) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Center(child: Text(userFacingErrorMessage(snapshot.error))),
            ],
          );
        }
        final data = snapshot.data!;
        final stock = _openingStockForDate(_selectedDate, data);
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (widget.embedded)
              ClaySubHeader(title: 'Stock History', onBack: widget.onBack),
            _ClayCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Date',
                    style: TextStyle(
                      color: Color(0xFF1A2561),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Choose any date from the first day setup until today.',
                    style: TextStyle(
                      color: Color(0xFF8A93B8),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _InventoryDatePickerRow(
                    label: 'Date',
                    value: selectedDateLabel,
                    onTap: _pickDate,
                  ),
                ],
              ),
            ),
            _ClayCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Opening Stock',
                    style: TextStyle(
                      color: Color(0xFF1A2561),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _StockSummaryTable(
                    petrol: stock['petrol'] ?? 0,
                    diesel: stock['diesel'] ?? 0,
                    twoT: stock['two_t_oil'] ?? 0,
                    valueHeader: 'Opening stock',
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );

    if (widget.embedded) {
      return ColoredBox(color: const Color(0xFFECEFF8), child: body);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFECEFF8),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFECEFF8),
        surfaceTintColor: const Color(0xFFECEFF8),
        elevation: 0,
        title: const Text('Stock History'),
      ),
      body: body,
    );
  }
}

class _ClayCard extends StatelessWidget {
  const _ClayCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB8C0DC).withValues(alpha: 0.75),
            offset: const Offset(6, 6),
            blurRadius: 16,
          ),
          const BoxShadow(
            color: Colors.white,
            offset: Offset(-5, -5),
            blurRadius: 12,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _InventoryDatePickerRow extends StatelessWidget {
  const _InventoryDatePickerRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFECEFF8),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFB8C0DC).withValues(alpha: 0.5),
              offset: const Offset(3, 3),
              blurRadius: 8,
            ),
            const BoxShadow(
              color: Colors.white,
              offset: Offset(-2, -2),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_rounded,
              size: 16,
              color: Color(0xFF1E5CBA),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8A93B8),
                    ),
                  ),
                  const SizedBox(height: 2),
                  OneLineScaleText(
                    value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A2561),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF8A93B8),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockSummaryTable extends StatelessWidget {
  const _StockSummaryTable({
    required this.petrol,
    required this.diesel,
    required this.twoT,
    this.valueHeader = 'Current stock',
  });

  final double petrol;
  final double diesel;
  final double twoT;
  final String valueHeader;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFECEFF8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE2F0)),
      ),
      child: Column(
        children: [
          _StockTableHeader(valueHeader: valueHeader),
          const SizedBox(height: 8),
          _StockTableRow(label: 'Petrol', value: formatLiters(petrol)),
          const Divider(height: 14, color: Color(0xFFDDE2F0)),
          _StockTableRow(label: 'Diesel', value: formatLiters(diesel)),
          const Divider(height: 14, color: Color(0xFFDDE2F0)),
          _StockTableRow(label: '2T Oil', value: formatLiters(twoT)),
        ],
      ),
    );
  }
}

class _StockTableHeader extends StatelessWidget {
  const _StockTableHeader({this.valueHeader = 'Current stock'});

  final String valueHeader;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: Color(0xFF8A93B8),
      fontSize: 10,
      fontWeight: FontWeight.w800,
    );
    return Row(
      children: [
        const Expanded(child: Text('Fuel', style: style)),
        const SizedBox(width: 12),
        SizedBox(width: 110, child: Text(valueHeader, style: style)),
      ],
    );
  }
}

class _StockTableRow extends StatelessWidget {
  const _StockTableRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OneLineScaleText(
            label,
            style: const TextStyle(
              color: Color(0xFF1A2561),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 110,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE6EAF4)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              child: OneLineScaleText(
                value,
                style: const TextStyle(
                  color: Color(0xFF1A2561),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StockMetaRow extends StatelessWidget {
  const _StockMetaRow({
    required this.effectiveDate,
    required this.setBy,
    required this.leadAlert,
  });

  final String effectiveDate;
  final String setBy;
  final String leadAlert;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFECEFF8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE2F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StockMetaCell(
                  label: 'Effective date',
                  value: effectiveDate,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StockMetaCell(label: 'Set by', value: setBy),
              ),
            ],
          ),
          const Divider(height: 18, color: Color(0xFFDDE2F0)),
          _StockMetaCell(label: 'Lead / alert', value: leadAlert, full: true),
        ],
      ),
    );
  }
}

class _StockMetaCell extends StatelessWidget {
  const _StockMetaCell({
    required this.label,
    required this.value,
    this.full = false,
  });

  final String label;
  final String value;
  final bool full;

  @override
  Widget build(BuildContext context) {
    final child = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF8A93B8),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        OneLineScaleText(
          value,
          style: const TextStyle(
            color: Color(0xFF1A2561),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
    return full ? SizedBox(width: double.infinity, child: child) : child;
  }
}

class _InvActionBtn extends StatefulWidget {
  const _InvActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  State<_InvActionBtn> createState() => _InvActionBtnState();
}

class _InvActionBtnState extends State<_InvActionBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        height: 44,
        decoration: BoxDecoration(
          color: widget.filled ? const Color(0xFF1A3A7A) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: _pressed
              ? []
              : widget.filled
              ? [
                  BoxShadow(
                    color: const Color(0xFF0D2460).withValues(alpha: 0.4),
                    offset: const Offset(0, 6),
                    blurRadius: 14,
                  ),
                ]
              : [
                  BoxShadow(
                    color: const Color(0xFFB8C0DC).withValues(alpha: 0.7),
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.icon,
              size: 15,
              color: widget.filled ? Colors.white : const Color(0xFF1A2561),
            ),
            const SizedBox(width: 6),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: widget.filled ? Colors.white : const Color(0xFF1A2561),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvIconBtn extends StatefulWidget {
  const _InvIconBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_InvIconBtn> createState() => _InvIconBtnState();
}

class _InvIconBtnState extends State<_InvIconBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: _pressed
              ? []
              : [
                  BoxShadow(
                    color: const Color(0xFFB8C0DC).withValues(alpha: 0.7),
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
        child: Icon(widget.icon, size: 18, color: const Color(0xFF4A5598)),
      ),
    );
  }
}
