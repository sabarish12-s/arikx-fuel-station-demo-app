import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/credit_service.dart';
import '../services/inventory_service.dart';
import '../services/sales_service.dart';
import '../utils/fuel_prices.dart';
import '../utils/formatters.dart';
import '../widgets/daily_entry_dialogs.dart';

class ClosingStockEntryScreen extends StatefulWidget {
  const ClosingStockEntryScreen({super.key});

  @override
  State<ClosingStockEntryScreen> createState() =>
      _ClosingStockEntryScreenState();
}

class _ClosingStockEntryScreenState extends State<ClosingStockEntryScreen> {
  final SalesService _salesService = SalesService();
  final CreditService _creditService = CreditService();
  final InventoryService _inventoryService = InventoryService();
  SalesDashboardModel? _dashboard;
  Map<String, Map<String, double>> _resolvedPriceSnapshot =
      const <String, Map<String, double>>{};
  List<CreditCustomerSummaryModel> _suggestedCustomers = const [];
  String? _selectedDate;
  DailyEntryDraft? _draft;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String? date}) async {
    try {
      final dashboardFuture = _salesService.fetchDashboardForDate(date: date);
      final customersFuture = _creditService.fetchCustomers();
      final pricesFuture = _inventoryService.fetchPrices(activeOnly: true);
      final dashboard = await dashboardFuture;
      List<CreditCustomerSummaryModel> customers = const [];
      List<FuelPriceModel> prices = const <FuelPriceModel>[];
      try {
        customers = (await customersFuture).$2;
      } catch (_) {
        customers = const [];
      }
      try {
        prices = await pricesFuture;
      } catch (_) {
        prices = const [];
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _dashboard = dashboard;
        _resolvedPriceSnapshot = mergePriceSnapshots(
          primary: dashboard.priceSnapshot,
          fallback: buildPriceSnapshotFromPrices(prices),
        );
        _suggestedCustomers = customers;
        _selectedDate = dashboard.date;
        _draft = _seedDraft(dashboard);
        _error = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_selectedDate ?? '') ?? DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      helpText: 'Select entry date',
    );
    if (selected == null) {
      return;
    }
    final month = selected.month.toString().padLeft(2, '0');
    final day = selected.day.toString().padLeft(2, '0');
    await _load(date: '${selected.year}-$month-$day');
  }

  DailyEntryDraft _seedDraft(SalesDashboardModel dashboard) {
    final existing = dashboard.selectedEntry;
    if (existing != null) {
      return DailyEntryDraft(
        date: existing.date,
        closingReadings: existing.closingReadings,
        pumpAttendants: existing.pumpAttendants,
        pumpTesting: existing.pumpTesting,
        pumpPayments: existing.pumpPayments,
        pumpCollections: existing.pumpCollections,
        paymentBreakdown: existing.paymentBreakdown,
        creditEntries: existing.creditEntries,
        creditCollections: existing.creditCollections,
        mismatchReason: existing.mismatchReason,
      );
    }
    return DailyEntryDraft(
      date: dashboard.date,
      closingReadings: const {},
      pumpAttendants: {for (final pump in dashboard.station.pumps) pump.id: ''},
      pumpTesting: {
        for (final pump in dashboard.station.pumps)
          pump.id: const PumpTestingModel(petrol: 0, diesel: 0),
      },
      pumpPayments: const {},
      pumpCollections: const {},
      paymentBreakdown: const PaymentBreakdownModel(cash: 0, check: 0, upi: 0),
      creditEntries: const [],
      creditCollections: const [],
    );
  }

  void _savePumpEdit(String pumpId, PumpEntryDraft pumpDraft) {
    final draft = _draft;
    if (draft == null) {
      return;
    }
    final remainingCredits =
        draft.creditEntries.where((item) => item.pumpId != pumpId).toList();
    setState(() {
      _draft = draft.copyWith(
        closingReadings: {
          ...draft.closingReadings,
          if (pumpDraft.closingReadings != null)
            pumpId: pumpDraft.closingReadings!,
        },
        pumpAttendants: {...draft.pumpAttendants, pumpId: pumpDraft.attendant},
        pumpTesting: {...draft.pumpTesting, pumpId: pumpDraft.testing},
        pumpPayments: {...draft.pumpPayments, pumpId: pumpDraft.payments},
        pumpCollections: {
          ...draft.pumpCollections,
          pumpId: pumpDraft.payments.total,
        },
        creditEntries: [...remainingCredits, ...pumpDraft.creditEntries],
        pumpMismatchReasons: {
          ...draft.pumpMismatchReasons,
          pumpId: pumpDraft.mismatchReason,
        },
      );
    });
  }

  String _buildEntryMismatchReason(DailyEntryDraft draft) {
    final pumps = _dashboard?.station.pumps ?? const <StationPumpModel>[];
    final reasons =
        pumps
            .map((pump) {
              final reason = draft.pumpMismatchReasons[pump.id]?.trim() ?? '';
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
    return draft.mismatchReason.trim();
  }

  double _pumpCollectionTotal(DailyEntryDraft draft) {
    return draft.pumpPayments.values.fold<double>(
      0,
      (sum, value) => sum + value.total,
    );
  }

  PaymentBreakdownModel _settlementModes(DailyEntryDraft draft) {
    var cash = draft.paymentBreakdown.cash;
    var check = draft.paymentBreakdown.check;
    var upi = draft.paymentBreakdown.upi;
    for (final value in draft.pumpPayments.values) {
      cash += value.cash;
      check += value.check;
      upi += value.upi;
    }
    return PaymentBreakdownModel(cash: cash, check: check, upi: upi);
  }

  double _pumpCreditTotal(DailyEntryDraft draft) {
    return draft.pumpPayments.values.fold<double>(
      0,
      (sum, value) => sum + value.credit,
    );
  }

  double _issuedCreditTotal(DailyEntryDraft draft) {
    return draft.creditEntries.fold<double>(
      0,
      (sum, value) => sum + value.amount,
    );
  }

  double _collectionRecoveryTotal(DailyEntryDraft draft) {
    return draft.creditCollections.fold<double>(
      0,
      (sum, value) => sum + value.amount,
    );
  }

  double _salesSettlementTotal(DailyEntryDraft draft) {
    final modes = _settlementModes(draft);
    return modes.cash +
        modes.check +
        modes.upi +
        _pumpCreditTotal(draft) +
        _issuedCreditTotal(draft);
  }

  double _amountCollectedTotal(DailyEntryDraft draft) {
    return _salesSettlementTotal(draft) + _collectionRecoveryTotal(draft);
  }

  bool _supportsTwoT(String pumpId) => pumpId == 'pump2';

  String _twoTSoldLabel(PumpReadings opening, PumpReadings? closing) {
    if (closing == null) {
      return 'Not entered';
    }
    return formatLiters(closing.twoT - opening.twoT);
  }

  String _cashCollectedFromLabel(String pumpId, DailyEntryDraft? draft) {
    final name =
        draft?.pumpAttendants[pumpId]?.trim() ??
        _dashboard?.selectedEntry?.pumpAttendants[pumpId]?.trim() ??
        '';
    return name.isEmpty ? 'Not entered' : name;
  }

  PumpReadings _draftSoldTotals(
    SalesDashboardModel dashboard,
    DailyEntryDraft draft,
  ) {
    double petrol = 0;
    double diesel = 0;
    double twoT = 0;
    for (final pump in dashboard.station.pumps) {
      final opening = dashboard.openingReadings[pump.id];
      final closing = draft.closingReadings[pump.id];
      if (opening == null || closing == null) {
        continue;
      }
      final testing =
          draft.pumpTesting[pump.id] ??
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

  Future<void> _editPump(StationPumpModel pump) async {
    final dashboard = _dashboard;
    final draft = _draft;
    if (dashboard == null || draft == null) {
      return;
    }

    if (dashboard.entryExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This date already has a saved entry. Admin can edit it from Entries.',
          ),
        ),
      );
      return;
    }

    final result = await showPumpEntryDialog(
      context: context,
      pump: pump,
      opening:
          dashboard.openingReadings[pump.id] ??
          const PumpReadings(petrol: 0, diesel: 0, twoT: 0),
      limit:
          dashboard.station.meterLimits[pump.id] ??
          const PumpReadings(petrol: 0, diesel: 0, twoT: 0),
      initialDraft: PumpEntryDraft(
        attendant: draft.pumpAttendants[pump.id] ?? '',
        closingReadings: draft.closingReadings[pump.id],
        testing:
            draft.pumpTesting[pump.id] ??
            const PumpTestingModel(petrol: 0, diesel: 0),
        payments:
            draft.pumpPayments[pump.id] ??
            const PumpPaymentBreakdownModel(
              cash: 0,
              check: 0,
              upi: 0,
              credit: 0,
            ),
        creditEntries:
            draft.creditEntries
                .where((item) => item.pumpId == pump.id)
                .toList(),
        mismatchReason: draft.pumpMismatchReasons[pump.id] ?? '',
      ),
      suggestedCustomers: _suggestedCustomers,
      priceSnapshot: _resolvedPriceSnapshot,
      flagThreshold: dashboard.station.flagThreshold,
    );
    if (!mounted || result == null) {
      return;
    }

    _savePumpEdit(result.key, result.value);
  }

  Future<void> _submitEntry() async {
    final dashboard = _dashboard;
    final draft = _draft;
    if (dashboard == null || _selectedDate == null || draft == null) {
      return;
    }

    if (dashboard.entryExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This date already has a saved entry. Admin can edit it from Entries.',
          ),
        ),
      );
      return;
    }

    final missingPumps =
        dashboard.station.pumps
            .where((pump) => !draft.closingReadings.containsKey(pump.id))
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
        dashboard.station.pumps
            .where((pump) => !draft.pumpPayments.containsKey(pump.id))
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

    final pumpCreditTotal = _pumpCreditTotal(draft);
    final namedCreditTotal = _issuedCreditTotal(draft);
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

    await _previewAndSubmit(draft);
  }

  Future<void> _previewAndSubmit(DailyEntryDraft draft) async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final mismatchReason = _buildEntryMismatchReason(draft);
      final preview = await _salesService.previewEntry(
        date: draft.date,
        closingReadings: draft.closingReadings,
        pumpAttendants: draft.pumpAttendants,
        pumpTesting: draft.pumpTesting,
        pumpPayments: draft.pumpPayments,
        pumpCollections: draft.pumpCollections,
        paymentBreakdown: draft.paymentBreakdown,
        creditEntries: draft.creditEntries,
        creditCollections: draft.creditCollections,
        mismatchReason: mismatchReason,
      );

      if (!mounted) {
        return;
      }

      await _salesService.submitEntry(
        date: draft.date,
        closingReadings: draft.closingReadings,
        pumpAttendants: draft.pumpAttendants,
        pumpTesting: draft.pumpTesting,
        pumpPayments: draft.pumpPayments,
        pumpCollections: draft.pumpCollections,
        paymentBreakdown: draft.paymentBreakdown,
        creditEntries: draft.creditEntries,
        creditCollections: draft.creditCollections,
        mismatchReason: mismatchReason,
      );
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
      await _load(date: draft.date);
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
    final dashboard = _dashboard;
    final draft = _draft;
    final summary =
        dashboard != null && draft != null
            ? _draftSoldTotals(dashboard, draft)
            : const PumpReadings(petrol: 0, diesel: 0, twoT: 0);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      body:
          dashboard == null
              ? Center(
                child:
                    _error == null
                        ? const CircularProgressIndicator()
                        : Text(_error!, textAlign: TextAlign.center),
              )
              : ListView(
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
                        const Text(
                          'Daily Opening Meter Readings',
                          style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF55606E),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${dashboard.station.name} - ${formatDateLabel(_selectedDate ?? dashboard.date)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF293340),
                          ),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_month_rounded),
                          label: Text(
                            'Date: ${formatDateLabel(_selectedDate ?? dashboard.date)}',
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _HeaderMetric(
                              label: 'Revenue today',
                              value: formatCurrency(dashboard.revenue),
                            ),
                            _HeaderMetric(
                              label: 'Collected today',
                              value: formatCurrency(dashboard.paymentTotal),
                            ),
                            _HeaderMetric(
                              label: 'Entries today',
                              value: '${dashboard.entriesCompleted}/1',
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Add pump readings first. Payments and credit are updated from the overall summary section below.',
                          style: TextStyle(
                            color: Color(0xFF55606E),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...dashboard.station.pumps.map((pump) {
                    final opening =
                        dashboard.openingReadings[pump.id] ??
                        const PumpReadings(petrol: 0, diesel: 0, twoT: 0);
                    final existing = dashboard.selectedEntry;
                    final sold =
                        existing?.soldByPump[pump.id] ??
                        const PumpReadings(petrol: 0, diesel: 0, twoT: 0);
                    final attendant =
                        draft?.pumpAttendants[pump.id] ??
                        existing?.pumpAttendants[pump.id] ??
                        '';
                    final closing =
                        draft?.closingReadings[pump.id] ??
                        existing?.closingReadings[pump.id];
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
                              if (attendant.isNotEmpty)
                                Chip(label: Text(attendant)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _PumpRow(
                            label: 'Opening petrol meter',
                            value: formatLiters(opening.petrol),
                            accent: const Color(0xFF1E5CBA),
                          ),
                          _PumpRow(
                            label: 'Opening diesel meter',
                            value: formatLiters(opening.diesel),
                            accent: const Color(0xFF006C5C),
                          ),
                          const SizedBox(height: 10),
                          _PumpRow(
                            label: 'Entered closing petrol meter',
                            value:
                                closing == null
                                    ? 'Not entered'
                                    : formatLiters(closing.petrol),
                            accent: const Color(0xFF1E5CBA),
                          ),
                          _PumpRow(
                            label: 'Entered closing diesel meter',
                            value:
                                closing == null
                                    ? 'Not entered'
                                    : formatLiters(closing.diesel),
                            accent: const Color(0xFF006C5C),
                          ),
                          if (_supportsTwoT(pump.id))
                            _PumpRow(
                              label: 'Entered 2T oil sold',
                              value: _twoTSoldLabel(opening, closing),
                              accent: const Color(0xFFB45309),
                            ),
                          _PumpRow(
                            label: 'Cash collected from',
                            value: _cashCollectedFromLabel(pump.id, draft),
                            accent: const Color(0xFF92400E),
                          ),
                          _PumpRow(
                            label: 'Cash',
                            value:
                                draft?.pumpPayments.containsKey(pump.id) == true
                                    ? formatCurrency(
                                      draft?.pumpPayments[pump.id]?.cash ?? 0,
                                    )
                                    : 'Not entered',
                            accent: const Color(0xFFB45309),
                          ),
                          if (existing != null) ...[
                            const SizedBox(height: 10),
                            _PumpRow(
                              label: 'Petrol sold',
                              value: formatLiters(sold.petrol),
                              accent: const Color(0xFF1E5CBA),
                            ),
                            _PumpRow(
                              label: 'Diesel sold',
                              value: formatLiters(sold.diesel),
                              accent: const Color(0xFF006C5C),
                            ),
                            if (_supportsTwoT(pump.id))
                              _PumpRow(
                                label: '2T oil sold',
                                value: formatLiters(sold.twoT),
                                accent: const Color(0xFFB45309),
                              ),
                          ],
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  onPressed:
                                      _submitting || dashboard.entryExists
                                          ? null
                                          : () => _editPump(pump),
                                  icon: const Icon(Icons.payments_outlined),
                                  label: const Text('Cash Collection'),
                                ),
                                OutlinedButton.icon(
                                  onPressed:
                                      _submitting || dashboard.entryExists
                                          ? null
                                          : () => _editPump(pump),
                                  icon: const Icon(Icons.edit_rounded),
                                  label: const Text('Update Pump'),
                                ),
                              ],
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
                          'Cash, check, UPI, and pump credit come from the pump entries. Pump credit is calculated from the added credit rows for each pump. Old credit collection is handled from Credit Ledger.',
                          style: TextStyle(
                            color: Color(0xFF55606E),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _PaymentRow(
                          label: 'Total petrol sold',
                          value: formatLiters(summary.petrol),
                        ),
                        _PaymentRow(
                          label: 'Total diesel sold',
                          value: formatLiters(summary.diesel),
                        ),
                        _PaymentRow(
                          label: 'Total 2T oil sold',
                          value: formatLiters(summary.twoT),
                        ),
                        _PaymentRow(
                          label: 'Pump collection total',
                          value: formatCurrency(
                            draft == null ? 0 : _pumpCollectionTotal(draft),
                          ),
                        ),
                        _PaymentRow(
                          label: 'Cash total',
                          value: formatCurrency(
                            draft == null ? 0 : _settlementModes(draft).cash,
                          ),
                        ),
                        _PaymentRow(
                          label: 'Check total',
                          value: formatCurrency(
                            draft == null ? 0 : _settlementModes(draft).check,
                          ),
                        ),
                        _PaymentRow(
                          label: 'UPI total',
                          value: formatCurrency(
                            draft == null ? 0 : _settlementModes(draft).upi,
                          ),
                        ),
                        _PaymentRow(
                          label: 'Pump credit total',
                          value: formatCurrency(
                            draft == null ? 0 : _pumpCreditTotal(draft),
                          ),
                        ),
                        _PaymentRow(
                          label: 'New credit issued',
                          value: formatCurrency(
                            draft == null ? 0 : _issuedCreditTotal(draft),
                          ),
                        ),
                        _PaymentRow(
                          label: 'Old credit collected',
                          value: formatCurrency(
                            draft == null ? 0 : _collectionRecoveryTotal(draft),
                          ),
                        ),
                        _PaymentRow(
                          label: 'Sales settlement total',
                          value: formatCurrency(
                            draft == null ? 0 : _salesSettlementTotal(draft),
                          ),
                        ),
                        _PaymentRow(
                          label: 'Amount collected total',
                          value: formatCurrency(
                            draft == null ? 0 : _amountCollectedTotal(draft),
                          ),
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
                                draft == null || _pumpCreditTotal(draft) <= 0
                                    ? 'No pump credit added yet. Use Add Credit inside a pump to create customer-wise credit rows.'
                                    : 'Pump credit is built from the customer-wise credit rows added inside each pump. Once approved, these names will be shown in Credit Ledger.',
                                style: const TextStyle(
                                  color: Color(0xFF55606E),
                                  height: 1.4,
                                ),
                              ),
                              if (draft != null &&
                                  draft.creditEntries.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                ...draft.creditEntries.map(
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
                              const Text(
                                'Use Update Pump on the relevant pump to add or change credit customer rows.',
                                style: TextStyle(
                                  color: Color(0xFF55606E),
                                  height: 1.4,
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
                    onPressed: _submitting ? null : _submitEntry,
                    icon: const Icon(Icons.edit_note_rounded),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      backgroundColor: const Color(0xFF1E5CBA),
                    ),
                    label: Text(
                      _submitting
                          ? 'Submitting...'
                          : dashboard.entryExists
                          ? 'Entry Already Submitted'
                          : 'Submit Entry',
                    ),
                  ),
                ],
              ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF55606E),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF293340),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PumpRow extends StatelessWidget {
  const _PumpRow({
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

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.label, required this.value});

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
