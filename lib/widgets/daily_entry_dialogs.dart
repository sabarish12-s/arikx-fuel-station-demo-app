import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../utils/formatters.dart';

Future<DailyEntryDraft?> showDailyEntryEditorDialog({
  required BuildContext context,
  required StationConfigModel station,
  required String title,
  required String initialDate,
  required Map<String, PumpReadings> openingReadings,
  DailyEntryDraft? initialDraft,
  bool allowDateEdit = true,
}) async {
  final Map<String, TextEditingController> petrolControllers = {};
  final Map<String, TextEditingController> dieselControllers = {};
  final Map<String, TextEditingController> twoTControllers = {};
  final Map<String, TextEditingController> attendantControllers = {};
  final Map<String, TextEditingController> cashControllers = {};
  final Map<String, TextEditingController> checkControllers = {};
  final Map<String, TextEditingController> upiControllers = {};
  final Map<String, TextEditingController> creditControllers = {};
  final Map<String, bool> testingValues = {};
  String selectedDate = initialDraft?.date ?? initialDate;

  for (final pump in station.pumps) {
    final opening = openingReadings[pump.id] ??
        const PumpReadings(petrol: 0, diesel: 0, twoT: 0);
    final seeded = initialDraft?.closingReadings[pump.id];
    petrolControllers[pump.id] = TextEditingController(
      text: (seeded?.petrol ?? opening.petrol).toStringAsFixed(2),
    );
    dieselControllers[pump.id] = TextEditingController(
      text: (seeded?.diesel ?? opening.diesel).toStringAsFixed(2),
    );
    twoTControllers[pump.id] = TextEditingController(
      text: pump.id != 'pump2'
          ? ''
          : (seeded?.twoT ?? opening.twoT).toStringAsFixed(2),
    );
    attendantControllers[pump.id] = TextEditingController(
      text: initialDraft?.pumpAttendants[pump.id] ?? '',
    );
    testingValues[pump.id] = initialDraft?.pumpTesting[pump.id] == true;
    cashControllers[pump.id] = TextEditingController(
      text: (initialDraft?.pumpPayments[pump.id]?.cash ?? 0) == 0
          ? ''
          : (initialDraft?.pumpPayments[pump.id]?.cash ?? 0).toStringAsFixed(2),
    );
    checkControllers[pump.id] = TextEditingController(
      text: (initialDraft?.pumpPayments[pump.id]?.check ?? 0) == 0
          ? ''
          : (initialDraft?.pumpPayments[pump.id]?.check ?? 0).toStringAsFixed(2),
    );
    upiControllers[pump.id] = TextEditingController(
      text: (initialDraft?.pumpPayments[pump.id]?.upi ?? 0) == 0
          ? ''
          : (initialDraft?.pumpPayments[pump.id]?.upi ?? 0).toStringAsFixed(2),
    );
    creditControllers[pump.id] = TextEditingController(
      text: (initialDraft?.pumpPayments[pump.id]?.credit ?? 0) == 0
          ? ''
          : (initialDraft?.pumpPayments[pump.id]?.credit ?? 0).toStringAsFixed(2),
    );
  }

  DailyEntryDraft? result;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  station.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF55606E),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: !allowDateEdit
                      ? null
                      : () async {
                          final initial =
                              DateTime.tryParse(selectedDate) ?? DateTime.now();
                          final picked = await showDatePicker(
                            context: dialogContext,
                            initialDate: initial,
                            firstDate: DateTime(2024),
                            lastDate: DateTime.now(),
                            helpText: 'Select entry date',
                          );
                          if (picked == null) {
                            return;
                          }
                          final month = picked.month.toString().padLeft(2, '0');
                          final day = picked.day.toString().padLeft(2, '0');
                          setDialogState(() {
                            selectedDate = '${picked.year}-$month-$day';
                          });
                        },
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: Text(formatDateLabel(selectedDate)),
                ),
                const SizedBox(height: 16),
                ...station.pumps.map(
                  (pump) {
                    final opening = openingReadings[pump.id] ??
                        const PumpReadings(petrol: 0, diesel: 0, twoT: 0);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FF),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pump.label,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF293340),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: attendantControllers[pump.id],
                            decoration: const InputDecoration(
                              labelText: 'Pump attendant name',
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: petrolControllers[pump.id],
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText:
                                  'Petrol closing reading - opening ${formatLiters(opening.petrol)}',
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: dieselControllers[pump.id],
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText:
                                  'Diesel closing reading - opening ${formatLiters(opening.diesel)}',
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                          if (pump.id == 'pump2') ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: twoTControllers[pump.id],
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                labelText:
                                    '2T oil closing reading - opening ${formatLiters(opening.twoT)}',
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          TextField(
                            controller: cashControllers[pump.id],
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Cash',
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: checkControllers[pump.id],
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Check',
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: upiControllers[pump.id],
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'UPI',
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: creditControllers[pump.id],
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Credit',
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          CheckboxListTile(
                            value: testingValues[pump.id] == true,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: const Text('Testing'),
                            subtitle: const Text(
                              'Exclude 5L from billed sale for this pump.',
                            ),
                            onChanged: (value) {
                              setDialogState(() {
                                testingValues[pump.id] = value ?? false;
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final closingReadings = <String, PumpReadings>{};
              final attendants = <String, String>{};
              final pumpTesting = <String, bool>{};
              final pumpPayments = <String, PumpPaymentBreakdownModel>{};
              final pumpCollections = <String, double>{};
              for (final pump in station.pumps) {
                closingReadings[pump.id] = PumpReadings(
                  petrol:
                      double.tryParse(petrolControllers[pump.id]?.text ?? '') ?? 0,
                  diesel:
                      double.tryParse(dieselControllers[pump.id]?.text ?? '') ?? 0,
                  twoT: pump.id == 'pump2'
                      ? (double.tryParse(twoTControllers[pump.id]?.text ?? '') ?? 0)
                      : 0,
                );
                attendants[pump.id] =
                    attendantControllers[pump.id]?.text.trim() ?? '';
                pumpTesting[pump.id] = testingValues[pump.id] == true;
                final payments = PumpPaymentBreakdownModel(
                  cash: double.tryParse(cashControllers[pump.id]?.text ?? '') ?? 0,
                  check: double.tryParse(checkControllers[pump.id]?.text ?? '') ?? 0,
                  upi: double.tryParse(upiControllers[pump.id]?.text ?? '') ?? 0,
                  credit: double.tryParse(creditControllers[pump.id]?.text ?? '') ?? 0,
                );
                pumpPayments[pump.id] = payments;
                pumpCollections[pump.id] = payments.total;
              }

              result = DailyEntryDraft(
                date: selectedDate,
                closingReadings: closingReadings,
                pumpAttendants: attendants,
                pumpTesting: pumpTesting,
                pumpPayments: pumpPayments,
                pumpCollections: pumpCollections,
                paymentBreakdown: const PaymentBreakdownModel(cash: 0, check: 0, upi: 0),
                creditEntries: const [],
              );
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Review Entry'),
          ),
        ],
      ),
    ),
  );

  for (final controller in petrolControllers.values) {
    controller.dispose();
  }
  for (final controller in dieselControllers.values) {
    controller.dispose();
  }
  for (final controller in twoTControllers.values) {
    controller.dispose();
  }
  for (final controller in attendantControllers.values) {
    controller.dispose();
  }
  for (final controller in cashControllers.values) {
    controller.dispose();
  }
  for (final controller in checkControllers.values) {
    controller.dispose();
  }
  for (final controller in upiControllers.values) {
    controller.dispose();
  }
  for (final controller in creditControllers.values) {
    controller.dispose();
  }

  return result;
}

Future<String?> showDailyEntryPreviewDialog({
  required BuildContext context,
  required ShiftEntryModel preview,
  String initialMismatchReason = '',
}) async {
  final TextEditingController reasonController = TextEditingController(
    text: initialMismatchReason,
  );
  String? result;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: const Text('Confirm Entry'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatDateLabel(preview.date),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              ...preview.soldByPump.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${entry.key}: ${formatLiters(entry.value.petrol)} petrol, ${formatLiters(entry.value.diesel)} diesel, ${formatLiters(entry.value.twoT)} 2T oil, cash ${formatCurrency(preview.pumpPayments[entry.key]?.cash ?? 0)}, check ${formatCurrency(preview.pumpPayments[entry.key]?.check ?? 0)}, upi ${formatCurrency(preview.pumpPayments[entry.key]?.upi ?? 0)}, credit ${formatCurrency(preview.pumpPayments[entry.key]?.credit ?? 0)}${preview.pumpTesting[entry.key] == true ? ', testing 5L excluded' : ''}',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text('Computed revenue ${formatCurrency(preview.computedRevenue)}'),
              Text('Money collected ${formatCurrency(preview.paymentTotal)}'),
              Text('Petrol sold ${formatLiters(preview.totals.sold.petrol)}'),
              Text('Diesel sold ${formatLiters(preview.totals.sold.diesel)}'),
              Text('2T oil sold ${formatLiters(preview.totals.sold.twoT)}'),
              if (preview.mismatchAmount != 0) ...[
                const SizedBox(height: 12),
                Text(
                  'Mismatch ${formatCurrency(preview.mismatchAmount.abs())}',
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Mismatch reason',
                    hintText: 'Required when payment total does not match revenue',
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
              ],
              if (preview.varianceNote.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  preview.varianceNote,
                  style: const TextStyle(color: Color(0xFFB91C1C)),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: preview.mismatchAmount != 0 &&
                    reasonController.text.trim().isEmpty
                ? null
                : () {
                    result = reasonController.text.trim();
                    Navigator.of(dialogContext).pop();
                  },
            child: const Text('Confirm'),
          ),
        ],
      ),
    ),
  );

  reasonController.dispose();
  return result;
}

Future<MapEntry<String, PumpEntryDraft>?> showPumpEntryDialog({
  required BuildContext context,
  required StationPumpModel pump,
  required PumpReadings opening,
  required PumpEntryDraft initialDraft,
}) async {
  return Navigator.of(context).push<MapEntry<String, PumpEntryDraft>>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _PumpEntryPage(
        pump: pump,
        opening: opening,
        initialDraft: initialDraft,
      ),
    ),
  );
}

Future<PaymentEntryDraft?> showPaymentEntryDialog({
  required BuildContext context,
  required PaymentEntryDraft initialDraft,
}) async {
  return Navigator.of(context).push<PaymentEntryDraft>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _PaymentEntryPage(initialDraft: initialDraft),
    ),
  );
}

class _PumpEntryPage extends StatefulWidget {
  const _PumpEntryPage({
    required this.pump,
    required this.opening,
    required this.initialDraft,
  });

  final StationPumpModel pump;
  final PumpReadings opening;
  final PumpEntryDraft initialDraft;

  @override
  State<_PumpEntryPage> createState() => _PumpEntryPageState();
}

class _PumpEntryPageState extends State<_PumpEntryPage> {
  late final TextEditingController _attendantController;
  late final TextEditingController _petrolController;
  late final TextEditingController _dieselController;
  late final TextEditingController _twoTController;
  late final TextEditingController _cashController;
  late final TextEditingController _checkController;
  late final TextEditingController _upiController;
  late final TextEditingController _creditController;
  late bool _testingEnabled;

  @override
  void initState() {
    super.initState();
    _attendantController = TextEditingController(
      text: widget.initialDraft.attendant,
    );
    _petrolController = TextEditingController(
      text: widget.initialDraft.closingReadings == null
          ? ''
          : widget.initialDraft.closingReadings!.petrol.toStringAsFixed(2),
    );
    _dieselController = TextEditingController(
      text: widget.initialDraft.closingReadings == null
          ? ''
          : widget.initialDraft.closingReadings!.diesel.toStringAsFixed(2),
    );
    _twoTController = TextEditingController(
      text: widget.initialDraft.closingReadings == null ||
              widget.initialDraft.closingReadings!.twoT == 0
          ? ''
          : widget.initialDraft.closingReadings!.twoT.toStringAsFixed(2),
    );
    _cashController = TextEditingController(
      text: widget.initialDraft.payments.cash == 0
          ? ''
          : widget.initialDraft.payments.cash.toStringAsFixed(2),
    );
    _checkController = TextEditingController(
      text: widget.initialDraft.payments.check == 0
          ? ''
          : widget.initialDraft.payments.check.toStringAsFixed(2),
    );
    _upiController = TextEditingController(
      text: widget.initialDraft.payments.upi == 0
          ? ''
          : widget.initialDraft.payments.upi.toStringAsFixed(2),
    );
    _creditController = TextEditingController(
      text: widget.initialDraft.payments.credit == 0
          ? ''
          : widget.initialDraft.payments.credit.toStringAsFixed(2),
    );
    _testingEnabled = widget.initialDraft.testingEnabled;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        title: Text('Update ${widget.pump.label}'),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
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
            if (widget.pump.id == 'pump2') ...[
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
              onChanged: (value) {
                setState(() {
                  _testingEnabled = value ?? false;
                });
              },
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(
                  MapEntry(
                    widget.pump.id,
                    PumpEntryDraft(
                      attendant: _attendantController.text.trim(),
                      closingReadings: PumpReadings(
                        petrol: double.tryParse(_petrolController.text) ?? 0,
                        diesel: double.tryParse(_dieselController.text) ?? 0,
                        twoT: widget.pump.id == 'pump2'
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
                    ),
                  ),
                );
              },
              child: const Text('Update Pump'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentEntryPage extends StatefulWidget {
  const _PaymentEntryPage({
    required this.initialDraft,
  });

  final PaymentEntryDraft initialDraft;

  @override
  State<_PaymentEntryPage> createState() => _PaymentEntryPageState();
}

class _PaymentEntryPageState extends State<_PaymentEntryPage> {
  late final TextEditingController _cashController;
  late final TextEditingController _checkController;
  late final TextEditingController _upiController;
  late List<Map<String, TextEditingController>> _creditControllers;

  @override
  void initState() {
    super.initState();
    _cashController = TextEditingController(
      text: widget.initialDraft.paymentBreakdown.cash.toStringAsFixed(2),
    );
    _checkController = TextEditingController(
      text: widget.initialDraft.paymentBreakdown.check.toStringAsFixed(2),
    );
    _upiController = TextEditingController(
      text: widget.initialDraft.paymentBreakdown.upi.toStringAsFixed(2),
    );
    _creditControllers = widget.initialDraft.creditEntries.isEmpty
        ? [
            {
              'name': TextEditingController(),
              'amount': TextEditingController(),
            },
          ]
        : widget.initialDraft.creditEntries
            .map(
              (entry) => {
                'name': TextEditingController(text: entry.name),
                'amount': TextEditingController(
                  text: entry.amount.toStringAsFixed(2),
                ),
              },
            )
            .toList();
  }

  @override
  void dispose() {
    _cashController.dispose();
    _checkController.dispose();
    _upiController.dispose();
    for (final item in _creditControllers) {
      for (final controller in item.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  void _addCreditEntry() {
    setState(() {
      _creditControllers = [
        ..._creditControllers,
        {
          'name': TextEditingController(),
          'amount': TextEditingController(),
        },
      ];
    });
  }

  void _removeCreditEntry(int index) {
    final removed = _creditControllers[index];
    for (final controller in removed.values) {
      controller.dispose();
    }
    setState(() {
      _creditControllers = [
        ..._creditControllers.sublist(0, index),
        ..._creditControllers.sublist(index + 1),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        title: const Text('Update Payments'),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          children: [
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
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Credit Entries',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF293340),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _addCreditEntry,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...List.generate(_creditControllers.length, (index) {
              final item = _creditControllers[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: item['name'],
                      decoration: InputDecoration(
                        labelText: 'Credit customer ${index + 1}',
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: item['amount'],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Credit amount',
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    if (_creditControllers.length > 1)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => _removeCreditEntry(index),
                          child: const Text('Remove'),
                        ),
                      ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(
                  PaymentEntryDraft(
                    paymentBreakdown: PaymentBreakdownModel(
                      cash: double.tryParse(_cashController.text) ?? 0,
                      check: double.tryParse(_checkController.text) ?? 0,
                      upi: double.tryParse(_upiController.text) ?? 0,
                    ),
                    creditEntries: _creditControllers
                        .map(
                          (item) => CreditEntryModel(
                            name: item['name']?.text.trim() ?? '',
                            amount: double.tryParse(item['amount']?.text ?? '') ?? 0,
                          ),
                        )
                        .where((item) => item.name.isNotEmpty && item.amount > 0)
                        .toList(),
                  ),
                );
              },
              child: const Text('Update Payments'),
            ),
          ],
        ),
      ),
    );
  }
}
