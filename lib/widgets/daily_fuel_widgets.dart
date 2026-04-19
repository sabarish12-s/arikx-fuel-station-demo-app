import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../utils/formatters.dart';
import 'clay_widgets.dart';

class DailyFuelStatusCard extends StatelessWidget {
  const DailyFuelStatusCard({
    super.key,
    required this.title,
    required this.targetDate,
    required this.record,
    this.pendingMessage = 'Density is pending for this date.',
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.onHistory,
  });

  final String title;
  final String targetDate;
  final DailyFuelRecordModel? record;
  final String pendingMessage;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final VoidCallback? onHistory;

  bool get _isComplete => record?.isComplete ?? false;

  @override
  Widget build(BuildContext context) {
    return ClayCard(
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
                      title,
                      style: const TextStyle(
                        color: kClayPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatDateLabel(targetDate),
                      style: const TextStyle(
                        color: kClaySub,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color:
                      _isComplete
                          ? const Color(0xFFD4F5E9)
                          : const Color(0xFFFDE8DF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _isComplete ? 'Saved' : 'Pending',
                  style: TextStyle(
                    color:
                        _isComplete
                            ? const Color(0xFF0F8A73)
                            : const Color(0xFFCE5828),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isComplete && record != null) ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 560;
                final children = [
                  _FuelMetricPanel(
                    title: 'Petrol',
                    accent: const Color(0xFF1E5CBA),
                    openingStock: record!.openingStock['petrol'] ?? 0,
                    density: record!.density['petrol'] ?? 0,
                    price: record!.price['petrol'] ?? 0,
                  ),
                  _FuelMetricPanel(
                    title: 'Diesel',
                    accent: const Color(0xFF0F8A73),
                    openingStock: record!.openingStock['diesel'] ?? 0,
                    density: record!.density['diesel'] ?? 0,
                    price: record!.price['diesel'] ?? 0,
                  ),
                ];
                if (wide) {
                  return Row(
                    children: [
                      Expanded(child: children[0]),
                      const SizedBox(width: 10),
                      Expanded(child: children[1]),
                    ],
                  );
                }
                return Column(
                  children: [
                    children[0],
                    const SizedBox(height: 10),
                    children[1],
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            _AuditStrip(record: record!),
          ] else ...[
            Text(
              pendingMessage,
              style: const TextStyle(
                color: kClaySub,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
          if (record != null &&
              record!.sourceClosingDate.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Opening stock source: ${formatDateLabel(record!.sourceClosingDate)} closing',
              style: const TextStyle(
                color: kClaySub,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (onPrimaryAction != null || onHistory != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (onPrimaryAction != null)
                  Expanded(
                    child: FilledButton(
                      onPressed: onPrimaryAction,
                      child: Text(primaryActionLabel ?? 'Open'),
                    ),
                  ),
                if (onPrimaryAction != null && onHistory != null)
                  const SizedBox(width: 10),
                if (onHistory != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onHistory,
                      child: const Text('History'),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class DailyFuelEntrySection extends StatefulWidget {
  const DailyFuelEntrySection({
    super.key,
    required this.targetDate,
    required this.record,
    required this.busy,
    required this.onSave,
    this.onHistory,
  });

  final String targetDate;
  final DailyFuelRecordModel? record;
  final bool busy;
  final Future<void> Function(Map<String, double> density) onSave;
  final VoidCallback? onHistory;

  @override
  State<DailyFuelEntrySection> createState() => _DailyFuelEntrySectionState();
}

class _DailyFuelEntrySectionState extends State<DailyFuelEntrySection> {
  late final TextEditingController _petrolController;
  late final TextEditingController _dieselController;

  @override
  void initState() {
    super.initState();
    _petrolController = TextEditingController();
    _dieselController = TextEditingController();
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant DailyFuelEntrySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldPetrol = oldWidget.record?.density['petrol'];
    final newPetrol = widget.record?.density['petrol'];
    final oldDiesel = oldWidget.record?.density['diesel'];
    final newDiesel = widget.record?.density['diesel'];
    if (oldWidget.targetDate != widget.targetDate ||
        oldPetrol != newPetrol ||
        oldDiesel != newDiesel ||
        oldWidget.record?.updatedAt != widget.record?.updatedAt) {
      _syncControllers();
    }
  }

  @override
  void dispose() {
    _petrolController.dispose();
    _dieselController.dispose();
    super.dispose();
  }

  void _syncControllers() {
    final petrol = widget.record?.density['petrol'] ?? 0;
    final diesel = widget.record?.density['diesel'] ?? 0;
    _petrolController.text = petrol > 0 ? petrol.toString() : '';
    _dieselController.text = diesel > 0 ? diesel.toString() : '';
  }

  Future<void> _submit() async {
    final petrol = double.tryParse(_petrolController.text.trim());
    final diesel = double.tryParse(_dieselController.text.trim());
    if (petrol == null || petrol <= 0 || diesel == null || diesel <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter petrol and diesel density values greater than zero.',
          ),
        ),
      );
      return;
    }
    await widget.onSave({
      'petrol': petrol,
      'diesel': diesel,
    });
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    return ClayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Daily Fuel Register',
                  style: TextStyle(
                    color: kClayPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (widget.onHistory != null)
                IconButton(
                  tooltip: 'History',
                  onPressed: widget.onHistory,
                  icon: const Icon(Icons.history_rounded),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Opening stock is auto-filled from the previous day closing. Price comes from settings. Save density before entering pump sales.',
            style: const TextStyle(
              color: kClaySub,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoPill(
                label: 'Date',
                value: formatDateLabel(widget.targetDate),
              ),
              if (record != null && record.sourceClosingDate.trim().isNotEmpty)
                _InfoPill(
                  label: 'Opening source',
                  value: formatDateLabel(record.sourceClosingDate),
                ),
              _InfoPill(
                label: 'Status',
                value: record?.isComplete == true ? 'Saved' : 'Pending',
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 560;
              final children = [
                _DensityInputCard(
                  title: 'Petrol',
                  accent: const Color(0xFF1E5CBA),
                  openingStock: record?.openingStock['petrol'] ?? 0,
                  price: record?.price['petrol'] ?? 0,
                  controller: _petrolController,
                ),
                _DensityInputCard(
                  title: 'Diesel',
                  accent: const Color(0xFF0F8A73),
                  openingStock: record?.openingStock['diesel'] ?? 0,
                  price: record?.price['diesel'] ?? 0,
                  controller: _dieselController,
                ),
              ];
              if (wide) {
                return Row(
                  children: [
                    Expanded(child: children[0]),
                    const SizedBox(width: 10),
                    Expanded(child: children[1]),
                  ],
                );
              }
              return Column(
                children: [
                  children[0],
                  const SizedBox(height: 10),
                  children[1],
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: widget.busy ? null : _submit,
            icon:
                widget.busy
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : const Icon(Icons.save_rounded),
            label: Text(record?.isComplete == true ? 'Update Density' : 'Save Density'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: kClayHeroStart,
              foregroundColor: Colors.white,
            ),
          ),
          if (record != null && record.exists) ...[
            const SizedBox(height: 12),
            _AuditStrip(record: record),
          ],
        ],
      ),
    );
  }
}

class _FuelMetricPanel extends StatelessWidget {
  const _FuelMetricPanel({
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FD),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: accent,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          _MetricRow(label: 'Opening stock', value: formatLiters(openingStock)),
          _MetricRow(label: 'Density', value: formatDensity(density)),
          _MetricRow(label: 'Price', value: formatPricePerLiter(price)),
        ],
      ),
    );
  }
}

class _DensityInputCard extends StatelessWidget {
  const _DensityInputCard({
    required this.title,
    required this.accent,
    required this.openingStock,
    required this.price,
    required this.controller,
  });

  final String title;
  final Color accent;
  final double openingStock;
  final double price;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FD),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: accent,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          _MetricRow(label: 'Opening stock', value: formatLiters(openingStock)),
          _MetricRow(label: 'Price', value: formatPricePerLiter(price)),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Density',
              hintText: 'Enter kg/m3',
              suffixText: 'kg/m3',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: kClaySub,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: kClayPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4FB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: kClaySub,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: kClayPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditStrip extends StatelessWidget {
  const _AuditStrip({required this.record});

  final DailyFuelRecordModel record;

  @override
  Widget build(BuildContext context) {
    final createdBy =
        record.createdByName.trim().isNotEmpty
            ? record.createdByName.trim()
            : record.createdBy.trim();
    final updatedBy =
        record.updatedByName.trim().isNotEmpty
            ? record.updatedByName.trim()
            : record.updatedBy.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FD),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (createdBy.isNotEmpty || record.createdAt.trim().isNotEmpty)
            Text(
              'Created${createdBy.isNotEmpty ? ' by $createdBy' : ''}${record.createdAt.trim().isNotEmpty ? ' on ${formatDateTimeLabel(record.createdAt)}' : ''}',
              style: const TextStyle(
                color: kClaySub,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (updatedBy.isNotEmpty || record.updatedAt.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Last updated${updatedBy.isNotEmpty ? ' by $updatedBy' : ''}${record.updatedAt.trim().isNotEmpty ? ' on ${formatDateTimeLabel(record.updatedAt)}' : ''}',
                style: const TextStyle(
                  color: kClaySub,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
