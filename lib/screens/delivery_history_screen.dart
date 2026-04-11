import 'package:flutter/material.dart';

import '../models/domain_models.dart';
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

  @override
  void initState() {
    super.initState();
    _future = _inventoryService.fetchDeliveries();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _inventoryService.fetchDeliveries();
    });
    await _future;
  }

  String _errorText(Object? error) {
    return userFacingErrorMessage(error);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kClayBg,
      appBar: AppBar(
        backgroundColor: kClayBg,
        title: const Text(
          'Delivery History',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: kClayPrimary,
          ),
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Text(
                      'Failed to load history\n${_errorText(snapshot.error)}'),
                ],
              );
            }
            final deliveries =
                snapshot.data ?? const <DeliveryReceiptModel>[];
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                // ── Summary pill ─────────────────────────────────
                ClayCard(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Row(
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
                      Text(
                        deliveries.isEmpty
                            ? 'No delivery receipts recorded yet.'
                            : '${deliveries.length} delivery event${deliveries.length == 1 ? '' : 's'} recorded.',
                        style: const TextStyle(
                          color: kClayPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (deliveries.isNotEmpty)
                  ...deliveries.map(
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
    if ((petrol > 0 || diesel > 0) && twoT <= 0) return 'Petrol + Diesel Delivery';
    if (twoT > 0 && petrol <= 0 && diesel <= 0) return '2T Oil Delivery';
    return 'Mixed Delivery';
  }

  List<_DeliveryQtyItem> _qtyItems() {
    final items = <_DeliveryQtyItem>[];
    final petrol = delivery.quantities['petrol'] ?? 0;
    final diesel = delivery.quantities['diesel'] ?? 0;
    final twoT = delivery.quantities['two_t_oil'] ?? 0;
    if (petrol > 0)
      items.add(_DeliveryQtyItem(
        label: 'Petrol',
        liters: petrol,
        color: const Color(0xFF1298B8),
      ));
    if (diesel > 0)
      items.add(_DeliveryQtyItem(
        label: 'Diesel',
        liters: diesel,
        color: const Color(0xFF2AA878),
      ));
    if (twoT > 0)
      items.add(_DeliveryQtyItem(
        label: '2T Oil',
        liters: twoT,
        color: const Color(0xFF7048A8),
      ));
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
