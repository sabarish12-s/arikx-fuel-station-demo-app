import 'dart:async';

import 'package:flutter/material.dart';

import '../models/auth_models.dart';
import '../models/domain_models.dart';
import '../services/api_response_cache.dart';
import '../services/auth_service.dart';
import '../services/inventory_service.dart';
import '../services/report_export_service.dart';
import '../utils/formatters.dart';
import '../utils/user_facing_errors.dart';
import '../widgets/app_date_range_picker.dart';
import '../widgets/app_bottom_nav_bar.dart';
import '../widgets/app_logo.dart';
import '../widgets/clay_widgets.dart';
import '../widgets/responsive_text.dart';
import 'management_shell.dart';
import 'sales_shell.dart';

class DailyFuelHistoryScreen extends StatefulWidget {
  const DailyFuelHistoryScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<DailyFuelHistoryScreen> createState() => _DailyFuelHistoryScreenState();
}

enum _DailyFuelHistorySort {
  dateNewest,
  dateOldest,
  petrolDensityHigh,
  petrolDensityLow,
  dieselDensityHigh,
  dieselDensityLow,
  updatedNewest,
  updatedOldest,
}

class _DailyFuelHistoryScreenState extends State<DailyFuelHistoryScreen> {
  final AuthService _authService = AuthService();
  final InventoryService _inventoryService = InventoryService();
  final ReportExportService _reportExportService = ReportExportService();
  late Future<List<DailyFuelRecordModel>> _future;
  late final StreamSubscription<ApiResponseCacheUpdate> _cacheSubscription;
  late DateTime _fromDate;
  late DateTime _toDate;
  _DailyFuelHistorySort _sort = _DailyFuelHistorySort.dateNewest;
  AuthUser? _currentUser;
  String _stationTitle = 'Daily Fuel History';
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _toDate = DateTime(today.year, today.month, today.day);
    _fromDate = _toDate.subtract(const Duration(days: 29));
    _future = _loadHistory();
    _loadChromeData();
    _cacheSubscription = ApiResponseCache.updates.listen((update) {
      if (!mounted ||
          !update.background ||
          !update.path.startsWith('/inventory/daily-fuel')) {
        return;
      }
      setState(() => _future = _loadHistory());
    });
  }

  @override
  void dispose() {
    _cacheSubscription.cancel();
    super.dispose();
  }

  Future<void> _loadChromeData() async {
    final user = await _authService.readCurrentUser();
    String title = user?.stationId ?? 'Daily Fuel History';
    try {
      final station = await _inventoryService.fetchStationConfig();
      if (station.name.trim().isNotEmpty) {
        title = station.name.trim();
      }
    } catch (_) {
      // Keep the user station id fallback when station config is unavailable.
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _currentUser = user;
      _stationTitle = title;
    });
  }

  bool get _usesManagementNav {
    final role = _currentUser?.role.trim().toLowerCase();
    return role == 'admin' || role == 'superadmin';
  }

  int get _selectedNavIndex => _usesManagementNav ? 1 : 3;

  List<AppBottomNavItem> get _navItems {
    if (_usesManagementNav) {
      return const [
        AppBottomNavItem(icon: Icons.grid_view_rounded, label: 'Dashboard'),
        AppBottomNavItem(icon: Icons.edit_note_rounded, label: 'Entries'),
        AppBottomNavItem(icon: Icons.bar_chart_rounded, label: 'Reports'),
        AppBottomNavItem(
          icon: Icons.local_gas_station_outlined,
          label: 'Inventory',
        ),
        AppBottomNavItem(
          icon: Icons.manage_accounts_outlined,
          label: 'Settings',
        ),
      ];
    }
    return const [
      AppBottomNavItem(icon: Icons.grid_view_rounded, label: 'Dashboard'),
      AppBottomNavItem(icon: Icons.inventory_2_outlined, label: 'Sales'),
      AppBottomNavItem(
        icon: Icons.local_gas_station_outlined,
        label: 'Inventory',
      ),
      AppBottomNavItem(icon: Icons.local_shipping_outlined, label: 'History'),
      AppBottomNavItem(icon: Icons.person_outline_rounded, label: 'Account'),
    ];
  }

  void _openShellAt(int index) {
    final user = _currentUser;
    if (user == null) {
      Navigator.of(context).maybePop();
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => _usesManagementNav
            ? ManagementShell(user: user, initialIndex: index)
            : SalesShell(user: user, initialIndex: index),
      ),
      (_) => false,
    );
  }

  String _toApiDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<List<DailyFuelRecordModel>> _loadHistory({bool forceRefresh = false}) {
    return _inventoryService.fetchDailyFuelHistory(
      fromDate: _toApiDate(_fromDate),
      toDate: _toApiDate(_toDate),
      forceRefresh: forceRefresh,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _loadHistory(forceRefresh: true));
    await _future;
  }

  Future<void> _pickDateRange() async {
    final selected = await showAppDateRangePicker(
      context: context,
      fromDate: _fromDate,
      toDate: _toDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      helpText: 'Select daily fuel history range',
    );
    if (selected == null) {
      return;
    }
    setState(() {
      _fromDate = selected.start;
      _toDate = selected.end;
      _future = _loadHistory();
    });
  }

  List<DailyFuelRecordModel> _sorted(List<DailyFuelRecordModel> records) {
    final sorted = [...records];
    sorted.sort((left, right) {
      switch (_sort) {
        case _DailyFuelHistorySort.dateNewest:
          return right.date.compareTo(left.date);
        case _DailyFuelHistorySort.dateOldest:
          return left.date.compareTo(right.date);
        case _DailyFuelHistorySort.petrolDensityHigh:
          return (right.density['petrol'] ?? 0).compareTo(
            left.density['petrol'] ?? 0,
          );
        case _DailyFuelHistorySort.petrolDensityLow:
          return (left.density['petrol'] ?? 0).compareTo(
            right.density['petrol'] ?? 0,
          );
        case _DailyFuelHistorySort.dieselDensityHigh:
          return (right.density['diesel'] ?? 0).compareTo(
            left.density['diesel'] ?? 0,
          );
        case _DailyFuelHistorySort.dieselDensityLow:
          return (left.density['diesel'] ?? 0).compareTo(
            right.density['diesel'] ?? 0,
          );
        case _DailyFuelHistorySort.updatedNewest:
          return right.updatedAt.compareTo(left.updatedAt);
        case _DailyFuelHistorySort.updatedOldest:
          return left.updatedAt.compareTo(right.updatedAt);
      }
    });
    return sorted;
  }

  String _sortLabel(_DailyFuelHistorySort sort) {
    switch (sort) {
      case _DailyFuelHistorySort.dateNewest:
        return 'Date - newest';
      case _DailyFuelHistorySort.dateOldest:
        return 'Date - oldest';
      case _DailyFuelHistorySort.petrolDensityHigh:
        return 'Petrol density - high';
      case _DailyFuelHistorySort.petrolDensityLow:
        return 'Petrol density - low';
      case _DailyFuelHistorySort.dieselDensityHigh:
        return 'Diesel density - high';
      case _DailyFuelHistorySort.dieselDensityLow:
        return 'Diesel density - low';
      case _DailyFuelHistorySort.updatedNewest:
        return 'Updated - newest';
      case _DailyFuelHistorySort.updatedOldest:
        return 'Updated - oldest';
    }
  }

  Future<void> _download(List<DailyFuelRecordModel> records) async {
    setState(() => _exporting = true);
    try {
      final path = await _reportExportService.saveRowsToDownloads(
        title:
            'daily_fuel_register_${_toApiDate(_fromDate).replaceAll('-', '')}_${_toApiDate(_toDate).replaceAll('-', '')}',
        headers: const [
          'Date',
          'Source Closing Date',
          'Petrol Opening Stock (L)',
          'Petrol Density (kg/m3)',
          'Petrol Price (Rs/L)',
          'Diesel Opening Stock (L)',
          'Diesel Density (kg/m3)',
          'Diesel Price (Rs/L)',
          'Created By',
          'Created At',
          'Updated By',
          'Updated At',
        ],
        rows: records
            .map(
              (record) => [
                record.date,
                record.sourceClosingDate,
                (record.openingStock['petrol'] ?? 0).toStringAsFixed(2),
                (record.density['petrol'] ?? 0).toStringAsFixed(3),
                (record.price['petrol'] ?? 0).toStringAsFixed(2),
                (record.openingStock['diesel'] ?? 0).toStringAsFixed(2),
                (record.density['diesel'] ?? 0).toStringAsFixed(3),
                (record.price['diesel'] ?? 0).toStringAsFixed(2),
                record.createdByName.isNotEmpty
                    ? record.createdByName
                    : record.createdBy,
                record.createdAt,
                record.updatedByName.isNotEmpty
                    ? record.updatedByName
                    : record.updatedBy,
                record.updatedAt,
              ],
            )
            .toList(),
        notificationTitle: 'Daily fuel history downloaded',
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Daily fuel history downloaded to $path')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingErrorMessage(error))));
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  Future<void> _editRecord(DailyFuelRecordModel record) async {
    final refreshed = await _inventoryService.fetchDailyFuelRecord(
      date: record.date,
    );
    if (!mounted) {
      return;
    }
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => _DailyFuelEditDialog(record: refreshed),
    );
    if (updated != true || !mounted) {
      return;
    }
    await _refresh();
  }

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
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
            'DAILY FUEL HISTORY',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w800,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Fuel Register',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Date filter',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w800,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _pickDateRange,
              icon: const Icon(Icons.event_available_rounded),
              label: Text(
                '${formatDateLabel(_toApiDate(_fromDate))} to ${formatDateLabel(_toApiDate(_toDate))}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: _historyFilterButtonStyle(),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Sort by',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w800,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<_DailyFuelHistorySort>(
                value: _sort,
                isExpanded: true,
                dropdownColor: kClayPrimary,
                borderRadius: BorderRadius.circular(16),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
                iconEnabledColor: Colors.white,
                items: _DailyFuelHistorySort.values
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(_sortLabel(item)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() => _sort = value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<DailyFuelRecordModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const ColoredBox(
              color: kClayBg,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                userFacingErrorMessage(snapshot.error),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: kClayPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }

          final records = _sorted(snapshot.data ?? []);
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _buildHero(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${records.length} record${records.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: kClaySub,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Download history',
                    onPressed: _exporting || records.isEmpty
                        ? null
                        : () => _download(records),
                    icon: _exporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (records.isEmpty)
                const ClayCard(
                  child: Text(
                    'No daily fuel records found for the selected filters.',
                    style: TextStyle(
                      color: kClaySub,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                ...records.map(
                  (record) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _DailyFuelHistoryCard(
                      record: record,
                      onTap: () => _editRecord(record),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _buildBody();
    }
    return Scaffold(
      backgroundColor: kClayBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: kClayBg,
        scrolledUnderElevation: 0,
        elevation: 0,
        title: Row(
          children: [
            const AppLogo(size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: OneLineScaleText(
                _stationTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: kClayPrimary,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: kClayPrimary),
      ),
      bottomNavigationBar: AppBottomNavBar(
        selectedIndex: _selectedNavIndex,
        onSelected: _openShellAt,
        items: _navItems,
      ),
      body: _buildBody(),
    );
  }
}

class _DailyFuelHistoryCard extends StatelessWidget {
  const _DailyFuelHistoryCard({required this.record, required this.onTap});

  final DailyFuelRecordModel record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final updatedBy = record.updatedByName.isNotEmpty
        ? record.updatedByName
        : record.updatedBy;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: ClayCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    formatDateLabel(record.date),
                    style: const TextStyle(
                      color: kClayPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Icon(Icons.edit_rounded, color: kClaySub),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _FuelSummaryTile(
                    title: 'Petrol',
                    accent: const Color(0xFF1E5CBA),
                    openingStock: record.openingStock['petrol'] ?? 0,
                    density: record.density['petrol'] ?? 0,
                    price: record.price['petrol'] ?? 0,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _FuelSummaryTile(
                    title: 'Diesel',
                    accent: const Color(0xFF0F8A73),
                    openingStock: record.openingStock['diesel'] ?? 0,
                    density: record.density['diesel'] ?? 0,
                    price: record.price['diesel'] ?? 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Last updated${updatedBy.isNotEmpty ? ' by $updatedBy' : ''}${record.updatedAt.isNotEmpty ? ' on ${formatDateTimeLabel(record.updatedAt)}' : ''}',
              style: const TextStyle(
                color: kClaySub,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FuelSummaryTile extends StatelessWidget {
  const _FuelSummaryTile({
    required this.title,
    required this.accent,
    required this.openingStock,
    required this.density,
    required this.price,
  });

  final String title;
  final Color accent;
  final double openingStock;
  final double density;
  final double price;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FD),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: accent, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'Opening stock ${formatLiters(openingStock)}',
            style: const TextStyle(
              color: kClayPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Density ${density.toStringAsFixed(2)} kg/m3',
            style: const TextStyle(
              color: kClayPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatPricePerLiter(price),
            style: const TextStyle(
              color: kClaySub,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyFuelEditDialog extends StatefulWidget {
  const _DailyFuelEditDialog({required this.record});

  final DailyFuelRecordModel record;

  @override
  State<_DailyFuelEditDialog> createState() => _DailyFuelEditDialogState();
}

class _DailyFuelEditDialogState extends State<_DailyFuelEditDialog> {
  final InventoryService _inventoryService = InventoryService();
  late final TextEditingController _petrolController;
  late final TextEditingController _dieselController;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _petrolController = TextEditingController(
      text: (widget.record.density['petrol'] ?? 0).toString(),
    );
    _dieselController = TextEditingController(
      text: (widget.record.density['diesel'] ?? 0).toString(),
    );
  }

  @override
  void dispose() {
    _petrolController.dispose();
    _dieselController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final petrol = double.tryParse(_petrolController.text.trim());
    final diesel = double.tryParse(_dieselController.text.trim());
    if (petrol == null || petrol <= 0 || diesel == null || diesel <= 0) {
      setState(() {
        _error = 'Enter petrol and diesel density values greater than zero.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _inventoryService.saveDailyFuelRecord(
        date: widget.record.date,
        density: {'petrol': petrol, 'diesel': diesel},
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = userFacingErrorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClayDialogShell(
      title: 'Edit Daily Fuel Register',
      subtitle: formatDateLabel(widget.record.date),
      icon: Icons.local_gas_station_rounded,
      actions: [
        Expanded(
          child: OutlinedButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving...' : 'Save'),
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FuelSummaryTile(
            title: 'Petrol',
            accent: const Color(0xFF1E5CBA),
            openingStock: widget.record.openingStock['petrol'] ?? 0,
            density: widget.record.density['petrol'] ?? 0,
            price: widget.record.price['petrol'] ?? 0,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _petrolController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Petrol density',
              suffixText: 'kg/m3',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          _FuelSummaryTile(
            title: 'Diesel',
            accent: const Color(0xFF0F8A73),
            openingStock: widget.record.openingStock['diesel'] ?? 0,
            density: widget.record.density['diesel'] ?? 0,
            price: widget.record.price['diesel'] ?? 0,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _dieselController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Diesel density',
              suffixText: 'kg/m3',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFFB42318),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

ButtonStyle _historyFilterButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: Colors.white,
    side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
    backgroundColor: Colors.white.withValues(alpha: 0.08),
    textStyle: const TextStyle(fontWeight: FontWeight.w700),
    padding: const EdgeInsets.symmetric(horizontal: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );
}
