import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/inventory_service.dart';
import '../utils/formatters.dart';
import 'credit_ledger_screen.dart';
import 'delivery_history_screen.dart';
import 'delivery_receipt_screen.dart';
import 'fuel_price_settings_screen.dart';
import 'inventory_planning_settings_screen.dart';

class InventoryHubScreen extends StatefulWidget {
  const InventoryHubScreen({super.key, this.canManagePlanning = false});

  final bool canManagePlanning;

  @override
  State<InventoryHubScreen> createState() => _InventoryHubScreenState();
}

class _InventoryHubScreenState extends State<InventoryHubScreen> {
  final InventoryService _inventoryService = InventoryService();
  late Future<InventoryDashboardModel> _future;

  String _errorText(Object? error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  @override
  void initState() {
    super.initState();
    _future = _inventoryService.fetchInventoryDashboard();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _inventoryService.fetchInventoryDashboard();
    });
    await _future;
  }

  Future<void> _openDeliveryReceipt(
    List<FuelInventoryForecastModel> fuels,
  ) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => DeliveryReceiptScreen(fuels: fuels),
      ),
    );
    if (saved == true && mounted) {
      await _refresh();
    }
  }

  Future<void> _openPlanningSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder:
            (_) => InventoryPlanningSettingsScreen(
              canEdit: widget.canManagePlanning,
            ),
      ),
    );
    if (mounted) {
      await _refresh();
    }
  }

  Future<void> _openCreditLedger() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const CreditLedgerScreen()),
    );
    if (mounted) {
      await _refresh();
    }
  }

  Future<void> _openFuelPrices() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const FuelPriceSettingsScreen(canEdit: true),
      ),
    );
    if (mounted) {
      await _refresh();
    }
  }

  Future<void> _openDeliveryHistory() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const DeliveryHistoryScreen()),
    );
    if (mounted) {
      await _refresh();
    }
  }

  String _displayDate(String raw) {
    if (raw.trim().isEmpty) {
      return 'Not available';
    }
    return formatDateLabel(raw);
  }

  String _daysRemainingLabel(double? value) {
    if (value == null) {
      return 'Not enough sales yet';
    }
    return '${value.toStringAsFixed(1)} day(s)';
  }

  Color _fuelColor(String fuelTypeId) {
    switch (fuelTypeId) {
      case 'petrol':
        return const Color(0xFF1E5CBA);
      case 'diesel':
        return const Color(0xFF006C5C);
      case 'two_t_oil':
        return const Color(0xFFB45309);
      default:
        return const Color(0xFF695781);
    }
  }

  Widget _buildForecastMetricGrid(FuelInventoryForecastModel item) {
    final metrics = [
      _ForecastMetric(
        label: 'Current stock',
        value: formatLiters(item.currentStock),
      ),
      _ForecastMetric(
        label: '7 day avg sales',
        value: formatLiters(item.averageDailySales),
      ),
      _ForecastMetric(
        label: 'Days remaining',
        value: _daysRemainingLabel(item.daysRemaining),
      ),
      _ForecastMetric(
        label: 'Projected runout',
        value: _displayDate(item.projectedRunoutDate),
      ),
      _ForecastMetric(
        label: 'Recommended order by',
        value: _displayDate(item.recommendedOrderDate),
      ),
    ];

    final rows = <Widget>[];
    for (var index = 0; index < metrics.length; index += 2) {
      final isLastSingle = index == metrics.length - 1;
      if (isLastSingle) {
        rows.add(SizedBox(width: double.infinity, child: metrics[index]));
        continue;
      }
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: metrics[index]),
            const SizedBox(width: 12),
            Expanded(child: metrics[index + 1]),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < rows.length; index++) ...[
          rows[index],
          if (index != rows.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<InventoryDashboardModel>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text('Failed to load inventory\n${_errorText(snapshot.error)}'),
              ],
            );
          }

          final data = snapshot.data!;
          final planning = data.inventoryPlanning;

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 120),
            children: [
              Text(
                data.station.name,
                style: const TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF55606E),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: () => _openDeliveryReceipt(data.forecast),
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: const Text('Record Delivery'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _openCreditLedger,
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Credit Ledger'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _openFuelPrices,
                    icon: const Icon(Icons.payments_rounded),
                    label: const Text('Fuel Prices'),
                  ),
                  if (widget.canManagePlanning)
                    OutlinedButton.icon(
                      onPressed: _openPlanningSettings,
                      icon: const Icon(Icons.tune_rounded),
                      label: const Text('Planning Settings'),
                    ),
                  IconButton(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children:
                    data.forecast
                        .map(
                          (item) => _InventoryStatCard(
                            title: item.label,
                            value: formatLiters(item.currentStock),
                            accent: _fuelColor(item.fuelTypeId),
                            subtitle:
                                item.shouldAlert
                                    ? 'Alert active'
                                    : 'Forecast healthy',
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Planning Snapshot',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF293340),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Delivery lead: ${planning.deliveryLeadDays} day(s)',
                      style: const TextStyle(color: Color(0xFF55606E)),
                    ),
                    Text(
                      'Alert before: ${planning.alertBeforeDays} day(s)',
                      style: const TextStyle(color: Color(0xFF55606E)),
                    ),
                    Text(
                      'Baseline stock updated: ${planning.updatedAt.trim().isEmpty ? 'Not set yet' : formatDateLabel(planning.updatedAt.split('T').first)}',
                      style: const TextStyle(color: Color(0xFF55606E)),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Current stock is calculated from the tank baseline, plus delivery receipts, minus saved sales entries. Pump opening readings remain separate from inventory.',
                      style: TextStyle(color: Color(0xFF55606E), height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              ...data.forecast.map(
                (item) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.label,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF293340),
                              ),
                            ),
                          ),
                          Chip(
                            backgroundColor:
                                item.shouldAlert
                                    ? const Color(0xFFFEE2E2)
                                    : const Color(0xFFE6F6EF),
                            label: Text(
                              item.shouldAlert ? 'Order now' : 'On track',
                              style: TextStyle(
                                color:
                                    item.shouldAlert
                                        ? const Color(0xFFB91C1C)
                                        : const Color(0xFF166534),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildForecastMetricGrid(item),
                      if (item.alertMessage.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            item.alertMessage,
                            style: const TextStyle(
                              color: Color(0xFF9A3412),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Recent Delivery',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF293340),
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _openDeliveryHistory,
                          icon: const Icon(Icons.history_rounded),
                          label: const Text('History'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'The latest delivery event is shown here. Open history to review every past delivery receipt.',
                      style: TextStyle(color: Color(0xFF55606E), height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    if (data.deliveries.isEmpty)
                      const Text(
                        'No delivery receipts recorded yet.',
                        style: TextStyle(color: Color(0xFF55606E)),
                      )
                    else
                      DeliveryReceiptSummaryCard(
                        delivery: data.deliveries.first,
                        margin: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InventoryStatCard extends StatelessWidget {
  const _InventoryStatCard({
    required this.title,
    required this.value,
    required this.accent,
    this.subtitle = '',
  });

  final String title;
  final String value;
  final Color accent;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF55606E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFF293340),
            ),
          ),
          if (subtitle.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Color(0xFF55606E)),
            ),
          ],
        ],
      ),
    );
  }
}

class _ForecastMetric extends StatelessWidget {
  const _ForecastMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF55606E),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF293340),
            ),
          ),
        ],
      ),
    );
  }
}
