import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/inventory_service.dart';
import '../services/report_export_service.dart';
import '../utils/formatters.dart';
import '../utils/user_facing_errors.dart';
import '../widgets/clay_widgets.dart';
import '../widgets/responsive_text.dart';

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
  final TextEditingController _effectiveDateController =
      TextEditingController();
  final Map<String, _FuelRateDraft> _drafts = {};
  late Future<List<FuelPriceModel>> _future;
  bool _seeded = false;
  bool _saving = false;

  static const List<String> _fuelOrder = ['petrol', 'diesel', 'two_t_oil'];

  @override
  void initState() {
    super.initState();
    _effectiveDateController.text = DateTime.now()
        .toIso8601String()
        .split('T')
        .first;
    _future = _inventoryService.fetchPrices();
  }

  @override
  void dispose() {
    _effectiveDateController.dispose();
    for (final draft in _drafts.values) {
      draft.dispose();
    }
    super.dispose();
  }

  List<FuelPriceModel> _sortPrices(List<FuelPriceModel> prices) {
    final order = {
      for (var i = 0; i < _fuelOrder.length; i++) _fuelOrder[i]: i,
    };
    return [...prices]..sort(
      (left, right) => (order[left.fuelTypeId] ?? 99).compareTo(
        order[right.fuelTypeId] ?? 99,
      ),
    );
  }

  void _seedDrafts(List<FuelPriceModel> prices) {
    final sorted = _sortPrices(prices);
    final key = sorted.map((item) => item.fuelTypeId).join('|');
    final currentKey = _drafts.keys.join('|');
    if (_seeded && key == currentKey) return;

    for (final draft in _drafts.values) {
      draft.dispose();
    }
    _drafts.clear();

    for (final price in sorted) {
      final active =
          price.activePeriod ??
          FuelPricePeriodModel(
            effectiveFrom: price.effectiveFrom,
            effectiveTo: price.effectiveTo,
            costPrice: price.costPrice,
            sellingPrice: price.sellingPrice,
            updatedAt: price.updatedAt,
            updatedBy: price.updatedBy,
          );
      _drafts[price.fuelTypeId] = _FuelRateDraft(
        costPrice: active.costPrice,
        sellingPrice: active.sellingPrice,
      );
    }
    _seeded = true;
  }

  Future<void> _reload() async {
    setState(() {
      _seeded = false;
      _future = _inventoryService.fetchPrices(forceRefresh: true);
    });
    await _future;
  }

  Future<void> _pickEffectiveDate() async {
    final initialDate =
        DateTime.tryParse(_effectiveDateController.text.trim()) ??
        DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    _effectiveDateController.text = _dateKey(picked);
  }

  Future<bool> _save(List<FuelPriceModel> prices) async {
    final effectiveDate = _effectiveDateController.text.trim();
    if (DateTime.tryParse(effectiveDate) == null) {
      _showError('Select a valid effective date.');
      return false;
    }

    final updatedPrices = <FuelPriceModel>[];
    for (final price in _sortPrices(prices)) {
      final draft = _drafts[price.fuelTypeId];
      final cost = double.tryParse(draft?.costController.text.trim() ?? '');
      final selling = double.tryParse(
        draft?.sellingController.text.trim() ?? '',
      );
      if (cost == null || cost < 0 || selling == null || selling < 0) {
        _showError('Enter valid non-negative rates for all fuels.');
        return false;
      }
      updatedPrices.add(
        _priceWithNewPeriod(
          price: price,
          effectiveDate: effectiveDate,
          costPrice: cost,
          sellingPrice: selling,
        ),
      );
    }

    setState(() => _saving = true);
    try {
      final saved = await _inventoryService.savePrices(updatedPrices);
      if (!mounted) return false;
      setState(() {
        _seeded = false;
        _future = Future<List<FuelPriceModel>>.value(saved);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Fuel rates saved.')));
      return true;
    } catch (error) {
      if (!mounted) return false;
      _showError(userFacingErrorMessage(error));
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openUpdateDialog(List<FuelPriceModel> prices) async {
    _seeded = false;
    _seedDrafts(prices);
    var saving = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 24,
              ),
              titlePadding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
              contentPadding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
              actionsPadding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text(
                'Update Fuel Rates',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: saving ? null : _pickEffectiveDate,
                        child: AbsorbPointer(
                          child: TextField(
                            controller: _effectiveDateController,
                            enabled: !saving,
                            decoration: InputDecoration(
                              labelText: 'Effective date',
                              prefixIcon: const Icon(Icons.event_rounded),
                              suffixIcon: const Icon(Icons.calendar_today),
                              filled: true,
                              fillColor: kClayBg,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      ..._sortPrices(prices).map((price) {
                        final draft = _drafts[price.fuelTypeId];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: kClayBg,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFDDE2F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: _fuelColor(
                                        price.fuelTypeId,
                                      ).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Container(
                                        width: 9,
                                        height: 9,
                                        decoration: BoxDecoration(
                                          color: _fuelColor(price.fuelTypeId),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _prettyFuelLabel(price.fuelTypeId),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: kClayPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _RateField(
                                      label: 'Cost',
                                      controller: draft?.costController,
                                      enabled: !saving,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _RateField(
                                      label: 'Sell',
                                      controller: draft?.sellingController,
                                      enabled: !saving,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          setDialogState(() => saving = true);
                          final saved = await _save(prices);
                          if (!context.mounted) return;
                          setDialogState(() => saving = false);
                          if (saved && dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        },
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(saving ? 'Saving...' : 'Save Fuel Rates'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openHistoryPage() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _FuelPriceHistoryScreen(canEdit: widget.canEdit),
      ),
    );
    if (mounted) await _reload();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFB91C1C),
        content: Text(message),
      ),
    );
  }

  FuelPriceModel _priceWithNewPeriod({
    required FuelPriceModel price,
    required String effectiveDate,
    required double costPrice,
    required double sellingPrice,
  }) {
    final basePeriods = price.periods.isEmpty
        ? [
            FuelPricePeriodModel(
              effectiveFrom: price.effectiveFrom.isEmpty
                  ? effectiveDate
                  : price.effectiveFrom,
              effectiveTo: price.effectiveTo,
              costPrice: price.costPrice,
              sellingPrice: price.sellingPrice,
              updatedAt: price.updatedAt,
              updatedBy: price.updatedBy,
            ),
          ]
        : price.periods.map((item) => item.copyWith()).toList();

    final periods =
        basePeriods
            .where(
              (period) =>
                  period.isDeleted || period.effectiveFrom != effectiveDate,
            )
            .map((period) {
              if (period.isDeleted) {
                return period;
              }
              if (period.effectiveFrom.compareTo(effectiveDate) < 0 &&
                  (period.effectiveTo.isEmpty ||
                      period.effectiveTo.compareTo(effectiveDate) >= 0)) {
                return period.copyWith(
                  effectiveTo: _previousDateKey(effectiveDate),
                );
              }
              return period;
            })
            .toList()
          ..sort(
            (left, right) => left.effectiveFrom.compareTo(right.effectiveFrom),
          );

    final nextPeriod = periods
        .where(
          (period) =>
              !period.isDeleted &&
              period.effectiveFrom.compareTo(effectiveDate) > 0,
        )
        .cast<FuelPricePeriodModel?>()
        .firstWhere((_) => true, orElse: () => null);
    final newPeriod = FuelPricePeriodModel(
      effectiveFrom: effectiveDate,
      effectiveTo: nextPeriod == null
          ? ''
          : _previousDateKey(nextPeriod.effectiveFrom),
      costPrice: costPrice,
      sellingPrice: sellingPrice,
      updatedAt: '',
      updatedBy: '',
    );

    final nextPeriods = [
      ...periods,
      newPeriod,
    ]..sort((left, right) => left.effectiveFrom.compareTo(right.effectiveFrom));
    final active = FuelPriceModel(
      fuelTypeId: price.fuelTypeId,
      costPrice: price.costPrice,
      sellingPrice: price.sellingPrice,
      updatedAt: price.updatedAt,
      updatedBy: price.updatedBy,
      periods: nextPeriods,
    ).activePeriod;

    return price.copyWith(
      costPrice: active?.costPrice ?? costPrice,
      sellingPrice: active?.sellingPrice ?? sellingPrice,
      effectiveFrom: active?.effectiveFrom ?? effectiveDate,
      effectiveTo: active?.effectiveTo ?? '',
      periods: nextPeriods,
    );
  }

  List<_FuelPriceSet> _buildHistorySets(
    List<FuelPriceModel> prices, {
    required bool deleted,
  }) {
    final grouped = <String, Map<String, FuelPricePeriodModel>>{};
    for (final price in prices) {
      final periods = price.periods.isEmpty
          ? [
              FuelPricePeriodModel(
                effectiveFrom: price.effectiveFrom,
                effectiveTo: price.effectiveTo,
                costPrice: price.costPrice,
                sellingPrice: price.sellingPrice,
                updatedAt: price.updatedAt,
                updatedBy: price.updatedBy,
              ),
            ]
          : price.periods;
      for (final period in periods) {
        if (period.effectiveFrom.trim().isEmpty) continue;
        if (period.isDeleted != deleted) continue;
        grouped.putIfAbsent(period.effectiveFrom, () => {});
        grouped[period.effectiveFrom]![price.fuelTypeId] = period;
      }
    }

    return grouped.entries
        .map(
          (entry) =>
              _FuelPriceSet(effectiveDate: entry.key, prices: entry.value),
        )
        .toList()
      ..sort(
        (left, right) => right.effectiveDate.compareTo(left.effectiveDate),
      );
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _previousDateKey(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return _dateKey(parsed.subtract(const Duration(days: 1)));
  }

  String _displayTimestamp(String raw) {
    final trimmed = raw.trim();
    return trimmed.isEmpty ? 'Unknown time' : formatDateTimeLabel(trimmed);
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

  Widget _buildCurrentRates(List<FuelPriceModel> prices) {
    final sortedPrices = _sortPrices(prices);
    return ClayCard(
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Current Fuel Rates',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: kClayPrimary,
                  ),
                ),
              ),
              if (widget.canEdit)
                FilledButton(
                  onPressed: prices.isEmpty || _saving
                      ? null
                      : () => _openUpdateDialog(prices),
                  child: const Text('Update Fuel Rates'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Active selling and cost rates used for entries.',
            style: TextStyle(color: kClaySub, height: 1.4),
          ),
          const SizedBox(height: 14),
          if (sortedPrices.isEmpty)
            const Text(
              'No fuel rates configured yet.',
              style: TextStyle(color: kClaySub),
            )
          else
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              decoration: BoxDecoration(
                color: kClayBg,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  const _RateTableHeader(),
                  const SizedBox(height: 8),
                  ...List.generate(sortedPrices.length, (index) {
                    final price = sortedPrices[index];
                    final active = price.activePeriod;
                    return Column(
                      children: [
                        _RateSummaryRow(
                          title: _prettyFuelLabel(price.fuelTypeId),
                          color: _fuelColor(price.fuelTypeId),
                          effectiveDate:
                              active?.effectiveFrom ?? price.effectiveFrom,
                          costPrice: active?.costPrice ?? price.costPrice,
                          sellingPrice:
                              active?.sellingPrice ?? price.sellingPrice,
                        ),
                        if (index != sortedPrices.length - 1)
                          const Divider(height: 14, color: Color(0xFFDDE2F0)),
                      ],
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLatestHistory(List<_FuelPriceSet> sets) {
    final latest = sets.isEmpty ? null : sets.first;
    return ClayCard(
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Latest Fuel Rate History',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: kClayPrimary,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _openHistoryPage,
                icon: const Icon(Icons.history_rounded),
                label: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Showing the newest fuel rate set here. Open all history for filters, sorting, downloads, and deleted records.',
            style: TextStyle(color: kClaySub, height: 1.4),
          ),
          const SizedBox(height: 14),
          if (latest == null)
            const Text(
              'No fuel rate history yet.',
              style: TextStyle(color: kClaySub),
            )
          else
            _FuelPriceSetCard(
              set: latest,
              fuelOrder: _fuelOrder,
              labelForFuel: _prettyFuelLabel,
              displayTimestamp: _displayTimestamp,
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
        if (snapshot.connectionState != ConnectionState.done &&
            !snapshot.hasData) {
          return const ColoredBox(
            color: kClayBg,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError && !snapshot.hasData) {
          return ColoredBox(
            color: kClayBg,
            child: Center(child: Text(userFacingErrorMessage(snapshot.error))),
          );
        }

        final prices = snapshot.data ?? const <FuelPriceModel>[];
        _seedDrafts(prices);
        final activeHistorySets = _buildHistorySets(prices, deleted: false);

        return RefreshIndicator(
          onRefresh: _reload,
          child: ColoredBox(
            color: kClayBg,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                if (widget.embedded)
                  ClaySubHeader(title: 'Fuel Prices', onBack: widget.onBack),
                _buildCurrentRates(prices),
                _buildLatestHistory(activeHistorySets),
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
        automaticallyImplyLeading: false,
        backgroundColor: kClayBg,
        title: const Text('Fuel Prices'),
      ),
      body: content,
    );
  }
}

enum _FuelPriceHistorySort {
  effectiveNewest,
  effectiveOldest,
  savedNewest,
  savedOldest,
}

class _FuelPriceHistoryScreen extends StatefulWidget {
  const _FuelPriceHistoryScreen({required this.canEdit});

  final bool canEdit;

  @override
  State<_FuelPriceHistoryScreen> createState() =>
      _FuelPriceHistoryScreenState();
}

class _FuelPriceHistoryScreenState extends State<_FuelPriceHistoryScreen> {
  final InventoryService _inventoryService = InventoryService();
  final ReportExportService _reportExportService = ReportExportService();
  late Future<List<FuelPriceModel>> _future;
  bool _showDeleted = false;
  bool _deleting = false;
  String _fromDate = currentMonthStartDateKey();
  String _toDate = currentMonthEndDateKey();
  _FuelPriceHistorySort _sort = _FuelPriceHistorySort.effectiveNewest;

  static const List<String> _fuelOrder = ['petrol', 'diesel', 'two_t_oil'];

  @override
  void initState() {
    super.initState();
    _future = _inventoryService.fetchPrices();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _inventoryService.fetchPrices(forceRefresh: true);
    });
    await _future;
  }

  List<_FuelPriceSet> _buildHistorySets(
    List<FuelPriceModel> prices, {
    required bool deleted,
  }) {
    final grouped = <String, Map<String, FuelPricePeriodModel>>{};
    for (final price in prices) {
      final periods = price.periods.isEmpty
          ? [
              FuelPricePeriodModel(
                effectiveFrom: price.effectiveFrom,
                effectiveTo: price.effectiveTo,
                costPrice: price.costPrice,
                sellingPrice: price.sellingPrice,
                updatedAt: price.updatedAt,
                updatedBy: price.updatedBy,
              ),
            ]
          : price.periods;
      for (final period in periods) {
        if (period.effectiveFrom.trim().isEmpty) continue;
        if (period.isDeleted != deleted) continue;
        if (_fromDate.isNotEmpty &&
            period.effectiveFrom.compareTo(_fromDate) < 0) {
          continue;
        }
        if (_toDate.isNotEmpty && period.effectiveFrom.compareTo(_toDate) > 0) {
          continue;
        }
        grouped.putIfAbsent(period.effectiveFrom, () => {});
        grouped[period.effectiveFrom]![price.fuelTypeId] = period;
      }
    }
    final sets = grouped.entries
        .map(
          (entry) =>
              _FuelPriceSet(effectiveDate: entry.key, prices: entry.value),
        )
        .toList();
    sets.sort((left, right) {
      switch (_sort) {
        case _FuelPriceHistorySort.effectiveNewest:
          return right.effectiveDate.compareTo(left.effectiveDate);
        case _FuelPriceHistorySort.effectiveOldest:
          return left.effectiveDate.compareTo(right.effectiveDate);
        case _FuelPriceHistorySort.savedNewest:
          return right.updatedAt.compareTo(left.updatedAt);
        case _FuelPriceHistorySort.savedOldest:
          return left.updatedAt.compareTo(right.updatedAt);
      }
    });
    return sets;
  }

  String _sortLabel(_FuelPriceHistorySort sort) {
    switch (sort) {
      case _FuelPriceHistorySort.effectiveNewest:
        return 'Effective newest';
      case _FuelPriceHistorySort.effectiveOldest:
        return 'Effective oldest';
      case _FuelPriceHistorySort.savedNewest:
        return 'Saved newest';
      case _FuelPriceHistorySort.savedOldest:
        return 'Saved oldest';
    }
  }

  Future<void> _pickDate({required bool from}) async {
    final current = DateTime.tryParse(from ? _fromDate : _toDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    final value = _dateKey(picked);
    setState(() {
      if (from) {
        _fromDate = value;
      } else {
        _toDate = value;
      }
    });
  }

  void _clearFilters() {
    setState(() {
      _fromDate = currentMonthStartDateKey();
      _toDate = currentMonthEndDateKey();
    });
  }

  bool get _hasCustomDateRange =>
      _fromDate != currentMonthStartDateKey() ||
      _toDate != currentMonthEndDateKey();

  String _dateKey(DateTime date) => apiDateKey(date);

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

  Future<void> _download(
    List<_FuelPriceSet> history, {
    required bool deleted,
  }) async {
    final rows = <List<dynamic>>[];
    for (final set in history) {
      for (final fuelId in _fuelOrder) {
        final period = set.prices[fuelId];
        rows.add([
          set.effectiveDate,
          _prettyFuelLabel(fuelId),
          period?.costPrice.toStringAsFixed(2) ?? '',
          period?.sellingPrice.toStringAsFixed(2) ?? '',
          period?.updatedAt ?? '',
          period?.updatedBy ?? '',
          period?.deletedAt ?? '',
          period?.deletedByName ?? '',
        ]);
      }
    }
    try {
      final path = await _reportExportService.saveRowsToDownloads(
        title: deleted ? 'deleted_fuel_rate_history' : 'fuel_rate_history',
        notificationTitle: 'Fuel rate history downloaded',
        headers: [
          'Effective Date',
          'Fuel',
          'Cost Price',
          'Selling Price',
          'Saved At',
          'Saved By',
          'Deleted At',
          'Deleted By',
        ],
        rows: rows,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fuel rate history downloaded to $path')),
      );
    } catch (error) {
      if (!mounted) return;
      _showError(userFacingErrorMessage(error));
    }
  }

  Future<void> _deleteHistorySet(_FuelPriceSet set) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete fuel rate history?'),
        content: const Text(
          'This date set will move to Deleted History for 30 days and then be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _deleting = true);
    try {
      await _inventoryService.deleteFuelPriceSet(set.effectiveDate);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fuel rate history deleted.')),
      );
      await _reload();
    } catch (error) {
      if (!mounted) return;
      _showError(userFacingErrorMessage(error));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFB91C1C),
        content: Text(message),
      ),
    );
  }

  String _displayTimestamp(String raw) {
    final trimmed = raw.trim();
    return trimmed.isEmpty ? 'Unknown time' : formatDateTimeLabel(trimmed);
  }

  Widget _filterButton({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFFECEFF8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFDDE2F0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.event_rounded, size: 18, color: kClayPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: kClaySub,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    OneLineScaleText(
                      value.isEmpty ? 'Any date' : formatDateLabel(value),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kClayBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: kClayBg,
        title: const Text('Fuel Rate History'),
      ),
      body: FutureBuilder<List<FuelPriceModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError && !snapshot.hasData) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Center(child: Text(userFacingErrorMessage(snapshot.error))),
              ],
            );
          }
          final prices = snapshot.data ?? const <FuelPriceModel>[];
          final activeSets = _buildHistorySets(prices, deleted: false);
          final deletedSets = _buildHistorySets(prices, deleted: true);
          final sets = _showDeleted ? deletedSets : activeSets;
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                ClayCard(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _showDeleted
                                      ? 'Deleted Fuel Rates'
                                      : 'Active Fuel Rates',
                                  style: const TextStyle(
                                    color: kClayPrimary,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${sets.length} rate set${sets.length == 1 ? '' : 's'} shown',
                                  style: const TextStyle(
                                    color: kClaySub,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton.filledTonal(
                            tooltip: 'Download history',
                            onPressed: sets.isEmpty
                                ? null
                                : () => _download(sets, deleted: _showDeleted),
                            icon: const Icon(Icons.download_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _HistoryTabButton(
                            label: 'Active',
                            count: activeSets.length,
                            selected: !_showDeleted,
                            onTap: () => setState(() => _showDeleted = false),
                          ),
                          _HistoryTabButton(
                            label: 'Deleted',
                            count: deletedSets.length,
                            selected: _showDeleted,
                            onTap: () => setState(() => _showDeleted = true),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
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
                      ClayDropdownField<_FuelPriceHistorySort>(
                        label: 'Sort by',
                        value: _sort,
                        compact: true,
                        items: _FuelPriceHistorySort.values
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(_sortLabel(item)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _sort = value);
                        },
                      ),
                      if (_hasCustomDateRange) ...[
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: _clearFilters,
                          child: const Text('Clear filter'),
                        ),
                      ],
                    ],
                  ),
                ),
                if (sets.isEmpty)
                  const ClayCard(
                    margin: EdgeInsets.only(bottom: 14),
                    child: Text(
                      'No fuel rate history for this filter.',
                      style: TextStyle(color: kClaySub),
                    ),
                  )
                else
                  ...sets.map(
                    (set) => _FuelPriceSetCard(
                      set: set,
                      fuelOrder: _fuelOrder,
                      labelForFuel: _prettyFuelLabel,
                      displayTimestamp: _displayTimestamp,
                      onDelete: widget.canEdit && !_showDeleted && !_deleting
                          ? () => _deleteHistorySet(set)
                          : null,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FuelRateDraft {
  _FuelRateDraft({required double costPrice, required double sellingPrice})
    : costController = TextEditingController(
        text: costPrice.toStringAsFixed(2),
      ),
      sellingController = TextEditingController(
        text: sellingPrice.toStringAsFixed(2),
      );

  final TextEditingController costController;
  final TextEditingController sellingController;

  void dispose() {
    costController.dispose();
    sellingController.dispose();
  }
}

class _FuelPriceSet {
  const _FuelPriceSet({required this.effectiveDate, required this.prices});

  final String effectiveDate;
  final Map<String, FuelPricePeriodModel> prices;

  String get updatedAt {
    final values = prices.values
        .map((period) => period.updatedAt.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (values.isEmpty) return '';
    values.sort();
    return values.last;
  }

  String get deletedAt {
    final values = prices.values
        .map((period) => period.deletedAt.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (values.isEmpty) return '';
    values.sort();
    return values.last;
  }

  String get deletedByName {
    final values = prices.values
        .map((period) => period.deletedByName.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    return values.isEmpty ? '' : values.first;
  }
}

class _RateSummaryRow extends StatelessWidget {
  const _RateSummaryRow({
    required this.title,
    required this.color,
    required this.effectiveDate,
    required this.costPrice,
    required this.sellingPrice,
  });

  final String title;
  final Color color;
  final String effectiveDate;
  final double costPrice;
  final double sellingPrice;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OneLineScaleText(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: kClayPrimary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        effectiveDate.isEmpty
                            ? 'No effective date'
                            : 'From ${formatDateLabel(effectiveDate)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: kClaySub, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _RateValueCell(value: formatCurrency(costPrice)),
          const SizedBox(width: 6),
          _RateValueCell(value: formatCurrency(sellingPrice)),
        ],
      ),
    );
  }
}

class _FuelPriceSetCard extends StatelessWidget {
  const _FuelPriceSetCard({
    required this.set,
    required this.fuelOrder,
    required this.labelForFuel,
    required this.displayTimestamp,
    this.onDelete,
  });

  final _FuelPriceSet set;
  final List<String> fuelOrder;
  final String Function(String) labelForFuel;
  final String Function(String) displayTimestamp;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final orderedFuelIds = fuelOrder
        .where((fuelId) => set.prices.containsKey(fuelId))
        .toList();
    final missingFuelIds = fuelOrder
        .where((fuelId) => !set.prices.containsKey(fuelId))
        .toList();
    final visibleFuelIds = [...orderedFuelIds, ...missingFuelIds];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E7F2)),
        boxShadow: [
          BoxShadow(
            color: kClayPrimary.withValues(alpha: 0.06),
            offset: const Offset(0, 8),
            blurRadius: 18,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  formatDateLabel(set.effectiveDate),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: kClayPrimary,
                  ),
                ),
              ),
              Text(
                displayTimestamp(set.updatedAt),
                style: const TextStyle(
                  color: kClaySub,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (onDelete != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Delete history',
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFB91C1C),
                    size: 20,
                  ),
                ),
              ],
            ],
          ),
          if (set.deletedAt.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Deleted by ${set.deletedByName.isEmpty ? 'Unknown' : set.deletedByName} on ${displayTimestamp(set.deletedAt)}',
              style: const TextStyle(
                color: Color(0xFFB91C1C),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                const _RateTableHeader(),
                const SizedBox(height: 8),
                ...List.generate(visibleFuelIds.length, (index) {
                  final fuelId = visibleFuelIds[index];
                  final period = set.prices[fuelId];
                  return Column(
                    children: [
                      _HistoryRateRow(
                        title: labelForFuel(fuelId),
                        costValue: period == null
                            ? 'Missing'
                            : formatCurrency(period.costPrice),
                        sellValue: period == null
                            ? 'Missing'
                            : formatCurrency(period.sellingPrice),
                      ),
                      if (index != visibleFuelIds.length - 1)
                        const Divider(height: 14, color: Color(0xFFE4E8F3)),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RateTableHeader extends StatelessWidget {
  const _RateTableHeader();

  @override
  Widget build(BuildContext context) {
    const headerStyle = TextStyle(
      color: kClaySub,
      fontSize: 10,
      fontWeight: FontWeight.w800,
    );
    return Row(
      children: const [
        Expanded(child: Text('Fuel', style: headerStyle)),
        SizedBox(width: 10),
        SizedBox(width: 82, child: Text('Cost', style: headerStyle)),
        SizedBox(width: 6),
        SizedBox(width: 82, child: Text('Sell', style: headerStyle)),
      ],
    );
  }
}

class _HistoryRateRow extends StatelessWidget {
  const _HistoryRateRow({
    required this.title,
    required this.costValue,
    required this.sellValue,
  });

  final String title;
  final String costValue;
  final String sellValue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: OneLineScaleText(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: kClayPrimary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _RateValueCell(value: costValue),
          const SizedBox(width: 6),
          _RateValueCell(value: sellValue),
        ],
      ),
    );
  }
}

class _RateValueCell extends StatelessWidget {
  const _RateValueCell({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 82,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE6EAF4)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: OneLineScaleText(
            value,
            alignment: Alignment.centerLeft,
            style: const TextStyle(
              color: kClayPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryTabButton extends StatelessWidget {
  const _HistoryTabButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? kClayPrimary : Colors.white,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            color: selected ? Colors.white : kClayPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _RateField extends StatelessWidget {
  const _RateField({
    required this.label,
    required this.controller,
    required this.enabled,
  });

  final String label;
  final TextEditingController? controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(
        color: kClayPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        filled: true,
        fillColor: enabled ? Colors.white : const Color(0xFFE8EBF4),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E6F1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E6F1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kClayPrimary, width: 1.2),
        ),
      ),
    );
  }
}
