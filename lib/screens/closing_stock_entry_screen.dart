import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/sales_service.dart';
import '../utils/formatters.dart';
import '../widgets/daily_entry_dialogs.dart';

class ClosingStockEntryScreen extends StatefulWidget {
  const ClosingStockEntryScreen({super.key});

  @override
  State<ClosingStockEntryScreen> createState() => _ClosingStockEntryScreenState();
}

class _ClosingStockEntryScreenState extends State<ClosingStockEntryScreen> {
  final SalesService _salesService = SalesService();
  SalesDashboardModel? _dashboard;
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
      final dashboard = await _salesService.fetchDashboardForDate(date: date);
      if (!mounted) {
        return;
      }
      setState(() {
        _dashboard = dashboard;
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
        mismatchReason: existing.mismatchReason,
      );
    }
    return DailyEntryDraft(
      date: dashboard.date,
      closingReadings: const {},
      pumpAttendants: {
        for (final pump in dashboard.station.pumps) pump.id: '',
      },
      pumpTesting: {
        for (final pump in dashboard.station.pumps) pump.id: false,
      },
      pumpPayments: const {},
      pumpCollections: const {},
      paymentBreakdown: const PaymentBreakdownModel(cash: 0, check: 0, upi: 0),
      creditEntries: const [],
    );
  }

  void _savePumpEdit(String pumpId, PumpEntryDraft pumpDraft) {
    final draft = _draft;
    if (draft == null) {
      return;
    }
    setState(() {
      _draft = draft.copyWith(
        closingReadings: {
          ...draft.closingReadings,
          if (pumpDraft.closingReadings != null) pumpId: pumpDraft.closingReadings!,
        },
        pumpAttendants: {
          ...draft.pumpAttendants,
          pumpId: pumpDraft.attendant,
        },
        pumpTesting: {
          ...draft.pumpTesting,
          pumpId: pumpDraft.testingEnabled,
        },
        pumpPayments: {
          ...draft.pumpPayments,
          pumpId: pumpDraft.payments,
        },
        pumpCollections: {
          ...draft.pumpCollections,
          pumpId: pumpDraft.payments.total,
        },
        paymentBreakdown: const PaymentBreakdownModel(
          cash: 0,
          check: 0,
          upi: 0,
        ),
      );
    });
  }

  double _overallCollection(DailyEntryDraft draft) {
    return draft.pumpPayments.values.fold<double>(0, (sum, value) => sum + value.total);
  }

  PaymentBreakdownModel _overallPaymentModes(DailyEntryDraft draft) {
    return draft.pumpPayments.values.fold(
      const PaymentBreakdownModel(cash: 0, check: 0, upi: 0),
      (sum, value) => PaymentBreakdownModel(
        cash: sum.cash + value.cash,
        check: sum.check + value.check,
        upi: sum.upi + value.upi,
      ),
    );
  }

  double _overallCredit(DailyEntryDraft draft) {
    return draft.pumpPayments.values.fold<double>(0, (sum, value) => sum + value.credit);
  }

  bool _supportsTwoT(String pumpId) => pumpId == 'pump2';

  PumpReadings _draftSoldTotals(SalesDashboardModel dashboard, DailyEntryDraft draft) {
    double petrol = 0;
    double diesel = 0;
    double twoT = 0;
    for (final pump in dashboard.station.pumps) {
      final opening = dashboard.openingReadings[pump.id];
      final closing = draft.closingReadings[pump.id];
      if (opening == null || closing == null) {
        continue;
      }
      petrol += opening.petrol - closing.petrol;
      diesel += opening.diesel - closing.diesel;
      if (_supportsTwoT(pump.id)) {
        twoT += opening.twoT - closing.twoT;
      }
    }
    return PumpReadings(petrol: petrol, diesel: diesel, twoT: twoT);
  }

  Future<void> _openEditor() async {
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

    final missingPumps = dashboard.station.pumps
        .where((pump) => !draft.closingReadings.containsKey(pump.id))
        .map((pump) => pump.label)
        .toList();
    if (missingPumps.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Enter closing readings for ${missingPumps.join(', ')} before review.',
          ),
        ),
      );
      return;
    }

    final missingCollections = dashboard.station.pumps
        .where((pump) => !draft.pumpPayments.containsKey(pump.id))
        .map((pump) => pump.label)
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

    await _previewAndSubmit(draft);
  }

  Future<void> _previewAndSubmit(DailyEntryDraft draft) async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final preview = await _salesService.previewEntry(
        date: draft.date,
        closingReadings: draft.closingReadings,
        pumpAttendants: draft.pumpAttendants,
        pumpTesting: draft.pumpTesting,
        pumpPayments: draft.pumpPayments,
        pumpCollections: draft.pumpCollections,
        paymentBreakdown: const PaymentBreakdownModel(
          cash: 0,
          check: 0,
          upi: 0,
        ),
        creditEntries: draft.creditEntries,
        mismatchReason: draft.mismatchReason,
      );

      if (!mounted) {
        return;
      }

      final mismatchReason = await showDailyEntryPreviewDialog(
        context: context,
        preview: preview,
        initialMismatchReason: draft.mismatchReason,
      );
      if (mismatchReason == null) {
        return;
      }

      await _salesService.submitEntry(
        date: draft.date,
        closingReadings: draft.closingReadings,
        pumpAttendants: draft.pumpAttendants,
        pumpTesting: draft.pumpTesting,
        pumpPayments: draft.pumpPayments,
        pumpCollections: draft.pumpCollections,
        paymentBreakdown: const PaymentBreakdownModel(
          cash: 0,
          check: 0,
          upi: 0,
        ),
        creditEntries: draft.creditEntries,
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
    final summary = dashboard != null && draft != null
        ? _draftSoldTotals(dashboard, draft)
        : const PumpReadings(petrol: 0, diesel: 0, twoT: 0);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      body: dashboard == null
          ? Center(
              child: _error == null
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
                        'Daily Opening Readings',
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
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ...dashboard.station.pumps.map(
                  (pump) {
                    final opening =
                        dashboard.openingReadings[pump.id] ??
                        const PumpReadings(petrol: 0, diesel: 0, twoT: 0);
                    final existing = dashboard.selectedEntry;
                    final sold = existing?.soldByPump[pump.id] ??
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
                                  pump.label,
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
                            label: 'Opening petrol',
                            value: formatLiters(opening.petrol),
                            accent: const Color(0xFF1E5CBA),
                          ),
                          _PumpRow(
                            label: 'Opening diesel',
                            value: formatLiters(opening.diesel),
                            accent: const Color(0xFF006C5C),
                          ),
                          if (_supportsTwoT(pump.id))
                            _PumpRow(
                              label: 'Opening 2T oil',
                              value: formatLiters(opening.twoT),
                              accent: const Color(0xFFB45309),
                            ),
                          const SizedBox(height: 10),
                          _PumpRow(
                            label: 'Entered closing petrol',
                            value: closing == null
                                ? 'Not entered'
                                : formatLiters(closing.petrol),
                            accent: const Color(0xFF1E5CBA),
                          ),
                          _PumpRow(
                            label: 'Entered closing diesel',
                            value: closing == null
                                ? 'Not entered'
                                : formatLiters(closing.diesel),
                            accent: const Color(0xFF006C5C),
                          ),
                          if (_supportsTwoT(pump.id))
                            _PumpRow(
                              label: 'Entered closing 2T oil',
                              value: closing == null
                                  ? 'Not entered'
                                  : formatLiters(closing.twoT),
                              accent: const Color(0xFFB45309),
                            ),
                          _PumpRow(
                            label: 'Cash',
                            value: draft?.pumpPayments.containsKey(pump.id) == true
                                ? formatCurrency(draft?.pumpPayments[pump.id]?.cash ?? 0)
                                : 'Not entered',
                            accent: const Color(0xFFB45309),
                          ),
                          _PumpRow(
                            label: 'Check',
                            value: draft?.pumpPayments.containsKey(pump.id) == true
                                ? formatCurrency(draft?.pumpPayments[pump.id]?.check ?? 0)
                                : 'Not entered',
                            accent: const Color(0xFF6B7280),
                          ),
                          _PumpRow(
                            label: 'UPI',
                            value: draft?.pumpPayments.containsKey(pump.id) == true
                                ? formatCurrency(draft?.pumpPayments[pump.id]?.upi ?? 0)
                                : 'Not entered',
                            accent: const Color(0xFF7C3AED),
                          ),
                          _PumpRow(
                            label: 'Credit',
                            value: draft?.pumpPayments.containsKey(pump.id) == true
                                ? formatCurrency(draft?.pumpPayments[pump.id]?.credit ?? 0)
                                : 'Not entered',
                            accent: const Color(0xFFDC2626),
                          ),
                          _PumpRow(
                            label: 'Total collection',
                            value: draft?.pumpPayments.containsKey(pump.id) == true
                                ? formatCurrency(draft?.pumpPayments[pump.id]?.total ?? 0)
                                : 'Not entered',
                            accent: const Color(0xFFB45309),
                          ),
                          _PumpRow(
                            label: 'Testing',
                            value: draft?.pumpTesting[pump.id] == true
                                ? '5L excluded'
                                : 'Off',
                            accent: const Color(0xFF7C3AED),
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
                          _PumpEntryCard(
                            pump: pump,
                            opening: opening,
                            currentAttendant: attendant,
                            currentClosing: draft?.closingReadings[pump.id],
                            testingEnabled: draft?.pumpTesting[pump.id] == true,
                            currentPayments: draft?.pumpPayments[pump.id],
                            supportsTwoT: _supportsTwoT(pump.id),
                            submitting: _submitting,
                            onSave: (pumpDraft) => _savePumpEdit(pump.id, pumpDraft),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Overall Summary',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF293340),
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
                        label: 'Overall collection',
                        value: formatCurrency(
                          draft == null ? 0 : _overallCollection(draft),
                        ),
                      ),
                      _PaymentRow(
                        label: 'Cash total',
                        value: formatCurrency(
                          draft == null ? 0 : _overallPaymentModes(draft).cash,
                        ),
                      ),
                      _PaymentRow(
                        label: 'Check total',
                        value: formatCurrency(
                          draft == null ? 0 : _overallPaymentModes(draft).check,
                        ),
                      ),
                      _PaymentRow(
                        label: 'UPI total',
                        value: formatCurrency(
                          draft == null ? 0 : _overallPaymentModes(draft).upi,
                        ),
                      ),
                      _PaymentRow(
                        label: 'Credit total',
                        value: formatCurrency(
                          draft == null ? 0 : _overallCredit(draft),
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
                  onPressed: _submitting ? null : _openEditor,
                  icon: const Icon(Icons.edit_note_rounded),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    backgroundColor: const Color(0xFF1E5CBA),
                  ),
                  label: Text(
                    _submitting
                        ? 'Preparing...'
                        : dashboard.entryExists
                        ? 'Entry Already Submitted'
                        : 'Review Entry',
                  ),
                ),
              ],
            ),
    );
  }
}

class _PumpEntryCard extends StatefulWidget {
  const _PumpEntryCard({
    required this.pump,
    required this.opening,
    required this.currentAttendant,
    required this.currentClosing,
    required this.testingEnabled,
    required this.currentPayments,
    required this.supportsTwoT,
    required this.submitting,
    required this.onSave,
  });

  final StationPumpModel pump;
  final PumpReadings opening;
  final String currentAttendant;
  final PumpReadings? currentClosing;
  final bool testingEnabled;
  final PumpPaymentBreakdownModel? currentPayments;
  final bool supportsTwoT;
  final bool submitting;
  final ValueChanged<PumpEntryDraft> onSave;

  @override
  State<_PumpEntryCard> createState() => _PumpEntryCardState();
}

class _PumpEntryCardState extends State<_PumpEntryCard> {
  final TextEditingController _attendantController = TextEditingController();
  final TextEditingController _petrolController = TextEditingController();
  final TextEditingController _dieselController = TextEditingController();
  final TextEditingController _twoTController = TextEditingController();
  final TextEditingController _cashController = TextEditingController();
  final TextEditingController _checkController = TextEditingController();
  final TextEditingController _upiController = TextEditingController();
  final TextEditingController _creditController = TextEditingController();
  bool _testingEnabled = false;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _syncFromWidget();
  }

  @override
  void didUpdateWidget(covariant _PumpEntryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing) {
      _syncFromWidget();
    }
  }

  @override
  void dispose() {
    _attendantController.dispose();
    _petrolController.dispose();
    _dieselController.dispose();
    _twoTController.dispose();
    _cashController.dispose();
    _checkController.dispose();
    _upiController.dispose();
    _creditController.dispose();
    super.dispose();
  }

  void _syncFromWidget() {
    _attendantController.text = widget.currentAttendant;
    _petrolController.text = widget.currentClosing == null
        ? ''
        : widget.currentClosing!.petrol.toStringAsFixed(2);
    _dieselController.text = widget.currentClosing == null
        ? ''
        : widget.currentClosing!.diesel.toStringAsFixed(2);
    _twoTController.text = widget.currentClosing == null || widget.currentClosing!.twoT == 0
        ? ''
        : widget.currentClosing!.twoT.toStringAsFixed(2);
    _cashController.text = widget.currentPayments == null || widget.currentPayments!.cash == 0
        ? ''
        : widget.currentPayments!.cash.toStringAsFixed(2);
    _checkController.text = widget.currentPayments == null || widget.currentPayments!.check == 0
        ? ''
        : widget.currentPayments!.check.toStringAsFixed(2);
    _upiController.text = widget.currentPayments == null || widget.currentPayments!.upi == 0
        ? ''
        : widget.currentPayments!.upi.toStringAsFixed(2);
    _creditController.text = widget.currentPayments == null || widget.currentPayments!.credit == 0
        ? ''
        : widget.currentPayments!.credit.toStringAsFixed(2);
    _testingEnabled = widget.testingEnabled;
  }

  void _startEditing() {
    setState(() {
      _syncFromWidget();
      _editing = true;
    });
  }

  void _cancelEditing() {
    FocusScope.of(context).unfocus();
    setState(() {
      _syncFromWidget();
      _editing = false;
    });
  }

  void _commitEditing() {
    final pumpDraft = PumpEntryDraft(
      attendant: _attendantController.text.trim(),
      closingReadings: PumpReadings(
        petrol: double.tryParse(_petrolController.text) ?? 0,
        diesel: double.tryParse(_dieselController.text) ?? 0,
        twoT: widget.supportsTwoT
            ? (double.tryParse(_twoTController.text) ?? 0)
            : 0,
      ),
      testingEnabled: _testingEnabled,
      payments: PumpPaymentBreakdownModel(
        cash: double.tryParse(_cashController.text) ?? 0,
        check: double.tryParse(_checkController.text) ?? 0,
        upi: double.tryParse(_upiController.text) ?? 0,
        credit: double.tryParse(_creditController.text) ?? 0,
      ),
    );

    FocusScope.of(context).unfocus();
    setState(() {
      _editing = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.onSave(pumpDraft);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return Column(
        children: [
          TextField(
            controller: _attendantController,
            decoration: const InputDecoration(
              labelText: 'Pump attendant name',
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _petrolController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText:
                  'Petrol closing reading - opening ${formatLiters(widget.opening.petrol)}',
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _dieselController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText:
                  'Diesel closing reading - opening ${formatLiters(widget.opening.diesel)}',
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          if (widget.supportsTwoT) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _twoTController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText:
                    '2T oil closing reading - opening ${formatLiters(widget.opening.twoT)}',
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _cashController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Cash',
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _checkController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Check',
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _upiController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'UPI',
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _creditController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Credit',
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _testingEnabled,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Testing'),
            subtitle: const Text('Exclude 5L from billed sale for this pump.'),
            onChanged: widget.submitting
                ? null
                : (value) {
                    setState(() {
                      _testingEnabled = value ?? false;
                    });
                  },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.submitting ? null : _cancelEditing,
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: widget.submitting ? null : _commitEditing,
                  child: const Text('Update Pump'),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Align(
      alignment: Alignment.centerRight,
      child: OutlinedButton.icon(
        onPressed: widget.submitting ? null : _startEditing,
        icon: const Icon(Icons.edit_rounded),
        label: const Text('Update Pump'),
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({
    required this.label,
    required this.value,
  });

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
  const _PaymentRow({
    required this.label,
    required this.value,
  });

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
