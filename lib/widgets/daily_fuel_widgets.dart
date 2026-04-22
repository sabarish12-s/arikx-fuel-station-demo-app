import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/domain_models.dart';
import '../utils/formatters.dart';
import 'clay_widgets.dart';
import 'responsive_text.dart';

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
                  color: _isComplete
                      ? const Color(0xFFD4F5E9)
                      : const Color(0xFFFDE8DF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _isComplete ? 'Saved' : 'Pending',
                  style: TextStyle(
                    color: _isComplete
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

  Future<bool> _submit({
    void Function(String message)? onValidationError,
  }) async {
    final petrol = double.tryParse(_petrolController.text.trim());
    final diesel = double.tryParse(_dieselController.text.trim());
    if (petrol == null || petrol <= 0 || diesel == null || diesel <= 0) {
      const message =
          'Enter petrol and diesel density values greater than zero.';
      if (onValidationError != null) {
        onValidationError(message);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(message)));
      }
      return false;
    }
    await widget.onSave({'petrol': petrol, 'diesel': diesel});
    return true;
  }

  Future<void> _openDensityDialog() async {
    _syncControllers();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var saving = false;
        String? error;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              setDialogState(() {
                saving = true;
                error = null;
              });
              final saved = await _submit(
                onValidationError: (message) => setDialogState(() {
                  error = message;
                }),
              );
              if (!context.mounted) {
                return;
              }
              setDialogState(() {
                saving = false;
              });
              if (saved) {
                Navigator.of(dialogContext).pop();
              }
            }

            final record = widget.record;
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              backgroundColor: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: kClayPrimary.withValues(alpha: 0.12),
                        blurRadius: 36,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [kClayHeroStart, kClayHeroEnd],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.opacity_rounded,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    record?.isComplete == true
                                        ? 'Update Density'
                                        : 'Enter Density',
                                    style: const TextStyle(
                                      color: kClayPrimary,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Save petrol and diesel density for ${formatDateLabel(widget.targetDate)}.',
                                    style: const TextStyle(
                                      color: kClaySub,
                                      fontWeight: FontWeight.w700,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: saving
                                  ? null
                                  : () => Navigator.of(dialogContext).pop(),
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFFF1F4FB),
                                foregroundColor: kClayPrimary,
                              ),
                              icon: const Icon(Icons.close_rounded),
                              tooltip: 'Close',
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F8FD),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFFE2E8F6),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _DialogInfoTile(
                                  label: 'Date',
                                  value: formatDateLabel(widget.targetDate),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _DialogInfoTile(
                                  label: 'Status',
                                  value: record?.isComplete == true
                                      ? 'Saved'
                                      : 'Pending',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final cards = [
                              _DensityInputCard(
                                title: 'Petrol',
                                accent: const Color(0xFF1E5CBA),
                                openingStock:
                                    record?.openingStock['petrol'] ?? 0,
                                price: record?.price['petrol'] ?? 0,
                                controller: _petrolController,
                                hintText: 'Example: 740.5',
                                autofocus: true,
                                textInputAction: TextInputAction.next,
                              ),
                              _DensityInputCard(
                                title: 'Diesel',
                                accent: const Color(0xFF0F8A73),
                                openingStock:
                                    record?.openingStock['diesel'] ?? 0,
                                price: record?.price['diesel'] ?? 0,
                                controller: _dieselController,
                                hintText: 'Example: 830.2',
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => save(),
                              ),
                            ];
                            final wide = constraints.maxWidth >= 620;
                            if (wide) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: cards[0]),
                                  const SizedBox(width: 12),
                                  Expanded(child: cards[1]),
                                ],
                              );
                            }
                            return Column(
                              children: [
                                cards[0],
                                const SizedBox(height: 12),
                                cards[1],
                              ],
                            );
                          },
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFFECACA),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 1),
                                  child: Icon(
                                    Icons.warning_amber_rounded,
                                    size: 18,
                                    color: Color(0xFFB91C1C),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    error!,
                                    style: const TextStyle(
                                      color: Color(0xFFB91C1C),
                                      fontWeight: FontWeight.w700,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: saving
                                    ? null
                                    : () => Navigator.of(dialogContext).pop(),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(50),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: saving || widget.busy ? null : save,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(50),
                                  backgroundColor: kClayHeroStart,
                                  foregroundColor: Colors.white,
                                ),
                                icon: saving || widget.busy
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.save_rounded),
                                label: Text(
                                  record?.isComplete == true
                                      ? 'Update Density'
                                      : 'Save Density',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final sourceClosingDate = record?.sourceClosingDate.trim() ?? '';
    final infoPills = <Widget>[
      _InfoPill(label: 'Date', value: formatDateLabel(widget.targetDate)),
      if (sourceClosingDate.isNotEmpty)
        _InfoPill(
          label: 'Opening source',
          value: formatDateLabel(sourceClosingDate),
        ),
      _InfoPill(
        label: 'Status',
        value: record?.isComplete == true ? 'Saved' : 'Pending',
      ),
    ];

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
                TextButton.icon(
                  onPressed: widget.onHistory,
                  icon: const Icon(Icons.history_rounded),
                  label: const Text('History'),
                  style: TextButton.styleFrom(
                    foregroundColor: kClayPrimary,
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var index = 0; index < infoPills.length; index++) ...[
                if (index > 0) const SizedBox(width: 10),
                Expanded(child: infoPills[index]),
              ],
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 560;
              final children = [
                _DensityOverviewCard(
                  title: 'Petrol',
                  accent: const Color(0xFF1E5CBA),
                  openingStock: record?.openingStock['petrol'] ?? 0,
                  density: record?.density['petrol'] ?? 0,
                  price: record?.price['petrol'] ?? 0,
                ),
                _DensityOverviewCard(
                  title: 'Diesel',
                  accent: const Color(0xFF0F8A73),
                  openingStock: record?.openingStock['diesel'] ?? 0,
                  density: record?.density['diesel'] ?? 0,
                  price: record?.price['diesel'] ?? 0,
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
            onPressed: widget.busy ? null : _openDensityDialog,
            icon: widget.busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.opacity_rounded),
            label: Text(
              record?.isComplete == true ? 'Update Density' : 'Enter Density',
            ),
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

class _DensityOverviewCard extends StatelessWidget {
  const _DensityOverviewCard({
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
    final hasDensity = density > 0;
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
          _MetricRow(
            label: 'Density',
            value: hasDensity ? formatDensity(density) : 'Pending',
          ),
          _MetricRow(label: 'Price', value: formatPricePerLiter(price)),
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
    required this.hintText,
    this.autofocus = false,
    this.textInputAction,
    this.onSubmitted,
  });

  final String title;
  final Color accent;
  final double openingStock;
  final double price;
  final TextEditingController controller;
  final String hintText;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FD),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DialogInfoTile(
                  label: 'Opening stock',
                  value: formatLiters(openingStock),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DialogInfoTile(
                  label: 'Price',
                  value: formatPricePerLiter(price),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            autofocus: autofocus,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            inputFormatters: [
              TextInputFormatter.withFunction((oldValue, newValue) {
                final text = newValue.text;
                final onlyDigitsAndDots = text.runes.every(
                  (codeUnit) =>
                      (codeUnit >= 48 && codeUnit <= 57) || codeUnit == 46,
                );
                final dotCount = '.'.allMatches(text).length;
                if (!onlyDigitsAndDots || dotCount > 1) {
                  return oldValue;
                }
                return newValue;
              }),
            ],
            decoration: InputDecoration(
              labelText: '$title density',
              hintText: hintText,
              suffixText: 'kg/m3',
              filled: true,
              fillColor: Colors.white,
              prefixIcon: Icon(Icons.opacity_rounded, color: accent),
              helperText: 'Required',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFD7DEEF)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: accent, width: 1.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogInfoTile extends StatelessWidget {
  const _DialogInfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OneLineScaleText(
            label,
            style: const TextStyle(
              color: kClaySub,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          OneLineScaleText(
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
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4FB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OneLineScaleText(
            label,
            style: const TextStyle(
              color: kClaySub,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          OneLineScaleText(
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
    final updatedBy = record.updatedByName.trim().isNotEmpty
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
          if (updatedBy.isNotEmpty || record.updatedAt.trim().isNotEmpty)
            Text(
              'Last updated${updatedBy.isNotEmpty ? ' by $updatedBy' : ''}${record.updatedAt.trim().isNotEmpty ? ' on ${formatDateTimeLabel(record.updatedAt)}' : ''}',
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
