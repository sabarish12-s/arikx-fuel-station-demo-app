import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/inventory_service.dart';
import '../utils/formatters.dart';
import '../utils/user_facing_errors.dart';
import '../widgets/responsive_text.dart';
import 'delivery_history_screen.dart';
import 'delivery_receipt_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _future = _inventoryService.fetchInventoryDashboard();
  }

  Future<void> _refresh() async {
    setState(() => _future = _inventoryService.fetchInventoryDashboard());
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
    if (saved == true && mounted) await _refresh();
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
    if (mounted) await _refresh();
  }

  Future<void> _openDeliveryHistory() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const DeliveryHistoryScreen()),
    );
    if (mounted) await _refresh();
  }

  String _displayDate(String raw) =>
      raw.trim().isEmpty ? 'Not available' : formatDateLabel(raw);

  String _daysLabel(double? v) =>
      v == null ? 'Not enough data' : '${v.toStringAsFixed(1)} day(s)';

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
        child: FutureBuilder<InventoryDashboardModel>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [Text(userFacingErrorMessage(snapshot.error))],
              );
            }

            final data = snapshot.data!;
            final planning = data.inventoryPlanning;
            final alertCount = data.forecast.where((f) => f.shouldAlert).length;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                // ── Hero header ─────────────────────────────────────
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
                        color: const Color(0xFF0D2460).withValues(alpha: 0.45),
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data.station.name,
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                const Text(
                                  'Inventory',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (alertCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFB91C1C,
                                ).withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: const Color(
                                    0xFFFF6B6B,
                                  ).withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    color: Color(0xFFFF9999),
                                    size: 14,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    '$alertCount alert${alertCount > 1 ? 's' : ''}',
                                    style: const TextStyle(
                                      color: Color(0xFFFF9999),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children:
                            data.forecast.map((item) {
                              final isLast = item == data.forecast.last;
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
                                            style: TextStyle(
                                              color:
                                                  item.shouldAlert
                                                      ? const Color(0xFFFF9999)
                                                      : Colors.white,
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

                // ── Action buttons ───────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _InvActionBtn(
                        icon: Icons.local_shipping_outlined,
                        label: 'Record Delivery',
                        onTap: () => _openDeliveryReceipt(data.forecast),
                        filled: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: _InvActionBtn(
                        icon: Icons.tune_rounded,
                        label: 'Planning Settings',
                        onTap: _openPlanningSettings,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _InvIconBtn(icon: Icons.refresh_rounded, onTap: _refresh),
                  ],
                ),

                const SizedBox(height: 18),

                // ── Planning snapshot ────────────────────────────────
                _ClayCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECEFF8),
                              borderRadius: BorderRadius.circular(10),
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
                            child: const Icon(
                              Icons.analytics_outlined,
                              color: Color(0xFF1A3A7A),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Planning Snapshot',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A2561),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _SnapshotPill(
                            label: 'Lead time',
                            value: '${planning.deliveryLeadDays}d',
                          ),
                          const SizedBox(width: 8),
                          _SnapshotPill(
                            label: 'Alert before',
                            value: '${planning.alertBeforeDays}d',
                          ),
                          const SizedBox(width: 8),
                          _SnapshotPill(
                            label: 'Updated',
                            value:
                                planning.updatedAt.trim().isEmpty
                                    ? '—'
                                    : formatDateLabel(
                                      planning.updatedAt.split('T').first,
                                    ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── Fuel detail cards ────────────────────────────────
                ...data.forecast.map(
                  (item) => _FuelForecastCard(
                    item: item,
                    accentColor: _fuelColor(item.fuelTypeId),
                    displayDate: _displayDate,
                    daysLabel: _daysLabel,
                  ),
                ),

                // ── Recent delivery ──────────────────────────────────
                _ClayCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Recent Delivery',
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
                      if (data.deliveries.isEmpty)
                        const Text(
                          'No delivery receipts recorded yet.',
                          style: TextStyle(
                            color: Color(0xFF8A93B8),
                            fontSize: 13,
                          ),
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
      ),
    );
  }
}

// ─── Fuel forecast card ────────────────────────────────────────────────────────
class _FuelForecastCard extends StatelessWidget {
  const _FuelForecastCard({
    required this.item,
    required this.accentColor,
    required this.displayDate,
    required this.daysLabel,
  });

  final FuelInventoryForecastModel item;
  final Color accentColor;
  final String Function(String) displayDate;
  final String Function(double?) daysLabel;

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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color:
                      item.shouldAlert
                          ? const Color(0xFFFEF2F2)
                          : const Color(0xFFE8F8EF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.shouldAlert
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 12,
                      color:
                          item.shouldAlert
                              ? const Color(0xFFB91C1C)
                              : const Color(0xFF0A7A4A),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item.shouldAlert ? 'Order now' : 'On track',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color:
                            item.shouldAlert
                                ? const Color(0xFFB91C1C)
                                : const Color(0xFF0A7A4A),
                      ),
                    ),
                  ],
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
                      value: daysLabel(item.daysRemaining),
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
          if (item.alertMessage.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFCE5828).withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                item.alertMessage,
                style: const TextStyle(
                  color: Color(0xFF9A3412),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Metric helpers ────────────────────────────────────────────────────────────
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

// ─── Clay card ─────────────────────────────────────────────────────────────────
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

// ─── Snapshot pill ─────────────────────────────────────────────────────────────
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

// ─── Action button ─────────────────────────────────────────────────────────────
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
          boxShadow:
              _pressed
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
          boxShadow:
              _pressed
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
        child: const Icon(
          Icons.refresh_rounded,
          size: 18,
          color: Color(0xFF4A5598),
        ),
      ),
    );
  }
}
