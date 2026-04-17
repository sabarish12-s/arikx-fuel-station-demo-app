import 'dart:async';

import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/api_response_cache.dart';
import '../services/inventory_service.dart';
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
    required this.deletedSnapshots,
  });

  final InventoryDashboardModel dashboard;
  final List<InventoryStockSnapshotModel> snapshots;
  final List<InventoryStockSnapshotModel> deletedSnapshots;
}

class _InventoryHubScreenState extends State<InventoryHubScreen> {
  final InventoryService _inventoryService = InventoryService();
  final ReportExportService _reportExportService = ReportExportService();
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
  bool _showDeletedStockHistory = false;
  bool _deletingStockHistory = false;

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
      setState(() => _future = _load());
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
      _inventoryService.fetchStockSnapshots(
        deletedOnly: true,
        forceRefresh: forceRefresh,
      ),
    ]);
    return _InventoryHubData(
      dashboard: results[0] as InventoryDashboardModel,
      snapshots: results[1] as List<InventoryStockSnapshotModel>,
      deletedSnapshots: results[2] as List<InventoryStockSnapshotModel>,
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

  Future<void> _saveSnapshot() async {
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
      return;
    }

    setState(() => _savingSnapshot = true);
    try {
      await _inventoryService.createStockSnapshot(
        effectiveDate: effectiveDate,
        stock: {'petrol': petrol, 'diesel': diesel, 'two_t_oil': twoT},
        note: _noteController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Stock saved.')));
      setState(() {
        _snapshotSeeded = false;
        _future = _load(forceRefresh: true);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFB91C1C),
          content: Text(userFacingErrorMessage(error)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _savingSnapshot = false);
      }
    }
  }

  Future<void> _downloadStockHistory(
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
    setState(() => _deletingStockHistory = true);
    try {
      await _inventoryService.deleteStockSnapshot(snapshot.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Stock history deleted.')));
      setState(() {
        _snapshotSeeded = false;
        _future = _load(forceRefresh: true);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFB91C1C),
          content: Text(userFacingErrorMessage(error)),
        ),
      );
    } finally {
      if (mounted) setState(() => _deletingStockHistory = false);
    }
  }

  String _displayDate(String raw) =>
      raw.trim().isEmpty ? 'Not available' : formatDateLabel(raw);

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
    return ColoredBox(
      color: const Color(0xFFECEFF8),
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_InventoryHubData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
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
            final activeHistory = data.snapshots.reversed.toList(
              growable: false,
            );
            final deletedHistory = data.deletedSnapshots.reversed.toList(
              growable: false,
            );
            final history = _showDeletedStockHistory
                ? deletedHistory
                : activeHistory;
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
                        Text(
                          dashboard.station.name,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Inventory Stock',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          activeSnapshot == null
                              ? 'No stock available'
                              : 'Stock as of ${_displayDate(activeSnapshot.effectiveDate)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: dashboard.forecast.map((item) {
                            final isLast = item == dashboard.forecast.last;
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
                          onTap: () => _openDeliveryReceipt(dashboard.forecast),
                          filled: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _InvActionBtn(
                          icon: Icons.history_rounded,
                          label: 'Purchase History',
                          onTap: _openDeliveryHistory,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _InvIconBtn(icon: Icons.refresh_rounded, onTap: _refresh),
                    ],
                  ),
                  const SizedBox(height: 18),
                ],
                if (showStockManagement) ...[
                  _ClayCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Active Stock',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A2561),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          activeSnapshot == null
                              ? 'No manual stock found.'
                              : 'Latest applicable manual stock set for inventory calculations and reports.',
                          style: const TextStyle(
                            color: Color(0xFF8A93B8),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _SnapshotPill(
                              label: 'Effective date',
                              value: activeSnapshot == null
                                  ? 'Not set'
                                  : _displayDate(activeSnapshot.effectiveDate),
                            ),
                            const SizedBox(width: 8),
                            _SnapshotPill(
                              label: 'Set by',
                              value:
                                  activeSnapshot?.createdByName
                                          .trim()
                                          .isNotEmpty ==
                                      true
                                  ? activeSnapshot!.createdByName
                                  : 'System',
                            ),
                            const SizedBox(width: 8),
                            _SnapshotPill(
                              label: 'Lead / alert',
                              value:
                                  '${planning.deliveryLeadDays}d / ${planning.alertBeforeDays}d',
                            ),
                          ],
                        ),
                        if (activeSnapshot != null &&
                            activeSnapshot.note.trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECEFF8),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              activeSnapshot.note,
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
                  if (widget.canManagePlanning)
                    _ClayCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Set Manual Stock',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A2561),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Save full dated stock values. The latest save on or before a day becomes the active baseline for that date.',
                            style: TextStyle(
                              color: Color(0xFF8A93B8),
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: _savingSnapshot ? null : _pickEffectiveDate,
                            child: AbsorbPointer(
                              child: TextField(
                                controller: _effectiveDateController,
                                decoration: InputDecoration(
                                  labelText: 'Effective date',
                                  suffixIcon: const Icon(Icons.calendar_today),
                                  filled: true,
                                  fillColor: const Color(0xFFECEFF8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _StockNumberField(
                            label: 'Petrol stock liters',
                            controller: _petrolController,
                            enabled: !_savingSnapshot,
                          ),
                          const SizedBox(height: 12),
                          _StockNumberField(
                            label: 'Diesel stock liters',
                            controller: _dieselController,
                            enabled: !_savingSnapshot,
                          ),
                          const SizedBox(height: 12),
                          _StockNumberField(
                            label: '2T oil stock liters',
                            controller: _twoTController,
                            enabled: !_savingSnapshot,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _noteController,
                            enabled: !_savingSnapshot,
                            minLines: 2,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'Reason / note (optional)',
                              filled: true,
                              fillColor: const Color(0xFFECEFF8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: _savingSnapshot ? null : _saveSnapshot,
                            icon: _savingSnapshot
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(
                              _savingSnapshot ? 'Saving...' : 'Save Stock',
                            ),
                          ),
                        ],
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
                                'Stock History',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1A2561),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Download history',
                              onPressed: history.isEmpty
                                  ? null
                                  : () => _downloadStockHistory(
                                      history,
                                      deleted: _showDeletedStockHistory,
                                    ),
                              icon: const Icon(Icons.download_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Every manual stock save is kept in history. If the same date is saved again, the newest save for that date becomes the active one.',
                          style: TextStyle(
                            color: Color(0xFF8A93B8),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _HistoryTabButton(
                              label: 'Active',
                              count: activeHistory.length,
                              selected: !_showDeletedStockHistory,
                              onTap: () => setState(
                                () => _showDeletedStockHistory = false,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _HistoryTabButton(
                              label: 'Deleted',
                              count: deletedHistory.length,
                              selected: _showDeletedStockHistory,
                              onTap: () => setState(
                                () => _showDeletedStockHistory = true,
                              ),
                            ),
                          ],
                        ),
                        if (_showDeletedStockHistory) ...[
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
                        const SizedBox(height: 14),
                        if (history.isEmpty)
                          Text(
                            _showDeletedStockHistory
                                ? 'No deleted stock records.'
                                : 'No stock records yet.',
                            style: TextStyle(
                              color: Color(0xFF8A93B8),
                              fontSize: 13,
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
                                      !_showDeletedStockHistory &&
                                      !_deletingStockHistory
                                  ? () => _deleteStockHistory(item)
                                  : null,
                            ),
                          ),
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
                                  borderRadius: BorderRadius.circular(999),
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
                                      'History',
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
        color: const Color(0xFFECEFF8),
        borderRadius: BorderRadius.circular(16),
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HistoryChip(
                label: 'Petrol',
                value: formatLiters(snapshot.stock['petrol'] ?? 0),
              ),
              _HistoryChip(
                label: 'Diesel',
                value: formatLiters(snapshot.stock['diesel'] ?? 0),
              ),
              _HistoryChip(
                label: '2T Oil',
                value: formatLiters(snapshot.stock['two_t_oil'] ?? 0),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Saved by $actor',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4A5598),
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
          if (snapshot.note.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              snapshot.note,
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

class _HistoryChip extends StatelessWidget {
  const _HistoryChip({required this.label, required this.value});

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
              color: Color(0xFF8A93B8),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A2561),
            ),
          ),
        ],
      ),
    );
  }
}

class _StockNumberField extends StatelessWidget {
  const _StockNumberField({
    required this.label,
    required this.controller,
    required this.enabled,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFECEFF8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
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

class _SnapshotPill extends StatelessWidget {
  const _SnapshotPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFECEFF8),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFB8C0DC).withValues(alpha: 0.5),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OneLineScaleText(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8A93B8),
              ),
            ),
            const SizedBox(height: 2),
            OneLineScaleText(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A2561),
              ),
            ),
          ],
        ),
      ),
    );
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
