import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/credit_service.dart';
import '../services/inventory_service.dart';
import '../services/management_service.dart';
import '../services/sales_service.dart';
import '../utils/fuel_prices.dart';
import '../utils/formatters.dart';
import '../utils/user_facing_errors.dart';
import '../widgets/clay_widgets.dart';
import '../widgets/daily_entry_dialogs.dart';
import '../widgets/responsive_text.dart';

typedef EntrySubmitCallback =
    Future<void> Function(DailyEntryDraft draft, String mismatchReason);

class EntryWorkflowScreen extends StatefulWidget {
  const EntryWorkflowScreen({
    super.key,
    required this.title,
    required this.station,
    required this.openingReadings,
    required this.priceSnapshot,
    required this.initialDraft,
    required this.onSubmit,
    this.isAdmin = false,
    this.existingEntryId,
    this.canChangeDate = false,
    this.takenDates = const [],
  });

  final String title;
  final StationConfigModel station;
  final Map<String, PumpReadings> openingReadings;
  final Map<String, Map<String, double>> priceSnapshot;
  final DailyEntryDraft initialDraft;
  final EntrySubmitCallback onSubmit;

  /// Whether the current user is admin/superadmin (enables date editing).
  final bool isAdmin;

  /// The Firestore entry ID of the entry being edited (needed to call changeDate).
  final String? existingEntryId;

  /// Whether this entry is allowed to move to another date.
  final bool canChangeDate;

  /// Dates that already have entries — cannot pick these when changing date.
  final List<String> takenDates;

  @override
  State<EntryWorkflowScreen> createState() => _EntryWorkflowScreenState();
}

class _EntryWorkflowScreenState extends State<EntryWorkflowScreen> {
  final SalesService _salesService = SalesService();
  final CreditService _creditService = CreditService();
  final InventoryService _inventoryService = InventoryService();
  final ManagementService _managementService = ManagementService();
  late DailyEntryDraft _draft;
  late Map<String, Map<String, double>> _resolvedPriceSnapshot;
  List<CreditCustomerSummaryModel> _suggestedCustomers = const [];
  bool _resolvingPriceSnapshot = false;
  bool _submitting = false;
  bool _changingDate = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialDraft;
    _resolvedPriceSnapshot = mergePriceSnapshots(primary: widget.priceSnapshot);
    _resolvingPriceSnapshot =
        !hasRequiredSellingPrices(_resolvedPriceSnapshot, const <String>[
          'petrol',
          'diesel',
        ]);
    _loadAuxiliaryData();
  }

  Future<void> _loadAuxiliaryData() async {
    final needsPriceFallback =
        !hasRequiredSellingPrices(_resolvedPriceSnapshot, const <String>[
          'petrol',
          'diesel',
        ]);
    try {
      final customersFuture = _creditService.fetchCustomers();
      final pricesFuture =
          needsPriceFallback
              ? _inventoryService.fetchPrices(activeOnly: true)
              : null;

      final customers = (await customersFuture).$2;
      List<FuelPriceModel> prices = const <FuelPriceModel>[];
      if (pricesFuture != null) {
        try {
          prices = await pricesFuture;
        } catch (_) {
          prices = const <FuelPriceModel>[];
        }
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _suggestedCustomers = customers;
        _resolvedPriceSnapshot = mergePriceSnapshots(
          primary: widget.priceSnapshot,
          fallback: buildPriceSnapshotFromPrices(prices),
        );
        _resolvingPriceSnapshot = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _resolvingPriceSnapshot = false;
      });
    }
  }

  void _savePumpEdit(String pumpId, PumpEntryDraft pumpDraft) {
    final remainingCredits =
        _draft.creditEntries.where((item) => item.pumpId != pumpId).toList();
    setState(() {
      _draft = _draft.copyWith(
        closingReadings: {
          ..._draft.closingReadings,
          if (pumpDraft.closingReadings != null)
            pumpId: pumpDraft.closingReadings!,
        },
        pumpAttendants: {..._draft.pumpAttendants, pumpId: pumpDraft.attendant},
        pumpTesting: {..._draft.pumpTesting, pumpId: pumpDraft.testing},
        pumpPayments: {..._draft.pumpPayments, pumpId: pumpDraft.payments},
        pumpCollections: {
          ..._draft.pumpCollections,
          pumpId: pumpDraft.payments.total,
        },
        creditEntries: [...remainingCredits, ...pumpDraft.creditEntries],
        pumpMismatchReasons: {
          ..._draft.pumpMismatchReasons,
          pumpId: pumpDraft.mismatchReason,
        },
      );
    });
  }

  String _buildEntryMismatchReason() {
    final reasons =
        widget.station.pumps
            .map((pump) {
              final reason = _draft.pumpMismatchReasons[pump.id]?.trim() ?? '';
              if (reason.isEmpty) {
                return null;
              }
              return '${formatPumpLabel(pump.id, pump.label)}: $reason';
            })
            .whereType<String>()
            .toList();
    if (reasons.isNotEmpty) {
      return reasons.join('\n');
    }
    return _draft.mismatchReason.trim();
  }

  bool _supportsTwoT(String pumpId) => true;

  String _twoTSoldLabel(PumpReadings opening, PumpReadings? closing) {
    if (closing == null) {
      return 'Not entered';
    }
    return formatLiters(closing.twoT - opening.twoT);
  }

  String _cashCollectedFromLabel(String pumpId) {
    final name = _draft.pumpAttendants[pumpId]?.trim() ?? '';
    return name.isEmpty ? 'Not entered' : name;
  }

  PumpReadings _soldTotals() {
    double petrol = 0;
    double diesel = 0;
    double twoT = 0;
    for (final pump in widget.station.pumps) {
      final opening = widget.openingReadings[pump.id];
      final closing = _draft.closingReadings[pump.id];
      if (opening == null || closing == null) {
        continue;
      }
      final testing =
          _draft.pumpTesting[pump.id] ??
          const PumpTestingModel(petrol: 0, diesel: 0);
      final rawPetrol = closing.petrol - opening.petrol;
      final rawDiesel = closing.diesel - opening.diesel;
      petrol +=
          rawPetrol > 0
              ? (rawPetrol - testing.petrol).clamp(0, rawPetrol)
              : rawPetrol;
      diesel +=
          rawDiesel > 0
              ? (rawDiesel - testing.diesel).clamp(0, rawDiesel)
              : rawDiesel;
      if (_supportsTwoT(pump.id)) {
        twoT += closing.twoT - opening.twoT;
      }
    }
    return PumpReadings(petrol: petrol, diesel: diesel, twoT: twoT);
  }

  PaymentBreakdownModel _settlementModes() {
    var cash = _draft.paymentBreakdown.cash;
    var check = _draft.paymentBreakdown.check;
    var upi = _draft.paymentBreakdown.upi;
    for (final value in _draft.pumpPayments.values) {
      cash += value.cash;
      check += value.check;
      upi += value.upi;
    }
    return PaymentBreakdownModel(cash: cash, check: check, upi: upi);
  }

  double _pumpCreditTotal() {
    return _draft.pumpPayments.values.fold<double>(
      0,
      (sum, value) => sum + value.credit,
    );
  }

  double _issuedCreditTotal() {
    return _draft.creditEntries.fold<double>(
      0,
      (sum, value) => sum + value.amount,
    );
  }

  double _collectionRecoveryTotal() {
    return _draft.creditCollections.fold<double>(
      0,
      (sum, value) => sum + value.amount,
    );
  }

  double _salesSettlementTotal() {
    final modes = _settlementModes();
    return modes.cash + modes.check + modes.upi + _pumpCreditTotal();
  }

  Future<void> _editPump(StationPumpModel pump) async {
    if (_resolvingPriceSnapshot &&
        !hasRequiredSellingPrices(_resolvedPriceSnapshot, const <String>[
          'petrol',
          'diesel',
        ])) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fuel prices are loading. Try Update Pump again.'),
        ),
      );
      return;
    }

    final result = await showPumpEntryDialog(
      context: context,
      pump: pump,
      opening:
          widget.openingReadings[pump.id] ??
          const PumpReadings(petrol: 0, diesel: 0, twoT: 0),
      limit:
          widget.station.meterLimits[pump.id] ??
          const PumpReadings(petrol: 0, diesel: 0, twoT: 0),
      initialDraft: PumpEntryDraft(
        attendant: _draft.pumpAttendants[pump.id] ?? '',
        closingReadings: _draft.closingReadings[pump.id],
        testing:
            _draft.pumpTesting[pump.id] ??
            const PumpTestingModel(petrol: 0, diesel: 0),
        payments:
            _draft.pumpPayments[pump.id] ??
            const PumpPaymentBreakdownModel(
              cash: 0,
              check: 0,
              upi: 0,
              credit: 0,
            ),
        creditEntries:
            _draft.creditEntries
                .where((item) => item.pumpId == pump.id)
                .toList(),
        mismatchReason: _draft.pumpMismatchReasons[pump.id] ?? '',
      ),
      suggestedCustomers: _suggestedCustomers,
      priceSnapshot: _resolvedPriceSnapshot,
      flagThreshold: widget.station.flagThreshold,
    );
    if (!mounted || result == null) {
      return;
    }
    _savePumpEdit(result.key, result.value);
  }

  Future<void> _editPumpCashCollection(StationPumpModel pump) async {
    final result = await showPumpCashCollectionDialog(
      context: context,
      pump: pump,
      initialDraft: PumpEntryDraft(
        attendant: _draft.pumpAttendants[pump.id] ?? '',
        closingReadings: _draft.closingReadings[pump.id],
        testing:
            _draft.pumpTesting[pump.id] ??
            const PumpTestingModel(petrol: 0, diesel: 0),
        payments:
            _draft.pumpPayments[pump.id] ??
            const PumpPaymentBreakdownModel(
              cash: 0,
              check: 0,
              upi: 0,
              credit: 0,
            ),
        creditEntries:
            _draft.creditEntries
                .where((item) => item.pumpId == pump.id)
                .toList(),
        mismatchReason: _draft.pumpMismatchReasons[pump.id] ?? '',
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    _savePumpEdit(result.key, result.value);
  }

  Future<void> _changeDate() async {
    final entryId = widget.existingEntryId;
    if (entryId == null) return;

    setState(() {
      _changingDate = true;
      _error = null;
    });

    // Fetch all station entries to know which dates are already taken.
    List<String> takenDates = widget.takenDates;
    try {
      final allEntries = await _managementService.fetchEntries();
      takenDates = allEntries.map((e) => e.date).toList();
    } catch (_) {
      // fall back to the list passed in by the parent
    } finally {
      if (mounted) setState(() => _changingDate = false);
    }
    if (!mounted) return;

    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_draft.date) ?? today,
      firstDate: DateTime(2024),
      lastDate: today,
      selectableDayPredicate: (day) {
        final dayStr =
            '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        // Always allow the current date (moving away from it)
        if (dayStr == _draft.date) return true;
        // Block dates that already have an entry
        return !takenDates.contains(dayStr);
      },
    );
    if (picked == null || !mounted) return;

    final newDate =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    if (newDate == _draft.date) return;

    setState(() {
      _changingDate = true;
      _error = null;
    });
    try {
      await _managementService.changeEntryDate(entryId, newDate);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = userFacingErrorMessage(error));
    } finally {
      if (mounted) setState(() => _changingDate = false);
    }
  }

  Future<void> _submitEntry() async {
    final missingPumps =
        widget.station.pumps
            .where((pump) => !_draft.closingReadings.containsKey(pump.id))
            .map((pump) => formatPumpLabel(pump.id, pump.label))
            .toList();
    if (missingPumps.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Enter closing meter readings for ${missingPumps.join(', ')} before submit.',
          ),
        ),
      );
      return;
    }

    final missingCollections =
        widget.station.pumps
            .where((pump) => !_draft.pumpPayments.containsKey(pump.id))
            .map((pump) => formatPumpLabel(pump.id, pump.label))
            .toList();
    if (missingCollections.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Enter collection for ${missingCollections.join(', ')} before submit.',
          ),
        ),
      );
      return;
    }

    final pumpCreditTotal = _pumpCreditTotal();
    final namedCreditTotal = _issuedCreditTotal();
    if ((pumpCreditTotal - namedCreditTotal).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Credit customer names must total ${formatCurrency(pumpCreditTotal)} before submit.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final mismatchReason = _buildEntryMismatchReason();
      final preview = await _salesService.previewEntry(
        date: _draft.date,
        closingReadings: _draft.closingReadings,
        pumpAttendants: _draft.pumpAttendants,
        pumpTesting: _draft.pumpTesting,
        pumpPayments: _draft.pumpPayments,
        pumpCollections: _draft.pumpCollections,
        paymentBreakdown: _draft.paymentBreakdown,
        creditEntries: _draft.creditEntries,
        creditCollections: _draft.creditCollections,
        mismatchReason: mismatchReason,
      );

      if (!mounted) {
        return;
      }

      await widget.onSubmit(_draft, mismatchReason);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Entry submitted. Collected ${formatCurrency(preview.paymentTotal)}.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = userFacingErrorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _soldTotals();
    return Scaffold(
      backgroundColor: kClayBg,
      appBar: AppBar(
        backgroundColor: kClayBg,
        iconTheme: const IconThemeData(color: kClayPrimary),
        title: Text(widget.title),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [kClayHeroStart, kClayHeroEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: kClayHeroEnd.withValues(alpha: 0.45),
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
                    Text(
                      formatDateLabel(_draft.date),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    if (widget.isAdmin &&
                        widget.existingEntryId != null &&
                        widget.canChangeDate) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _changingDate ? null : _changeDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.edit_calendar_rounded,
                                size: 11,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _changingDate ? 'Changing…' : 'Change date',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.station.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Enter pump readings first. Payments and credit are updated from the summary section below.',
                  style: TextStyle(
                    color: Colors.white70,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      _HeroStatCell(
                        label: 'Petrol',
                        value: formatLiters(summary.petrol),
                      ),
                      _HeroStatDivider(),
                      _HeroStatCell(
                        label: 'Diesel',
                        value: formatLiters(summary.diesel),
                      ),
                      _HeroStatDivider(),
                      _HeroStatCell(
                        label: '2T Oil',
                        value: formatLiters(summary.twoT),
                      ),
                      _HeroStatDivider(),
                      _HeroStatCell(
                        label: 'Settlement',
                        value: formatCurrency(_salesSettlementTotal()),
                        wide: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _WorkflowSectionLabel(label: 'PUMPS'),
          const SizedBox(height: 10),
          ...widget.station.pumps.map((pump) {
            final opening =
                widget.openingReadings[pump.id] ??
                const PumpReadings(petrol: 0, diesel: 0, twoT: 0);
            final attendant = _draft.pumpAttendants[pump.id] ?? '';
            final closing = _draft.closingReadings[pump.id];
            return ClayCard(
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          formatPumpLabel(pump.id, pump.label),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: kClayPrimary,
                          ),
                        ),
                      ),
                      if (attendant.isNotEmpty)
                        _WorkflowPill(label: attendant, color: kClayHeroStart),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _WorkflowRow(
                    label: 'Opening petrol meter',
                    value: formatLiters(opening.petrol),
                    accent: const Color(0xFF1298B8),
                  ),
                  _WorkflowRow(
                    label: 'Opening diesel meter',
                    value: formatLiters(opening.diesel),
                    accent: const Color(0xFF2AA878),
                  ),
                  _WorkflowRow(
                    label: 'Entered closing petrol meter',
                    value:
                        closing == null
                            ? 'Not entered'
                            : formatLiters(closing.petrol),
                    accent: const Color(0xFF1298B8),
                  ),
                  _WorkflowRow(
                    label: 'Entered closing diesel meter',
                    value:
                        closing == null
                            ? 'Not entered'
                            : formatLiters(closing.diesel),
                    accent: const Color(0xFF2AA878),
                  ),
                  if (_supportsTwoT(pump.id))
                    _WorkflowRow(
                      label: 'Entered 2T oil sold',
                      value: _twoTSoldLabel(opening, closing),
                      accent: const Color(0xFF7048A8),
                    ),
                  _WorkflowRow(
                    label: 'Cash collected from',
                    value: _cashCollectedFromLabel(pump.id),
                    accent: const Color(0xFFCE5828),
                  ),
                  _WorkflowRow(
                    label: 'Cash',
                    value: formatCurrency(
                      _draft.pumpPayments[pump.id]?.cash ?? 0,
                    ),
                    accent: const Color(0xFFCE5828),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _editPumpCashCollection(pump),
                          icon: const Icon(Icons.payments_outlined),
                          label: const Text('Cash Collection'),
                          style: _workflowOutlinedButtonStyle(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _editPump(pump),
                          icon: const Icon(Icons.edit_rounded),
                          label: const Text('Update Pump'),
                          style: _workflowOutlinedButtonStyle(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          const _WorkflowSectionLabel(label: 'SUMMARY'),
          const SizedBox(height: 10),
          ClayCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Overall Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: kClayPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Cash, check, UPI, and pump credit are taken from the pump entries. Pump credit is calculated from the added credit rows for each pump. Old credit collection is handled from Credit Ledger.',
                  style: TextStyle(
                    color: kClaySub,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                _WorkflowTextRow(
                  label: 'Total petrol sold',
                  value: formatLiters(summary.petrol),
                ),
                _WorkflowTextRow(
                  label: 'Total diesel sold',
                  value: formatLiters(summary.diesel),
                ),
                _WorkflowTextRow(
                  label: 'Total 2T oil sold',
                  value: formatLiters(summary.twoT),
                ),
                _WorkflowTextRow(
                  label: 'Sales settlement total',
                  value: formatCurrency(_salesSettlementTotal()),
                ),
                _WorkflowTextRow(
                  label: 'Old credit collected',
                  value: formatCurrency(_collectionRecoveryTotal()),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: kClayBg,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Credit customer details',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: kClayPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _pumpCreditTotal() <= 0
                            ? 'No pump credit added yet. Use Add Credit inside a pump to create customer-wise credit rows.'
                            : 'Pump credit is built from the customer-wise credit rows added inside each pump. Once approved, these names will be shown in Credit Ledger.',
                        style: const TextStyle(
                          color: kClaySub,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_draft.creditEntries.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        ..._draft.creditEntries.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: kClayHeroStart.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.person_outline_rounded,
                                    size: 18,
                                    color: kClayHeroStart,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: const TextStyle(
                                      color: kClayPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(
                                  formatCurrency(item.amount),
                                  style: const TextStyle(
                                    color: kClayPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      const Text(
                        'Use Update Pump on the relevant pump to add or change credit customer rows.',
                        style: TextStyle(
                          color: kClaySub,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: Color(0xFFB91C1C),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _submitting ? null : _submitEntry,
            icon: const Icon(Icons.edit_note_rounded),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              backgroundColor: kClayHeroStart,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            label: Text(_submitting ? 'Submitting...' : 'Submit Entry'),
          ),
        ],
      ),
    );
  }
}

ButtonStyle _workflowOutlinedButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: kClayPrimary,
    side: const BorderSide(color: Color(0xFFD8DCF0)),
    padding: const EdgeInsets.symmetric(vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  );
}

class _WorkflowSectionLabel extends StatelessWidget {
  const _WorkflowSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: kClaySub,
        letterSpacing: 1.1,
      ),
    );
  }
}

class _HeroStatCell extends StatelessWidget {
  const _HeroStatCell({
    required this.label,
    required this.value,
    this.wide = false,
  });

  final String label;
  final String value;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: wide ? 2 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 3),
          OneLineScaleText(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: Colors.white.withValues(alpha: 0.2),
    );
  }
}

class _WorkflowPill extends StatelessWidget {
  const _WorkflowPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: OneLineScaleText(
        label,
        alignment: Alignment.center,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _WorkflowRow extends StatelessWidget {
  const _WorkflowRow({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: kClaySub,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          OneLineScaleText(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: kClayPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkflowTextRow extends StatelessWidget {
  const _WorkflowTextRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: kClaySub,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          OneLineScaleText(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: kClayPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
