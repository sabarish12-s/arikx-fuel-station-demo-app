import 'dart:async';

import 'package:flutter/material.dart';

import '../models/auth_models.dart';
import '../models/domain_models.dart';
import '../services/api_response_cache.dart';
import '../services/auth_service.dart';
import '../services/inventory_service.dart';
import '../utils/formatters.dart';
import '../utils/user_facing_errors.dart';
import '../widgets/app_bottom_nav_bar.dart';
import '../widgets/app_logo.dart';
import '../widgets/clay_widgets.dart';
import '../widgets/responsive_text.dart';
import 'management_shell.dart';
import 'sales_shell.dart';

class DeliveryHistoryScreen extends StatefulWidget {
  const DeliveryHistoryScreen({super.key});

  @override
  State<DeliveryHistoryScreen> createState() => _DeliveryHistoryScreenState();
}

class _DeliveryHistoryScreenState extends State<DeliveryHistoryScreen> {
  final AuthService _authService = AuthService();
  final InventoryService _inventoryService = InventoryService();
  late Future<List<DeliveryReceiptModel>> _future;
  late final StreamSubscription<ApiResponseCacheUpdate> _cacheSubscription;
  String _fromDate = '';
  String _toDate = '';
  DeliveryFuelFilter _fuelFilter = DeliveryFuelFilter.all;
  _DeliveryHistorySort _sort = _DeliveryHistorySort.purchaseNewest;
  AuthUser? _currentUser;
  String _stationTitle = 'Purchase History';

  @override
  void initState() {
    super.initState();
    _future = _load();
    _loadChromeData();
    _cacheSubscription = ApiResponseCache.updates.listen((update) {
      if (!mounted ||
          !update.background ||
          !update.path.startsWith('/inventory/deliveries')) {
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
    super.dispose();
  }

  Future<void> _loadChromeData() async {
    final user = await _authService.readCurrentUser();
    String title = user?.stationId ?? 'Purchase History';
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

  int get _selectedNavIndex => _usesManagementNav ? 3 : 2;

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

  Future<List<DeliveryReceiptModel>> _load({bool forceRefresh = false}) {
    return _inventoryService.fetchDeliveries(forceRefresh: forceRefresh);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load(forceRefresh: true);
    });
    await _future;
  }

  String _errorText(Object? error) {
    return userFacingErrorMessage(error);
  }

  String _apiDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  int _compareDateValues(String left, String right) {
    final leftDate = DateTime.tryParse(left);
    final rightDate = DateTime.tryParse(right);
    if (leftDate != null && rightDate != null) {
      return leftDate.compareTo(rightDate);
    }
    return left.compareTo(right);
  }

  bool _matchesFuelFilter(DeliveryReceiptModel delivery) {
    if (_fuelFilter == DeliveryFuelFilter.all) {
      return true;
    }

    final petrol = delivery.quantities['petrol'] ?? 0;
    final diesel = delivery.quantities['diesel'] ?? 0;
    final twoT = delivery.quantities['two_t_oil'] ?? 0;
    final activeFuelCount = [
      petrol,
      diesel,
      twoT,
    ].where((quantity) => quantity > 0).length;

    switch (_fuelFilter) {
      case DeliveryFuelFilter.all:
        return true;
      case DeliveryFuelFilter.petrol:
        return petrol > 0;
      case DeliveryFuelFilter.diesel:
        return diesel > 0;
      case DeliveryFuelFilter.twoT:
        return twoT > 0;
      case DeliveryFuelFilter.mixed:
        return activeFuelCount > 1;
    }
  }

  List<DeliveryReceiptModel> _filteredAndSorted(
    List<DeliveryReceiptModel> deliveries,
  ) {
    final filtered = deliveries.where((delivery) {
      if (_fromDate.isNotEmpty && delivery.date.compareTo(_fromDate) < 0) {
        return false;
      }
      if (_toDate.isNotEmpty && delivery.date.compareTo(_toDate) > 0) {
        return false;
      }
      return _matchesFuelFilter(delivery);
    }).toList();

    filtered.sort((left, right) {
      switch (_sort) {
        case _DeliveryHistorySort.purchaseNewest:
          return _compareDateValues(right.date, left.date);
        case _DeliveryHistorySort.purchaseOldest:
          return _compareDateValues(left.date, right.date);
        case _DeliveryHistorySort.quantityHigh:
          return right.quantity.compareTo(left.quantity);
        case _DeliveryHistorySort.quantityLow:
          return left.quantity.compareTo(right.quantity);
      }
    });
    return filtered;
  }

  String _fuelFilterLabel(DeliveryFuelFilter filter) {
    switch (filter) {
      case DeliveryFuelFilter.all:
        return 'All purchases';
      case DeliveryFuelFilter.petrol:
        return 'Petrol';
      case DeliveryFuelFilter.diesel:
        return 'Diesel';
      case DeliveryFuelFilter.twoT:
        return '2T Oil';
      case DeliveryFuelFilter.mixed:
        return 'Mixed';
    }
  }

  String _sortLabel(_DeliveryHistorySort sort) {
    switch (sort) {
      case _DeliveryHistorySort.purchaseNewest:
        return 'Purchase date - newest';
      case _DeliveryHistorySort.purchaseOldest:
        return 'Purchase date - oldest';
      case _DeliveryHistorySort.quantityHigh:
        return 'Quantity - high to low';
      case _DeliveryHistorySort.quantityLow:
        return 'Quantity - low to high';
    }
  }

  Future<void> _pickDate({required bool from}) async {
    final current = DateTime.tryParse(from ? _fromDate : _toDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      final value = _apiDate(picked);
      if (from) {
        _fromDate = value;
      } else {
        _toDate = value;
      }
    });
  }

  void _clearFilters() {
    setState(() {
      _fromDate = '';
      _toDate = '';
      _fuelFilter = DeliveryFuelFilter.all;
      _sort = _DeliveryHistorySort.purchaseNewest;
    });
  }

  bool get _hasFilters =>
      _fromDate.isNotEmpty ||
      _toDate.isNotEmpty ||
      _fuelFilter != DeliveryFuelFilter.all ||
      _sort != _DeliveryHistorySort.purchaseNewest;

  Widget _filterButton({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFFECEFF8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDDE3F0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.event_rounded, size: 18, color: kClayPrimary),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: kClaySub,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value.isEmpty ? 'Any date' : formatDateLabel(value),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: kClayPrimary,
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

  Widget _filterDropdown<T>({
    required String label,
    required T value,
    required List<T> values,
    required String Function(T value) labelFor,
    required ValueChanged<T> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 10, 4),
      decoration: BoxDecoration(
        color: const Color(0xFFECEFF8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE3F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: kClaySub,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              isDense: true,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF5D6685),
                size: 22,
              ),
              style: const TextStyle(
                color: kClayPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(14),
              items: values
                  .map(
                    (item) => DropdownMenuItem<T>(
                      value: item,
                      child: Text(
                        labelFor(item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (selected) {
                if (selected == null) return;
                onChanged(selected);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState({required bool hasPurchases}) {
    return ClayCard(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFECEFF8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              hasPurchases
                  ? Icons.filter_alt_rounded
                  : Icons.local_shipping_outlined,
              color: kClayPrimary,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            hasPurchases
                ? 'No purchases match these filters'
                : 'No purchases recorded yet',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: kClayPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            hasPurchases
                ? 'Change the date range, fuel type, or sorting to find older records.'
                : 'Recorded fuel purchases will appear here with date, quantity, and notes.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: kClaySub, fontSize: 12, height: 1.35),
          ),
          if (_hasFilters) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: _clearFilters,
              child: const Text('Clear filter'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _countPill({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFECEFF8),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: kClayPrimary, size: 17),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: kClayPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: kClaySub,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterCard({
    required int totalCount,
    required int visibleCount,
  }) {
    return ClayCard(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A3A7A).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_shipping_rounded,
                  color: Color(0xFF1A3A7A),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Purchase Records',
                      style: TextStyle(
                        color: kClayPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      totalCount == 0
                          ? 'No purchases recorded yet'
                          : '$visibleCount of $totalCount purchase event${totalCount == 1 ? '' : 's'} shown',
                      style: const TextStyle(
                        color: kClaySub,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (_hasFilters)
                TextButton(
                  onPressed: _clearFilters,
                  child: const Text('Clear filter'),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _countPill(
                icon: Icons.receipt_long_rounded,
                label: 'total records',
                value: totalCount.toString(),
              ),
              const SizedBox(width: 10),
              _countPill(
                icon: Icons.visibility_rounded,
                label: 'visible now',
                value: visibleCount.toString(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'FILTERS',
            style: TextStyle(
              color: kClaySub,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
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
          _filterDropdown<DeliveryFuelFilter>(
            label: 'Fuel filter',
            value: _fuelFilter,
            values: DeliveryFuelFilter.values,
            labelFor: _fuelFilterLabel,
            onChanged: (value) => setState(() => _fuelFilter = value),
          ),
          const SizedBox(height: 12),
          _filterDropdown<_DeliveryHistorySort>(
            label: 'Sort by',
            value: _sort,
            values: _DeliveryHistorySort.values,
            labelFor: _sortLabel,
            onChanged: (value) => setState(() => _sort = value),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<DeliveryReceiptModel>>(
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
                children: [
                  Text('Failed to load history\n${_errorText(snapshot.error)}'),
                ],
              );
            }
            final deliveries = snapshot.data ?? const <DeliveryReceiptModel>[];
            final visibleDeliveries = _filteredAndSorted(deliveries);
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _buildFilterCard(
                  totalCount: deliveries.length,
                  visibleCount: visibleDeliveries.length,
                ),
                if (visibleDeliveries.isEmpty)
                  _emptyState(hasPurchases: deliveries.isNotEmpty)
                else
                  ...visibleDeliveries.map(
                    (delivery) => DeliveryReceiptSummaryCard(
                      delivery: delivery,
                      fuelFilter: _fuelFilter,
                      margin: const EdgeInsets.only(bottom: 14),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

enum DeliveryFuelFilter { all, petrol, diesel, twoT, mixed }

enum _DeliveryHistorySort {
  purchaseNewest,
  purchaseOldest,
  quantityHigh,
  quantityLow,
}

class DeliveryReceiptSummaryCard extends StatelessWidget {
  const DeliveryReceiptSummaryCard({
    super.key,
    required this.delivery,
    this.fuelFilter = DeliveryFuelFilter.all,
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  final DeliveryReceiptModel delivery;
  final DeliveryFuelFilter fuelFilter;
  final EdgeInsetsGeometry margin;

  String _deliveryTitle() {
    switch (fuelFilter) {
      case DeliveryFuelFilter.petrol:
        return 'Petrol Purchase';
      case DeliveryFuelFilter.diesel:
        return 'Diesel Purchase';
      case DeliveryFuelFilter.twoT:
        return '2T Oil Purchase';
      case DeliveryFuelFilter.all:
      case DeliveryFuelFilter.mixed:
        break;
    }
    final petrol = delivery.quantities['petrol'] ?? 0;
    final diesel = delivery.quantities['diesel'] ?? 0;
    final twoT = delivery.quantities['two_t_oil'] ?? 0;
    if ((petrol > 0 || diesel > 0) && twoT <= 0) {
      return 'Petrol + Diesel Purchase';
    }
    if (twoT > 0 && petrol <= 0 && diesel <= 0) return '2T Oil Purchase';
    return 'Mixed Purchase';
  }

  List<_DeliveryQtyItem> _qtyItems() {
    final items = <_DeliveryQtyItem>[];
    final petrol = delivery.quantities['petrol'] ?? 0;
    final diesel = delivery.quantities['diesel'] ?? 0;
    final twoT = delivery.quantities['two_t_oil'] ?? 0;
    if (petrol > 0 &&
        (fuelFilter == DeliveryFuelFilter.all ||
            fuelFilter == DeliveryFuelFilter.mixed ||
            fuelFilter == DeliveryFuelFilter.petrol)) {
      items.add(
        _DeliveryQtyItem(
          label: 'Petrol',
          liters: petrol,
          color: const Color(0xFF1298B8),
        ),
      );
    }
    if (diesel > 0 &&
        (fuelFilter == DeliveryFuelFilter.all ||
            fuelFilter == DeliveryFuelFilter.mixed ||
            fuelFilter == DeliveryFuelFilter.diesel)) {
      items.add(
        _DeliveryQtyItem(
          label: 'Diesel',
          liters: diesel,
          color: const Color(0xFF2AA878),
        ),
      );
    }
    if (twoT > 0 &&
        (fuelFilter == DeliveryFuelFilter.all ||
            fuelFilter == DeliveryFuelFilter.mixed ||
            fuelFilter == DeliveryFuelFilter.twoT)) {
      items.add(
        _DeliveryQtyItem(
          label: '2T Oil',
          liters: twoT,
          color: const Color(0xFF7048A8),
        ),
      );
    }
    return items;
  }

  double _displayQuantity() {
    switch (fuelFilter) {
      case DeliveryFuelFilter.petrol:
        return delivery.quantities['petrol'] ?? 0;
      case DeliveryFuelFilter.diesel:
        return delivery.quantities['diesel'] ?? 0;
      case DeliveryFuelFilter.twoT:
        return delivery.quantities['two_t_oil'] ?? 0;
      case DeliveryFuelFilter.all:
      case DeliveryFuelFilter.mixed:
        return delivery.quantity;
    }
  }

  String _badgeLabel() {
    switch (fuelFilter) {
      case DeliveryFuelFilter.petrol:
        return 'P';
      case DeliveryFuelFilter.diesel:
        return 'D';
      case DeliveryFuelFilter.twoT:
        return '2T';
      case DeliveryFuelFilter.all:
      case DeliveryFuelFilter.mixed:
        return _isTwoTOnly() ? '2T' : 'PD';
    }
  }

  bool _isTwoTOnly() {
    final petrol = delivery.quantities['petrol'] ?? 0;
    final diesel = delivery.quantities['diesel'] ?? 0;
    final twoT = delivery.quantities['two_t_oil'] ?? 0;
    return twoT > 0 && petrol <= 0 && diesel <= 0;
  }

  @override
  Widget build(BuildContext context) {
    final qtyItems = _qtyItems();
    return ClayCard(
      margin: margin,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF1A3A7A).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                _badgeLabel(),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: Color(0xFF1A3A7A),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _deliveryTitle(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: kClayPrimary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatDateLabel(delivery.date)}  ·  Total ${formatLiters(_displayQuantity())}',
                  style: const TextStyle(color: kClaySub, fontSize: 12),
                ),
                if (delivery.purchasedByName.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Entered by ${delivery.purchasedByName}',
                    style: const TextStyle(
                      color: kClayPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (qtyItems.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: qtyItems
                        .map(
                          (item) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: item.color.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${item.label}: ${formatLiters(item.liters)}',
                              style: TextStyle(
                                color: item.color,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                if (delivery.note.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    delivery.note,
                    style: const TextStyle(
                      color: kClaySub,
                      height: 1.35,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryQtyItem {
  const _DeliveryQtyItem({
    required this.label,
    required this.liters,
    required this.color,
  });
  final String label;
  final double liters;
  final Color color;
}
