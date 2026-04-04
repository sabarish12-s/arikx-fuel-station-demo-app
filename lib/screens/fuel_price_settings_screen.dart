import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/inventory_service.dart';
import '../utils/formatters.dart';

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
    if (!shouldReseed) {
      return;
    }
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
    setState(() {
      _saving = true;
    });
    try {
      final saved = await _inventoryService.savePrices(_draftPrices);
      if (!mounted) {
        return;
      }
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
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFB91C1C),
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _seeded = false;
      _future = _inventoryService.fetchPrices();
    });
  }

  Future<void> _editPriceHistory(FuelPriceModel price) async {
    final result = await showDialog<FuelPriceModel>(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => _FuelPriceEditorDialog(
            title: _prettyFuelLabel(price.fuelTypeId),
            initialPrice: _clonePrice(price),
          ),
    );
    if (!mounted || result == null) {
      return;
    }
    setState(() {
      _draftPrices =
          _draftPrices
              .map(
                (item) => item.fuelTypeId == result.fuelTypeId ? result : item,
              )
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
              (part) =>
                  part.isEmpty
                      ? part
                      : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
            )
            .join(' ');
    }
  }

  String _periodLabel(FuelPricePeriodModel period) {
    final from =
        period.effectiveFrom.isEmpty
            ? 'Unknown'
            : formatDateLabel(period.effectiveFrom);
    final to =
        period.effectiveTo.isEmpty
            ? 'Ongoing'
            : formatDateLabel(period.effectiveTo);
    return '$from to $to';
  }

  String _optionalDateLabel(String raw, {String empty = 'Not set'}) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return empty;
    }
    return formatDateLabel(trimmed);
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
    final periods = [...price.periods].reversed.toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
                  _prettyFuelLabel(price.fuelTypeId),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: Color(0xFF293340),
                  ),
                ),
              ),
              if (_isEditing && widget.canEdit)
                OutlinedButton.icon(
                  onPressed: _saving ? null : () => _editPriceHistory(price),
                  icon: const Icon(Icons.edit_calendar_rounded),
                  label: const Text('Edit History'),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current active price',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF55606E),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _periodLabel(activePeriod),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF293340),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  children: [
                    Text(
                      'From ${_optionalDateLabel(activePeriod.effectiveFrom)}',
                      style: const TextStyle(color: Color(0xFF55606E)),
                    ),
                    Text(
                      "To ${_optionalDateLabel(activePeriod.effectiveTo, empty: 'Ongoing')}",
                      style: const TextStyle(color: Color(0xFF55606E)),
                    ),
                    Text(
                      'Updated ${_optionalDateLabel(activePeriod.updatedAt)}',
                      style: const TextStyle(color: Color(0xFF55606E)),
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PriceMetric(
                        label: 'Selling price',
                        value: formatCurrency(activePeriod.sellingPrice),
                        accent: const Color(0xFF0F9D58),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Price history',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF293340),
                  ),
                ),
              ),
              Text(
                '${price.periods.length} period${price.periods.length == 1 ? '' : 's'}',
                style: const TextStyle(color: Color(0xFF55606E)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...periods.map(
            (period) => _PriceHistoryTile(
              title: _periodLabel(period),
              effectiveFrom: period.effectiveFrom,
              effectiveTo: period.effectiveTo,
              updatedAt: period.updatedAt,
              costPrice: period.costPrice,
              sellingPrice: period.sellingPrice,
              isCurrent:
                  period.effectiveFrom == activePeriod.effectiveFrom &&
                  period.effectiveTo == activePeriod.effectiveTo &&
                  period.costPrice == activePeriod.costPrice &&
                  period.sellingPrice == activePeriod.sellingPrice,
            ),
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
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('${snapshot.error}'));
        }
        final prices = snapshot.data ?? const <FuelPriceModel>[];
        _ensureDraft(prices);

        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              if (widget.embedded)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: widget.onBack,
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const Expanded(
                        child: Text(
                          'Fuel Price Settings',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF293340),
                          ),
                        ),
                      ),
                      if (widget.canEdit)
                        TextButton(
                          onPressed:
                              _draftPrices.isEmpty || _saving
                                  ? null
                                  : () {
                                    if (_isEditing) {
                                      _cancelEditing();
                                    } else {
                                      setState(() {
                                        _isEditing = true;
                                      });
                                    }
                                  },
                          child: Text(_isEditing ? 'Cancel' : 'Edit'),
                        ),
                    ],
                  ),
                ),
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fuel Price History',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Each fuel now supports editable price periods with from and to dates.',
                            style: TextStyle(color: Color(0xFF55606E)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            _isEditing
                                ? const Color(0xFFE0E7FF)
                                : const Color(0xFFE5F7EE),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _isEditing ? 'Editing' : 'View only',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color:
                              _isEditing
                                  ? const Color(0xFF1E40AF)
                                  : const Color(0xFF047857),
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
                  child: Text(
                    _saving ? 'Saving...' : 'Save All Price Settings',
                  ),
                ),
            ],
          ),
        );
      },
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fuel Price Settings'),
        actions: [
          if (widget.canEdit)
            FutureBuilder<List<FuelPriceModel>>(
              future: _future,
              builder: (context, snapshot) {
                final prices = snapshot.data ?? const <FuelPriceModel>[];
                return TextButton(
                  onPressed:
                      prices.isEmpty || _saving
                          ? null
                          : () {
                            if (_isEditing) {
                              _cancelEditing();
                            } else {
                              setState(() {
                                _isEditing = true;
                              });
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF55606E),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

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
    if (trimmed.isEmpty) {
      return empty;
    }
    return formatDateLabel(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isCurrent
                  ? const Color(0xFF1E5CBA).withValues(alpha: 0.25)
                  : Colors.transparent,
        ),
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
                    color: Color(0xFF293340),
                  ),
                ),
              ),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E7FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Current',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E40AF),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              Text(
                'From ${_formatOptionalDate(effectiveFrom)}',
                style: const TextStyle(color: Color(0xFF55606E)),
              ),
              Text(
                "To ${_formatOptionalDate(effectiveTo, empty: 'Ongoing')}",
                style: const TextStyle(color: Color(0xFF55606E)),
              ),
              Text(
                'Updated ${_formatOptionalDate(updatedAt)}',
                style: const TextStyle(color: Color(0xFF55606E)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Cost ${formatCurrency(costPrice)}   Selling ${formatCurrency(sellingPrice)}',
            style: const TextStyle(color: Color(0xFF55606E)),
          ),
        ],
      ),
    );
  }
}

class _FuelPriceEditorDialog extends StatefulWidget {
  const _FuelPriceEditorDialog({
    required this.title,
    required this.initialPrice,
  });

  final String title;
  final FuelPriceModel initialPrice;

  @override
  State<_FuelPriceEditorDialog> createState() => _FuelPriceEditorDialogState();
}

class _FuelPriceEditorDialogState extends State<_FuelPriceEditorDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final List<_EditablePricePeriod> _periods;

  @override
  void initState() {
    super.initState();
    final source =
        widget.initialPrice.periods.isNotEmpty
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
    _periods =
        source.map((period) => _EditablePricePeriod.fromModel(period)).toList();
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
    if (picked == null) {
      return;
    }
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
    if (period.effectiveFrom.isEmpty) {
      return 'From date is required.';
    }
    final cost = double.tryParse(period.costController.text.trim());
    if (cost == null || cost < 0) {
      return 'Enter a valid cost price.';
    }
    final selling = double.tryParse(period.sellingController.text.trim());
    if (selling == null || selling < 0) {
      return 'Enter a valid selling price.';
    }
    if (period.effectiveTo.isNotEmpty &&
        period.effectiveTo.compareTo(period.effectiveFrom) < 0) {
      return 'To date cannot be before from date.';
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
    if (_periods.length == 1) {
      return;
    }
    final removed = _periods.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  void _save() {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    final nextPeriods =
        _periods
            .map(
              (period) => FuelPricePeriodModel(
                effectiveFrom: period.effectiveFrom,
                effectiveTo: period.effectiveTo,
                costPrice:
                    double.tryParse(period.costController.text.trim()) ?? 0,
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

    final current =
        nextPeriods.where((period) => period.effectiveTo.isEmpty).isNotEmpty
            ? nextPeriods.where((period) => period.effectiveTo.isEmpty).last
            : nextPeriods.last;

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
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.title} Price History',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF293340),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Edit every price period with its start and end dates.',
                          style: TextStyle(color: Color(0xFF55606E)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  20 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    children: [
                      ..._periods.asMap().entries.map((entry) {
                        final index = entry.key;
                        final period = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FF),
                            borderRadius: BorderRadius.circular(18),
                          ),
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
                                        color: Color(0xFF293340),
                                      ),
                                    ),
                                  ),
                                  if (_periods.length > 1)
                                    IconButton(
                                      onPressed: () => _removePeriod(index),
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed:
                                          () => _pickDate(
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
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed:
                                          () => _pickDate(
                                            period: period,
                                            isFrom: false,
                                          ),
                                      icon: const Icon(
                                        Icons.event_available_rounded,
                                      ),
                                      label: Text(
                                        period.effectiveTo.isEmpty
                                            ? 'To date: Ongoing'
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
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    'Last updated ${formatDateLabel(period.updatedAt)}',
                                    style: const TextStyle(
                                      color: Color(0xFF55606E),
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
                                  fillColor: Colors.white,
                                ),
                                validator: (_) => _validatePeriod(period),
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
                                  fillColor: Colors.white,
                                ),
                                validator: (_) => _validatePeriod(period),
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
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
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
