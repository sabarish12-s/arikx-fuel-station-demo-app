import 'dart:async';

import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/api_response_cache.dart';
import '../services/inventory_service.dart';
import '../utils/formatters.dart';
import '../utils/user_facing_errors.dart';
import '../widgets/clay_widgets.dart';

class DeliveryHistoryScreen extends StatefulWidget {
  const DeliveryHistoryScreen({super.key});

  @override
  State<DeliveryHistoryScreen> createState() => _DeliveryHistoryScreenState();
}

class _DeliveryHistoryScreenState extends State<DeliveryHistoryScreen> {
  final InventoryService _inventoryService = InventoryService();
  late Future<List<DeliveryReceiptModel>> _future;
  late final StreamSubscription<ApiResponseCacheUpdate> _cacheSubscription;
  String _fromDate = '';
  String _toDate = '';
  _DeliveryFuelFilter _fuelFilter = _DeliveryFuelFilter.all;
  _DeliveryHistorySort _sort = _DeliveryHistorySort.purchaseNewest;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _cacheSubscription = ApiResponseCache.updates.listen((update) {
      if (!mounted ||
          !update.background ||
          !update.path.startsWith('/inventory/deliveries')) {
        return;
      }
      setState(() => _future = _load());
    });
  }

  @override
  void dispose() {
    _cacheSubscription.cancel();
    super.dispose();
  }

  Future<List<DeliveryReceiptModel>> _load({bool forceRefresh = false}) {
    return _inventoryService.fetchDeliveries(forceRefresh: forceRefresh);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load(forceRefresh: true));
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
    if (_fuelFilter == _DeliveryFuelFilter.all) {
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
      case _DeliveryFuelFilter.all:
        return true;
      case _DeliveryFuelFilter.petrol:
        return petrol > 0;
      case _DeliveryFuelFilter.diesel:
        return diesel > 0;
      case _DeliveryFuelFilter.twoT:
        return twoT > 0;
      case _DeliveryFuelFilter.mixed:
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
        case _DeliveryHistorySort.savedNewest:
          return _compareDateValues(right.createdAt, left.createdAt);
        case _DeliveryHistorySort.savedOldest:
          return _compareDateValues(left.createdAt, right.createdAt);
        case _DeliveryHistorySort.quantityHigh:
          return right.quantity.compareTo(left.quantity);
        case _DeliveryHistorySort.quantityLow:
          return left.quantity.compareTo(right.quantity);
      }
    });
    return filtered;
  }

  String _fuelFilterLabel(_DeliveryFuelFilter filter) {
    switch (filter) {
      case _DeliveryFuelFilter.all:
        return 'All purchases';
      case _DeliveryFuelFilter.petrol:
        return 'Petrol';
      case _DeliveryFuelFilter.diesel:
        return 'Diesel';
      case _DeliveryFuelFilter.twoT:
        return '2T Oil';
      case _DeliveryFuelFilter.mixed:
        return 'Mixed';
    }
  }

  String _sortLabel(_DeliveryHistorySort sort) {
    switch (sort) {
      case _DeliveryHistorySort.purchaseNewest:
        return 'Purchase date - newest';
      case _DeliveryHistorySort.purchaseOldest:
        return 'Purchase date - oldest';
      case _DeliveryHistorySort.savedNewest:
        return 'Saved date - newest';
      case _DeliveryHistorySort.savedOldest:
        return 'Saved date - oldest';
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
      _fuelFilter = _DeliveryFuelFilter.all;
      _sort = _DeliveryHistorySort.purchaseNewest;
    });
  }

  bool get _hasFilters =>
      _fromDate.isNotEmpty ||
      _toDate.isNotEmpty ||
      _fuelFilter != _DeliveryFuelFilter.all ||
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
      padding: const EdgeInsets.fromLTRB(12, 8, 10, 6),
      decoration: BoxDecoration(
        color: const Color(0xFFECEFF8),
        borderRadius: BorderRadius.circular(16),
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
          DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF5D6685),
              ),
              style: const TextStyle(
                color: kClayPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 14,
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
                  ? Icons.filter_alt_off_rounded
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
            TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
              label: const Text('Clear filters'),
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
                IconButton(
                  tooltip: 'Clear filters',
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.filter_alt_off_rounded),
                  color: kClayPrimary,
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
          _filterDropdown<_DeliveryFuelFilter>(
            label: 'Fuel filter',
            value: _fuelFilter,
            values: _DeliveryFuelFilter.values,
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
        title: const Text(
          'Purchase History',
          style: TextStyle(fontWeight: FontWeight.w900, color: kClayPrimary),
        ),
        iconTheme: const IconThemeData(color: kClayPrimary),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<DeliveryReceiptModel>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
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

enum _DeliveryFuelFilter { all, petrol, diesel, twoT, mixed }

enum _DeliveryHistorySort {
  purchaseNewest,
  purchaseOldest,
  savedNewest,
  savedOldest,
  quantityHigh,
  quantityLow,
}

class DeliveryReceiptSummaryCard extends StatelessWidget {
  const DeliveryReceiptSummaryCard({
    super.key,
    required this.delivery,
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  final DeliveryReceiptModel delivery;
  final EdgeInsetsGeometry margin;

  String _deliveryTitle() {
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
    if (petrol > 0) {
      items.add(
        _DeliveryQtyItem(
          label: 'Petrol',
          liters: petrol,
          color: const Color(0xFF1298B8),
        ),
      );
    }
    if (diesel > 0) {
      items.add(
        _DeliveryQtyItem(
          label: 'Diesel',
          liters: diesel,
          color: const Color(0xFF2AA878),
        ),
      );
    }
    if (twoT > 0) {
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
                _isTwoTOnly() ? '2T' : 'PD',
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
                  '${formatDateLabel(delivery.date)}  ·  Total ${formatLiters(delivery.quantity)}',
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
