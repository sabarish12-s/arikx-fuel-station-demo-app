import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/inventory_service.dart';
import '../utils/formatters.dart';

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
    return error.toString().replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(title: const Text('Delivery History')),
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
                  Text('Failed to load history\n${_errorText(snapshot.error)}'),
                ],
              );
            }
            final deliveries = snapshot.data ?? const <DeliveryReceiptModel>[];
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    deliveries.isEmpty
                        ? 'No delivery receipts recorded yet.'
                        : '${deliveries.length} delivery event${deliveries.length == 1 ? '' : 's'} recorded.',
                    style: const TextStyle(
                      color: Color(0xFF55606E),
                      height: 1.4,
                    ),
                  ),
                ),
                if (deliveries.isEmpty)
                  const SizedBox.shrink()
                else
                  ...deliveries.map(
                    (delivery) =>
                        DeliveryReceiptSummaryCard(delivery: delivery),
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
    if ((petrol > 0 || diesel > 0) && twoT <= 0) {
      return 'Petrol + Diesel Delivery';
    }
    if (twoT > 0 && petrol <= 0 && diesel <= 0) {
      return '2T Oil Delivery';
    }
    return 'Mixed Delivery';
  }

  List<String> _quantityLines() {
    final lines = <String>[];
    final petrol = delivery.quantities['petrol'] ?? 0;
    final diesel = delivery.quantities['diesel'] ?? 0;
    final twoT = delivery.quantities['two_t_oil'] ?? 0;
    if (petrol > 0) {
      lines.add('Petrol: ${formatLiters(petrol)}');
    }
    if (diesel > 0) {
      lines.add('Diesel: ${formatLiters(diesel)}');
    }
    if (twoT > 0) {
      lines.add('2T Oil: ${formatLiters(twoT)}');
    }
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final quantityLines = _quantityLines();
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFE9EEF7),
            child: Text(
              (delivery.quantities['two_t_oil'] ?? 0) > 0 &&
                      (delivery.quantities['petrol'] ?? 0) <= 0 &&
                      (delivery.quantities['diesel'] ?? 0) <= 0
                  ? '2T'
                  : 'PD',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E5CBA),
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
                    color: Color(0xFF293340),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatDateLabel(delivery.date)}  |  Total ${formatLiters(delivery.quantity)}',
                  style: const TextStyle(color: Color(0xFF55606E)),
                ),
                if (quantityLines.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...quantityLines.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        line,
                        style: const TextStyle(color: Color(0xFF55606E)),
                      ),
                    ),
                  ),
                ],
                if (delivery.note.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    delivery.note,
                    style: const TextStyle(
                      color: Color(0xFF55606E),
                      height: 1.35,
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
