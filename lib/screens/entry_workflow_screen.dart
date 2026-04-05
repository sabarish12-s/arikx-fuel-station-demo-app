import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/credit_service.dart';
import '../services/sales_service.dart';
import '../utils/formatters.dart';
import '../widgets/daily_entry_dialogs.dart';

typedef EntrySubmitCallback =
    Future<void> Function(DailyEntryDraft draft, String mismatchReason);

class EntryWorkflowScreen extends StatefulWidget {
  const EntryWorkflowScreen({
    super.key,
    required this.title,
    required this.station,
    required this.openingReadings,
    required this.initialDraft,
    required this.onSubmit,
  });

  final String title;
  final StationConfigModel station;
  final Map<String, PumpReadings> openingReadings;
  final DailyEntryDraft initialDraft;
  final EntrySubmitCallback onSubmit;

  @override
  State<EntryWorkflowScreen> createState() => _EntryWorkflowScreenState();
}

class _EntryWorkflowScreenState extends State<EntryWorkflowScreen> {
  final SalesService _salesService = SalesService();
  final CreditService _creditService = CreditService();
  late DailyEntryDraft _draft;
  List<CreditCustomerSummaryModel> _suggestedCustomers = const [];
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialDraft;
    _loadSuggestedCustomers();
  }

  Future<void> _loadSuggestedCustomers() async {
    try {
      final customers = (await _creditService.fetchCustomers()).$2;
      if (!mounted) {
        return;
      }
      setState(() {
        _suggestedCustomers = customers;
      });
    } catch (_) {}
  }

  void _savePumpEdit(String pumpId, PumpEntryDraft pumpDraft) {
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
      );
    });
  }

  bool _supportsTwoT(String pumpId) => pumpId == 'pump2';

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
      petrol += rawPetrol > 0 ? (rawPetrol - testing.petrol).clamp(0, rawPetrol) : rawPetrol;
      diesel += rawDiesel > 0 ? (rawDiesel - testing.diesel).clamp(0, rawDiesel) : rawDiesel;
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
    return _draft.creditEntries.fold<double>(0, (sum, value) => sum + value.amount);
  }

  double _collectionRecoveryTotal() {
    return _draft.creditCollections.fold<double>(
      0,
      (sum, value) => sum + value.amount,
    );
  }

  double _salesSettlementTotal() {
    final modes = _settlementModes();
    return modes.cash +
        modes.check +
        modes.upi +
        _pumpCreditTotal() +
        _issuedCreditTotal();
  }

  Future<void> _editCreditEntries() async {
    final result = await showCreditEntriesDialog(
      context: context,
      initialEntries: _draft.creditEntries,
      expectedTotal: _pumpCreditTotal(),
      suggestedCustomers: _suggestedCustomers,
    );
    if (!mounted || result == null) {
      return;
    }
    setState(() {
      _draft = _draft.copyWith(creditEntries: result);
    });
  }

  Future<void> _editPump(StationPumpModel pump) async {
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
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    _savePumpEdit(result.key, result.value);
  }

  Future<void> _reviewAndSubmit() async {
    final missingPumps =
        widget.station.pumps
            .where((pump) => !_draft.closingReadings.containsKey(pump.id))
            .map((pump) => formatPumpLabel(pump.id, pump.label))
            .toList();
    if (missingPumps.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Enter closing meter readings for ${missingPumps.join(', ')} before review.',
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
            'Enter collection for ${missingCollections.join(', ')} before review.',
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
            'Credit customer names must total ${formatCurrency(pumpCreditTotal)} before review.',
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
        mismatchReason: _draft.mismatchReason,
      );

      if (!mounted) {
        return;
      }

      final mismatchReason = await showDailyEntryPreviewDialog(
        context: context,
        preview: preview,
        initialMismatchReason: _draft.mismatchReason,
      );
      if (mismatchReason == null) {
        return;
      }

      await widget.onSubmit(_draft, mismatchReason);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
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
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.station.name} - ${formatDateLabel(_draft.date)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF293340),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Enter pump readings first. Payments and credit are updated from the summary section below.',
                  style: TextStyle(color: Color(0xFF55606E), height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...widget.station.pumps.map((pump) {
            final opening =
                widget.openingReadings[pump.id] ??
                const PumpReadings(petrol: 0, diesel: 0, twoT: 0);
            final attendant = _draft.pumpAttendants[pump.id] ?? '';
            final closing = _draft.closingReadings[pump.id];
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
                          formatPumpLabel(pump.id, pump.label),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF293340),
                          ),
                        ),
                      ),
                      if (attendant.isNotEmpty) Chip(label: Text(attendant)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _WorkflowRow(
                    label: 'Opening petrol meter',
                    value: formatLiters(opening.petrol),
                    accent: const Color(0xFF1E5CBA),
                  ),
                  _WorkflowRow(
                    label: 'Opening diesel meter',
                    value: formatLiters(opening.diesel),
                    accent: const Color(0xFF006C5C),
                  ),
                  if (_supportsTwoT(pump.id))
                    _WorkflowRow(
                      label: 'Opening 2T oil meter',
                      value: formatLiters(opening.twoT),
                      accent: const Color(0xFFB45309),
                    ),
                  _WorkflowRow(
                    label: 'Entered closing petrol meter',
                    value:
                        closing == null
                            ? 'Not entered'
                            : formatLiters(closing.petrol),
                    accent: const Color(0xFF1E5CBA),
                  ),
                  _WorkflowRow(
                    label: 'Entered closing diesel meter',
                    value:
                        closing == null
                            ? 'Not entered'
                            : formatLiters(closing.diesel),
                    accent: const Color(0xFF006C5C),
                  ),
                  if (_supportsTwoT(pump.id))
                    _WorkflowRow(
                      label: 'Entered closing 2T oil meter',
                      value:
                          closing == null
                              ? 'Not entered'
                              : formatLiters(closing.twoT),
                      accent: const Color(0xFFB45309),
                    ),
                  _WorkflowRow(
                    label: 'Cash',
                    value: formatCurrency(_draft.pumpPayments[pump.id]?.cash ?? 0),
                    accent: const Color(0xFFB45309),
                  ),
                  _WorkflowRow(
                    label: 'Check',
                    value: formatCurrency(_draft.pumpPayments[pump.id]?.check ?? 0),
                    accent: const Color(0xFF6B7280),
                  ),
                  _WorkflowRow(
                    label: 'UPI',
                    value: formatCurrency(_draft.pumpPayments[pump.id]?.upi ?? 0),
                    accent: const Color(0xFF7C3AED),
                  ),
                  _WorkflowRow(
                    label: 'Credit',
                    value: formatCurrency(
                      _draft.pumpPayments[pump.id]?.credit ?? 0,
                    ),
                    accent: const Color(0xFFDC2626),
                  ),
                  _WorkflowRow(
                    label: 'Testing',
                    value:
                        (_draft.pumpTesting[pump.id]?.enabled ?? false)
                            ? 'Petrol ${formatLiters(_draft.pumpTesting[pump.id]?.petrol ?? 0)}, Diesel ${formatLiters(_draft.pumpTesting[pump.id]?.diesel ?? 0)} excluded'
                            : 'Off',
                    accent: const Color(0xFF7C3AED),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () => _editPump(pump),
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Update Pump'),
                    ),
                  ),
                ],
              ),
            );
          }),
          Container(
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
                    const Expanded(
                      child: Text(
                        'Overall Summary',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF293340),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Cash, check, UPI, and pump credit are taken from the pump entries. Old credit collection is handled from Credit Ledger.',
                  style: TextStyle(color: Color(0xFF55606E), height: 1.4),
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Credit customer details',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF293340),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _pumpCreditTotal() <= 0
                            ? 'No pump credit entered yet. When credit sale is entered, add customer names here.'
                            : 'Add customer-wise credit names for the pump credit total. Once approved, these names will be shown in Credit Ledger.',
                        style: const TextStyle(
                          color: Color(0xFF55606E),
                          height: 1.4,
                        ),
                      ),
                      if (_draft.creditEntries.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        ..._draft.creditEntries.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.person_outline_rounded,
                                  size: 18,
                                  color: Color(0xFF1E5CBA),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: const TextStyle(
                                      color: Color(0xFF293340),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  formatCurrency(item.amount),
                                  style: const TextStyle(
                                    color: Color(0xFF293340),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: _submitting ? null : _editCreditEntries,
                          icon: const Icon(Icons.badge_outlined),
                          label: Text(
                            _draft.creditEntries.isNotEmpty
                                ? 'Edit Credit Names'
                                : 'Add Credit Names',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: const TextStyle(color: Color(0xFFB91C1C)),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _submitting ? null : _reviewAndSubmit,
            icon: const Icon(Icons.edit_note_rounded),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              backgroundColor: const Color(0xFF1E5CBA),
            ),
            label: Text(_submitting ? 'Preparing...' : 'Review Entry'),
          ),
        ],
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
              style: const TextStyle(color: Color(0xFF55606E)),
            ),
          ),
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
              style: const TextStyle(color: Color(0xFF55606E)),
            ),
          ),
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
