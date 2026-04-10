import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/inventory_service.dart';
import '../utils/formatters.dart';
import '../widgets/clay_widgets.dart';

class FuelPriceSettingsScreen extends StatefulWidget {
  const FuelPriceSettingsScreen({
    super.key,
    required this.canEdit,
    this.embedded = false,
    this.onBack,
  });

  final bool canEdit;
  final bool embedded;
  final VoidCallback? onBack;

  @override
  State<FuelPriceSettingsScreen> createState() =>
      _FuelPriceSettingsScreenState();
}

class _FuelPriceSettingsScreenState extends State<FuelPriceSettingsScreen> {
  final InventoryService _inventoryService = InventoryService();
  late Future<List<FuelPriceModel>> _future;
  List<FuelPriceModel> _draftPrices = const [];
  bool _seeded = false;
  bool _isEditing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _inventoryService.fetchPrices();
  }

  FuelPriceModel _clonePrice(FuelPriceModel price) {
    return price.copyWith(
      periods: price.periods.map((period) => period.copyWith()).toList(),
    );
  }

  void _ensureDraft(List<FuelPriceModel> prices) {
    final shouldReseed =
        !_seeded ||
        _draftPrices.length != prices.length ||
        _draftPrices.map((item) => item.fuelTypeId).join('|') !=
            prices.map((item) => item.fuelTypeId).join('|');
    if (!shouldReseed) return;
    _draftPrices = prices.map(_clonePrice).toList();
    _seeded = true;
  }

  Future<void> _reload() async {
    setState(() {
      _seeded = false;
      _future = _inventoryService.fetchPrices();
    });
    await _future;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _inventoryService.savePrices(_draftPrices);
      final saved = await _inventoryService.fetchPrices();
      if (!mounted) return;
      setState(() {
        _draftPrices = saved.map(_clonePrice).toList();
        _seeded = true;
        _isEditing = false;
        _future = Future<List<FuelPriceModel>>.value(saved);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fuel prices and history saved.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFB91C1C),
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _seeded = false;
      _future = _inventoryService.fetchPrices();
    });
  }

  Future<void> _openPriceHistory(FuelPriceModel price) async {
    final result = await Navigator.of(context).push<FuelPriceModel>(
      MaterialPageRoute<FuelPriceModel>(
        builder: (_) => _FuelPriceHistoryScreen(
          title: _prettyFuelLabel(price.fuelTypeId),
          initialPrice: _clonePrice(price),
          canEdit: widget.canEdit,
          startInEditMode: _isEditing,
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _draftPrices = _draftPrices
          .map((item) => item.fuelTypeId == result.fuelTypeId ? result : item)
          .toList();
    });
  }

  String _prettyFuelLabel(String fuelTypeId) {
    switch (fuelTypeId) {
      case 'two_t_oil':
        return '2T Oil';
      case 'petrol':
        return 'Petrol';
      case 'diesel':
        return 'Diesel';
      default:
        return fuelTypeId
            .split('_')
            .map(
              (part) => part.isEmpty
                  ? part
                  : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
            )
            .join(' ');
    }
  }

  String _periodLabel(FuelPricePeriodModel period) {
    final from =
        period.effectiveFrom.isEmpty ? 'Unknown' : formatDateLabel(period.effectiveFrom);
    final to =
        period.effectiveTo.isEmpty ? 'Ongoing' : formatDateLabel(period.effectiveTo);
    return '$from to $to';
  }

  String _optionalDateLabel(String raw, {String empty = 'Not set'}) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return empty;
    return formatDateLabel(trimmed);
  }

  Color _fuelColor(String fuelTypeId) {
    switch (fuelTypeId) {
      case 'petrol':
        return const Color(0xFF1298B8);
      case 'diesel':
        return const Color(0xFF2AA878);
      case 'two_t_oil':
        return const Color(0xFF7048A8);
      default:
        return const Color(0xFF4858C8);
    }
  }

  Widget _buildPriceCard(FuelPriceModel price) {
    final activePeriod =
        price.activePeriod ??
        FuelPricePeriodModel(
          effectiveFrom: price.effectiveFrom,
          effectiveTo: price.effectiveTo,
          costPrice: price.costPrice,
          sellingPrice: price.sellingPrice,
          updatedAt: price.updatedAt,
          updatedBy: price.updatedBy,
        );
    final color = _fuelColor(price.fuelTypeId);

    return ClayCard(
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.local_gas_station_rounded,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _prettyFuelLabel(price.fuelTypeId),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    color: kClayPrimary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _saving ? null : () => _openPriceHistory(price),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: kClayBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isEditing && widget.canEdit
                            ? Icons.edit_calendar_rounded
                            : Icons.history_rounded,
                        size: 15,
                        color: kClaySub,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isEditing && widget.canEdit
                            ? 'History & Edit'
                            : 'View History',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: kClaySub,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kClayBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _periodLabel(activePeriod),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: kClayPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      'From ${_optionalDateLabel(activePeriod.effectiveFrom)}',
                      style: const TextStyle(color: kClaySub, fontSize: 12),
                    ),
                    Text(
                      'To ${_optionalDateLabel(activePeriod.effectiveTo, empty: 'Ongoing')}',
                      style: const TextStyle(color: kClaySub, fontSize: 12),
                    ),
                    Text(
                      'Updated ${_optionalDateLabel(activePeriod.updatedAt)}',
                      style: const TextStyle(color: kClaySub, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _PriceMetric(
                        label: 'Cost price',
                        value: formatCurrency(activePeriod.costPrice),
                        accent: const Color(0xFF7C3AED),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PriceMetric(
                        label: 'Selling price',
                        value: formatCurrency(activePeriod.sellingPrice),
                        accent: const Color(0xFF2AA878),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.history_rounded, size: 14, color: kClaySub),
              const SizedBox(width: 6),
              Text(
                '${price.periods.length} period${price.periods.length == 1 ? '' : 's'} on record',
                style: const TextStyle(
                  color: kClaySub,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = FutureBuilder<List<FuelPriceModel>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ColoredBox(
            color: kClayBg,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return ColoredBox(
            color: kClayBg,
            child: Center(
              child: Text(
                snapshot.error.toString().replaceFirst('Exception: ', ''),
              ),
            ),
          );
        }
        final prices = snapshot.data ?? const <FuelPriceModel>[];
        _ensureDraft(prices);

        return RefreshIndicator(
          onRefresh: _reload,
          child: ColoredBox(
            color: kClayBg,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                if (widget.embedded)
                  ClaySubHeader(
                    title: 'Fuel Prices',
                    onBack: widget.onBack,
                    trailing: widget.canEdit
                        ? _EditTogglePill(
                            isEditing: _isEditing,
                            disabled: _draftPrices.isEmpty || _saving,
                            onTap: () {
                              if (_isEditing) {
                                _cancelEditing();
                              } else {
                                setState(() => _isEditing = true);
                              }
                            },
                          )
                        : null,
                  ),

                // ── Header info ────────────────────────────────────
                ClayCard(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Fuel Price History',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: kClayPrimary,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Each fuel supports editable price periods with from and to dates.',
                              style: TextStyle(color: kClaySub, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: kClayBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _isEditing ? 'Editing' : 'View only',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _isEditing
                                ? const Color(0xFF1A3A7A)
                                : const Color(0xFF2AA878),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                ..._draftPrices.map(_buildPriceCard),

                if (widget.canEdit && _isEditing)
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Saving...' : 'Save Fuel Prices'),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (widget.embedded) return content;

    return Scaffold(
      backgroundColor: kClayBg,
      appBar: AppBar(
        backgroundColor: kClayBg,
        title: const Text('Fuel Prices'),
        actions: [
          if (widget.canEdit)
            FutureBuilder<List<FuelPriceModel>>(
              future: _future,
              builder: (context, snapshot) {
                final prices = snapshot.data ?? const <FuelPriceModel>[];
                return TextButton(
                  onPressed: prices.isEmpty || _saving
                      ? null
                      : () {
                          if (_isEditing) {
                            _cancelEditing();
                          } else {
                            setState(() => _isEditing = true);
                          }
                        },
                  child: Text(_isEditing ? 'Cancel' : 'Edit'),
                );
              },
            ),
        ],
      ),
      body: content,
    );
  }
}

// ─── Edit toggle pill ────────────────────────────────────────────────────────
class _EditTogglePill extends StatelessWidget {
  const _EditTogglePill({
    required this.isEditing,
    required this.onTap,
    this.disabled = false,
  });
  final bool isEditing;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFB8C0DC).withValues(alpha: 0.65),
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
        child: Text(
          isEditing ? 'Cancel' : 'Edit',
          style: TextStyle(
            color: disabled
                ? kClaySub
                : isEditing
                    ? const Color(0xFFCE5828)
                    : kClayPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ─── Price metric box ────────────────────────────────────────────────────────
class _PriceMetric extends StatelessWidget {
  const _PriceMetric({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              color: kClaySub,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Price history tile ──────────────────────────────────────────────────────
class _PriceHistoryTile extends StatelessWidget {
  const _PriceHistoryTile({
    required this.title,
    required this.effectiveFrom,
    required this.effectiveTo,
    required this.updatedAt,
    required this.costPrice,
    required this.sellingPrice,
    required this.isCurrent,
  });

  final String title;
  final String effectiveFrom;
  final String effectiveTo;
  final String updatedAt;
  final double costPrice;
  final double sellingPrice;
  final bool isCurrent;

  String _formatOptionalDate(String raw, {String empty = 'Not set'}) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return empty;
    return formatDateLabel(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCurrent
            ? const Color(0xFF1A3A7A).withValues(alpha: 0.05)
            : kClayBg,
        borderRadius: BorderRadius.circular(16),
        border: isCurrent
            ? Border.all(
                color: const Color(0xFF1A3A7A).withValues(alpha: 0.20),
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: kClayPrimary,
                  ),
                ),
              ),
              if (isCurrent)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A3A7A).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Current',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: Color(0xFF1A3A7A),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'From ${_formatOptionalDate(effectiveFrom)}',
                style: const TextStyle(color: kClaySub, fontSize: 12),
              ),
              Text(
                'To ${_formatOptionalDate(effectiveTo, empty: 'Ongoing')}',
                style: const TextStyle(color: kClaySub, fontSize: 12),
              ),
              Text(
                'Updated ${_formatOptionalDate(updatedAt)}',
                style: const TextStyle(color: kClaySub, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Cost ${formatCurrency(costPrice)}   Selling ${formatCurrency(sellingPrice)}',
            style: const TextStyle(
              color: kClayPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Fuel price history screen (full page) ────────────────────────────────────
class _FuelPriceHistoryScreen extends StatefulWidget {
  const _FuelPriceHistoryScreen({
    required this.title,
    required this.initialPrice,
    required this.canEdit,
    this.startInEditMode = false,
  });

  final String title;
  final FuelPriceModel initialPrice;
  final bool canEdit;
  final bool startInEditMode;

  @override
  State<_FuelPriceHistoryScreen> createState() =>
      _FuelPriceHistoryScreenState();
}

class _FuelPriceHistoryScreenState extends State<_FuelPriceHistoryScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final List<_EditablePricePeriod> _periods;
  late bool _isEditing;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.startInEditMode && widget.canEdit;
    final source = widget.initialPrice.periods.isNotEmpty
        ? widget.initialPrice.periods
        : [
            FuelPricePeriodModel(
              effectiveFrom: widget.initialPrice.effectiveFrom,
              effectiveTo: widget.initialPrice.effectiveTo,
              costPrice: widget.initialPrice.costPrice,
              sellingPrice: widget.initialPrice.sellingPrice,
              updatedAt: widget.initialPrice.updatedAt,
              updatedBy: widget.initialPrice.updatedBy,
            ),
          ];
    _periods = source
        .map((period) => _EditablePricePeriod.fromModel(period))
        .toList();
  }

  @override
  void dispose() {
    for (final period in _periods) {
      period.dispose();
    }
    super.dispose();
  }

  String _todayKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  Future<void> _pickDate({
    required _EditablePricePeriod period,
    required bool isFrom,
  }) async {
    final raw = isFrom ? period.effectiveFrom : period.effectiveTo;
    final initial = DateTime.tryParse(raw) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
      helpText: isFrom ? 'Select start date' : 'Select end date',
    );
    if (picked == null) return;
    final month = picked.month.toString().padLeft(2, '0');
    final day = picked.day.toString().padLeft(2, '0');
    setState(() {
      if (isFrom) {
        period.effectiveFrom = '${picked.year}-$month-$day';
      } else {
        period.effectiveTo = '${picked.year}-$month-$day';
      }
    });
  }

  String? _validatePeriod(_EditablePricePeriod period) {
    if (period.effectiveFrom.isEmpty) return 'From date is required.';
    final cost = double.tryParse(period.costController.text.trim());
    if (cost == null || cost < 0) return 'Enter a valid cost price.';
    final selling = double.tryParse(period.sellingController.text.trim());
    if (selling == null || selling < 0) return 'Enter a valid selling price.';
    if (period.effectiveTo.isNotEmpty &&
        period.effectiveTo.compareTo(period.effectiveFrom) < 0) {
      return 'To date cannot be before from date.';
    }
    return null;
  }

  String? _validateAllPeriods() {
    final normalized = _periods
        .map(
          (period) => FuelPricePeriodModel(
            effectiveFrom: period.effectiveFrom,
            effectiveTo: period.effectiveTo,
            costPrice: double.tryParse(period.costController.text.trim()) ?? 0,
            sellingPrice:
                double.tryParse(period.sellingController.text.trim()) ?? 0,
            updatedAt: period.updatedAt,
            updatedBy: period.updatedBy,
          ),
        )
        .toList()
      ..sort(
        (left, right) => left.effectiveFrom.compareTo(right.effectiveFrom),
      );

    for (var index = 1; index < normalized.length; index += 1) {
      final previous = normalized[index - 1];
      final current = normalized[index];
      if (previous.effectiveTo.isEmpty ||
          current.effectiveFrom.compareTo(previous.effectiveTo) <= 0) {
        return 'Price periods cannot overlap. Close the previous period before starting the next one.';
      }
    }
    return null;
  }

  void _addPeriod() {
    setState(() {
      _periods.add(
        _EditablePricePeriod(
          effectiveFrom: _todayKey(),
          effectiveTo: '',
          costController: TextEditingController(text: '0.00'),
          sellingController: TextEditingController(text: '0.00'),
          updatedAt: '',
          updatedBy: '',
        ),
      );
    });
  }

  void _removePeriod(int index) {
    if (_periods.length == 1) return;
    final removed = _periods.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  void _save() {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;
    final overlapError = _validateAllPeriods();
    if (overlapError != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(overlapError)));
      return;
    }

    final nextPeriods = _periods
        .map(
          (period) => FuelPricePeriodModel(
            effectiveFrom: period.effectiveFrom,
            effectiveTo: period.effectiveTo,
            costPrice: double.tryParse(period.costController.text.trim()) ?? 0,
            sellingPrice:
                double.tryParse(period.sellingController.text.trim()) ?? 0,
            updatedAt: period.updatedAt,
            updatedBy: period.updatedBy,
          ),
        )
        .toList()
      ..sort(
        (left, right) => left.effectiveFrom.compareTo(right.effectiveFrom),
      );

    final current = FuelPriceModel(
              fuelTypeId: widget.initialPrice.fuelTypeId,
              costPrice: widget.initialPrice.costPrice,
              sellingPrice: widget.initialPrice.sellingPrice,
              updatedAt: widget.initialPrice.updatedAt,
              updatedBy: widget.initialPrice.updatedBy,
              periods: nextPeriods,
            ).activePeriod ??
        nextPeriods.last;

    Navigator.of(context).pop(
      widget.initialPrice.copyWith(
        costPrice: current.costPrice,
        sellingPrice: current.sellingPrice,
        effectiveFrom: current.effectiveFrom,
        effectiveTo: current.effectiveTo,
        periods: nextPeriods,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final periods = [
      ..._periods.map(
        (period) => FuelPricePeriodModel(
          effectiveFrom: period.effectiveFrom,
          effectiveTo: period.effectiveTo,
          costPrice: double.tryParse(period.costController.text.trim()) ?? 0,
          sellingPrice:
              double.tryParse(period.sellingController.text.trim()) ?? 0,
          updatedAt: period.updatedAt,
          updatedBy: period.updatedBy,
        ),
      ),
    ]..sort((left, right) => right.effectiveFrom.compareTo(left.effectiveFrom));

    final current = periods.isEmpty
        ? null
        : FuelPriceModel(
            fuelTypeId: widget.initialPrice.fuelTypeId,
            costPrice: widget.initialPrice.costPrice,
            sellingPrice: widget.initialPrice.sellingPrice,
            updatedAt: widget.initialPrice.updatedAt,
            updatedBy: widget.initialPrice.updatedBy,
            periods: periods,
          ).activePeriod;

    return Scaffold(
      backgroundColor: kClayBg,
      appBar: AppBar(
        backgroundColor: kClayBg,
        title: Text('${widget.title} Price History'),
        actions: [
          if (widget.canEdit)
            TextButton(
              onPressed: () => setState(() => _isEditing = !_isEditing),
              child: Text(_isEditing ? 'View' : 'Edit'),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  24 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
                  children: [
                    // ── Hero info card ─────────────────────────────
                    ClayCard(
                      margin: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: kClayPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _isEditing
                                ? 'Edit each price period below. This keeps long history manageable.'
                                : 'All saved price periods for this fuel.',
                            style: const TextStyle(
                              color: kClaySub,
                              height: 1.4,
                            ),
                          ),
                          if (current != null) ...[
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _PriceMetric(
                                    label: 'Current cost',
                                    value: formatCurrency(current.costPrice),
                                    accent: const Color(0xFF7C3AED),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _PriceMetric(
                                    label: 'Current selling',
                                    value: formatCurrency(current.sellingPrice),
                                    accent: const Color(0xFF2AA878),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    if (_isEditing)
                      Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          children: [
                            ..._periods.asMap().entries.map((entry) {
                              final index = entry.key;
                              final period = entry.value;
                              return ClayCard(
                                margin: const EdgeInsets.only(bottom: 14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Period ${index + 1}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: kClayPrimary,
                                            ),
                                          ),
                                        ),
                                        if (_periods.length > 1)
                                          IconButton(
                                            onPressed: () =>
                                                _removePeriod(index),
                                            icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              color: Color(0xFFCE5828),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () => _pickDate(
                                              period: period,
                                              isFrom: true,
                                            ),
                                            icon: const Icon(
                                              Icons.calendar_month_rounded,
                                            ),
                                            label: Text(
                                              period.effectiveFrom.isEmpty
                                                  ? 'From date'
                                                  : formatDateLabel(
                                                      period.effectiveFrom,
                                                    ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () => _pickDate(
                                              period: period,
                                              isFrom: false,
                                            ),
                                            icon: const Icon(
                                              Icons.event_available_rounded,
                                            ),
                                            label: Text(
                                              period.effectiveTo.isEmpty
                                                  ? 'To: Ongoing'
                                                  : formatDateLabel(
                                                      period.effectiveTo,
                                                    ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    if (period.effectiveTo.isNotEmpty)
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: TextButton(
                                          onPressed: () {
                                            setState(() {
                                              period.effectiveTo = '';
                                            });
                                          },
                                          child: const Text('Clear end date'),
                                        ),
                                      ),
                                    if (period.updatedAt.trim().isNotEmpty)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 8),
                                        child: Text(
                                          'Last updated ${formatDateLabel(period.updatedAt)}',
                                          style: const TextStyle(
                                            color: kClaySub,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    TextFormField(
                                      controller: period.costController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                      decoration: const InputDecoration(
                                        labelText: 'Cost price',
                                        filled: true,
                                        fillColor: kClayBg,
                                      ),
                                      validator: (_) =>
                                          _validatePeriod(period),
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: period.sellingController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                      decoration: const InputDecoration(
                                        labelText: 'Selling price',
                                        filled: true,
                                        fillColor: kClayBg,
                                      ),
                                      validator: (_) =>
                                          _validatePeriod(period),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                onPressed: _addPeriod,
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Add Price Period'),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Column(
                        children: periods
                            .map(
                              (period) => _PriceHistoryTile(
                                title:
                                    '${_formatHistoryDate(period.effectiveFrom)} to ${_formatHistoryDate(period.effectiveTo, empty: 'Ongoing')}',
                                effectiveFrom: period.effectiveFrom,
                                effectiveTo: period.effectiveTo,
                                updatedAt: period.updatedAt,
                                costPrice: period.costPrice,
                                sellingPrice: period.sellingPrice,
                                isCurrent: current != null &&
                                    period.effectiveFrom ==
                                        current.effectiveFrom &&
                                    period.effectiveTo == current.effectiveTo &&
                                    period.costPrice == current.costPrice &&
                                    period.sellingPrice == current.sellingPrice,
                              ),
                            )
                            .toList(),
                      ),
                  ],
                ),
              ),
            ),
            if (_isEditing)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _save,
                        child: const Text('Save History'),
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

  String _formatHistoryDate(String raw, {String empty = 'Not set'}) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return empty;
    return formatDateLabel(trimmed);
  }
}

class _EditablePricePeriod {
  _EditablePricePeriod({
    required this.effectiveFrom,
    required this.effectiveTo,
    required this.costController,
    required this.sellingController,
    required this.updatedAt,
    required this.updatedBy,
  });

  factory _EditablePricePeriod.fromModel(FuelPricePeriodModel period) {
    return _EditablePricePeriod(
      effectiveFrom: period.effectiveFrom,
      effectiveTo: period.effectiveTo,
      costController: TextEditingController(
        text: period.costPrice.toStringAsFixed(2),
      ),
      sellingController: TextEditingController(
        text: period.sellingPrice.toStringAsFixed(2),
      ),
      updatedAt: period.updatedAt,
      updatedBy: period.updatedBy,
    );
  }

  String effectiveFrom;
  String effectiveTo;
  final TextEditingController costController;
  final TextEditingController sellingController;
  final String updatedAt;
  final String updatedBy;

  void dispose() {
    costController.dispose();
    sellingController.dispose();
  }
}
