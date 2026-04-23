import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../utils/fuel_prices.dart';
import '../utils/formatters.dart';
import 'busy_action_button.dart';
import 'clay_widgets.dart';
import 'responsive_text.dart';

const double _defaultTestingQuantity = 5;
const double _readingComparisonTolerance = 0.005;
const String _creditCustomerModeExisting = 'existing';
const String _creditCustomerModeNew = 'new';

String _formatTestingQuantityInput(double quantity) {
  if (quantity <= 0) {
    return '';
  }
  return quantity == quantity.truncateToDouble()
      ? quantity.toStringAsFixed(0)
      : quantity.toStringAsFixed(2);
}

String _testingSubtitle(PumpTestingModel testing) {
  final inventoryText = testing.addToInventory
      ? 'Testing will also reduce inventory.'
      : 'Testing will not reduce inventory.';
  return 'Exclude petrol ${formatLiters(testing.petrol)} and diesel ${formatLiters(testing.diesel)} from billed sale for this pump. $inventoryText';
}

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
  final Map<String, bool> testingInventoryValues = {};
  final Map<String, TextEditingController> testingPetrolControllers = {};
  final Map<String, TextEditingController> testingDieselControllers = {};
  String selectedDate = initialDraft?.date ?? initialDate;

  for (final pump in station.pumps) {
    final opening =
        openingReadings[pump.id] ??
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
    final testing =
        initialDraft?.pumpTesting[pump.id] ??
        const PumpTestingModel(petrol: 0, diesel: 0);
    testingValues[pump.id] = testing.enabled;
    testingInventoryValues[pump.id] = testing.addToInventory;
    testingPetrolControllers[pump.id] = TextEditingController(
      text: _formatTestingQuantityInput(testing.petrol),
    );
    testingDieselControllers[pump.id] = TextEditingController(
      text: _formatTestingQuantityInput(testing.diesel),
    );
    cashControllers[pump.id] = TextEditingController(
      text: (initialDraft?.pumpPayments[pump.id]?.cash ?? 0) == 0
          ? ''
          : (initialDraft?.pumpPayments[pump.id]?.cash ?? 0).toStringAsFixed(2),
    );
    checkControllers[pump.id] = TextEditingController(
      text: (initialDraft?.pumpPayments[pump.id]?.check ?? 0) == 0
          ? ''
          : (initialDraft?.pumpPayments[pump.id]?.check ?? 0).toStringAsFixed(
              2,
            ),
    );
    upiControllers[pump.id] = TextEditingController(
      text: (initialDraft?.pumpPayments[pump.id]?.upi ?? 0) == 0
          ? ''
          : (initialDraft?.pumpPayments[pump.id]?.upi ?? 0).toStringAsFixed(2),
    );
    creditControllers[pump.id] = TextEditingController(
      text: (initialDraft?.pumpPayments[pump.id]?.credit ?? 0) == 0
          ? ''
          : (initialDraft?.pumpPayments[pump.id]?.credit ?? 0).toStringAsFixed(
              2,
            ),
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
                ...station.pumps.map((pump) {
                  final opening =
                      openingReadings[pump.id] ??
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
                          formatPumpLabel(pump.id, pump.label),
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
                                'Petrol closing meter reading - opening ${formatLiters(opening.petrol)}',
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
                                'Diesel closing meter reading - opening ${formatLiters(opening.diesel)}',
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
                                  '2T oil closing meter reading - opening ${formatLiters(opening.twoT)}',
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
                            labelText: 'HP Pay',
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
                          subtitle: Text(
                            _testingSubtitle(
                              testingValues[pump.id] == true
                                  ? PumpTestingModel(
                                      petrol: parseTestingQuantity(
                                        testingPetrolControllers[pump.id]
                                                ?.text ??
                                            '',
                                      ),
                                      diesel: parseTestingQuantity(
                                        testingDieselControllers[pump.id]
                                                ?.text ??
                                            '',
                                      ),
                                      addToInventory:
                                          testingInventoryValues[pump.id] ==
                                          true,
                                    )
                                  : const PumpTestingModel(
                                      petrol: _defaultTestingQuantity,
                                      diesel: _defaultTestingQuantity,
                                    ),
                            ),
                          ),
                          onChanged: (value) {
                            setDialogState(() {
                              testingValues[pump.id] = value ?? false;
                              final petrolController =
                                  testingPetrolControllers[pump.id];
                              final dieselController =
                                  testingDieselControllers[pump.id];
                              if (testingValues[pump.id] == true) {
                                if (parseTestingQuantity(
                                      petrolController?.text ?? '',
                                    ) <=
                                    0) {
                                  petrolController?.text =
                                      _formatTestingQuantityInput(
                                        _defaultTestingQuantity,
                                      );
                                }
                                if (parseTestingQuantity(
                                      dieselController?.text ?? '',
                                    ) <=
                                    0) {
                                  dieselController?.text =
                                      _formatTestingQuantityInput(
                                        _defaultTestingQuantity,
                                      );
                                }
                              } else {
                                testingInventoryValues[pump.id] = false;
                              }
                            });
                          },
                        ),
                        if (testingValues[pump.id] == true) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: testingPetrolControllers[pump.id],
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Testing petrol quantity',
                              helperText:
                                  'This value is excluded only from petrol sales.',
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: testingDieselControllers[pump.id],
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Testing diesel quantity',
                              helperText:
                                  'This value is excluded only from diesel sales.',
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          CheckboxListTile(
                            value: testingInventoryValues[pump.id] == true,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: const Text('Reduce testing from inventory'),
                            subtitle: const Text(
                              'If selected, inventory will reduce by the testing quantity too.',
                            ),
                            onChanged: (value) {
                              setDialogState(() {
                                testingInventoryValues[pump.id] =
                                    value ?? false;
                              });
                            },
                          ),
                        ],
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
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final closingReadings = <String, PumpReadings>{};
              final attendants = <String, String>{};
              final pumpTesting = <String, PumpTestingModel>{};
              final pumpPayments = <String, PumpPaymentBreakdownModel>{};
              final pumpCollections = <String, double>{};
              for (final pump in station.pumps) {
                closingReadings[pump.id] = PumpReadings(
                  petrol:
                      double.tryParse(petrolControllers[pump.id]?.text ?? '') ??
                      0,
                  diesel:
                      double.tryParse(dieselControllers[pump.id]?.text ?? '') ??
                      0,
                  twoT: pump.id == 'pump2'
                      ? (double.tryParse(
                              twoTControllers[pump.id]?.text ?? '',
                            ) ??
                            0)
                      : 0,
                );
                attendants[pump.id] =
                    attendantControllers[pump.id]?.text.trim() ?? '';
                if (testingValues[pump.id] == true) {
                  final testingPetrol = parseTestingQuantity(
                    testingPetrolControllers[pump.id]?.text ?? '',
                  );
                  final testingDiesel = parseTestingQuantity(
                    testingDieselControllers[pump.id]?.text ?? '',
                  );
                  if (testingPetrol <= 0 && testingDiesel <= 0) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Enter petrol or diesel testing quantity greater than 0 for ${formatPumpLabel(pump.id, pump.label)}.',
                        ),
                      ),
                    );
                    return;
                  }
                  pumpTesting[pump.id] = PumpTestingModel(
                    petrol: testingPetrol,
                    diesel: testingDiesel,
                    addToInventory: testingInventoryValues[pump.id] == true,
                  );
                } else {
                  pumpTesting[pump.id] = const PumpTestingModel(
                    petrol: 0,
                    diesel: 0,
                  );
                }
                final payments = PumpPaymentBreakdownModel(
                  cash:
                      double.tryParse(cashControllers[pump.id]?.text ?? '') ??
                      0,
                  check:
                      double.tryParse(checkControllers[pump.id]?.text ?? '') ??
                      0,
                  upi:
                      double.tryParse(upiControllers[pump.id]?.text ?? '') ?? 0,
                  credit:
                      double.tryParse(creditControllers[pump.id]?.text ?? '') ??
                      0,
                );
                pumpPayments[pump.id] = payments;
                pumpCollections[pump.id] = payments.total;
              }

              result = DailyEntryDraft(
                date: selectedDate,
                closingReadings: closingReadings,
                pumpSalesmen: {
                  for (final pump in station.pumps)
                    pump.id: const PumpSalesmanModel(
                      salesmanId: '',
                      salesmanName: '',
                      salesmanCode: '',
                    ),
                },
                pumpAttendants: attendants,
                pumpTesting: pumpTesting,
                pumpPayments: pumpPayments,
                pumpCollections: pumpCollections,
                paymentBreakdown:
                    initialDraft?.paymentBreakdown ??
                    const PaymentBreakdownModel(cash: 0, check: 0, upi: 0),
                creditEntries: initialDraft?.creditEntries ?? const [],
                creditCollections: initialDraft?.creditCollections ?? const [],
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
  for (final controller in testingPetrolControllers.values) {
    controller.dispose();
  }
  for (final controller in testingDieselControllers.values) {
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
      builder: (dialogContext, setDialogState) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.86,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FF),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF153A8A), Color(0xFF1E5CBA)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Confirm Entry',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Review pump totals, collections, and mismatch before submit.',
                              style: TextStyle(color: Colors.white70),
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
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          formatDateLabel(preview.date),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _PreviewSectionTitle('Pump Summary'),
                        const SizedBox(height: 10),
                        ...preview.soldByPump.entries.map((entry) {
                          final pumpId = entry.key;
                          final payments = preview.pumpPayments[pumpId];
                          final testing = preview.pumpTesting[pumpId];
                          final attendant =
                              preview.pumpAttendants[pumpId]?.trim() ?? '';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        formatPumpLabel(pumpId),
                                        style: const TextStyle(
                                          fontSize: 18,
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
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    _PreviewPill(
                                      label: 'Petrol sold',
                                      value: formatLiters(entry.value.petrol),
                                      accent: const Color(0xFF1E5CBA),
                                    ),
                                    _PreviewPill(
                                      label: 'Diesel sold',
                                      value: formatLiters(entry.value.diesel),
                                      accent: const Color(0xFF006C5C),
                                    ),
                                    if (entry.value.twoT > 0)
                                      _PreviewPill(
                                        label: '2T oil sold',
                                        value: formatLiters(entry.value.twoT),
                                        accent: const Color(0xFFB45309),
                                      ),
                                    _PreviewPill(
                                      label: 'Cash',
                                      value: formatCurrency(
                                        payments?.cash ?? 0,
                                      ),
                                      accent: const Color(0xFFB45309),
                                    ),
                                    _PreviewPill(
                                      label: 'HP Pay',
                                      value: formatCurrency(
                                        payments?.check ?? 0,
                                      ),
                                      accent: const Color(0xFF6B7280),
                                    ),
                                    _PreviewPill(
                                      label: 'UPI',
                                      value: formatCurrency(payments?.upi ?? 0),
                                      accent: const Color(0xFF7C3AED),
                                    ),
                                    _PreviewPill(
                                      label: 'Credit',
                                      value: formatCurrency(
                                        payments?.credit ?? 0,
                                      ),
                                      accent: const Color(0xFFDC2626),
                                    ),
                                  ],
                                ),
                                if (testing?.enabled == true) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF5F3FF),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      'Testing excluded from sales: petrol ${formatLiters(testing?.petrol ?? 0)}  |  diesel ${formatLiters(testing?.diesel ?? 0)}  |  inventory: ${testing?.addToInventory == true ? 'included' : 'excluded'}',
                                      style: const TextStyle(
                                        color: Color(0xFF5B21B6),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                        const _PreviewSectionTitle('Totals'),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _PreviewMetricCard(
                              label: 'Computed sales',
                              value: formatCurrency(preview.computedRevenue),
                              accent: const Color(0xFF1E5CBA),
                            ),
                            _PreviewMetricCard(
                              label: 'Sales settlement',
                              value: formatCurrency(
                                preview.salesSettlementTotal,
                              ),
                              accent: const Color(0xFF0F766E),
                            ),
                            _PreviewMetricCard(
                              label: 'Old credit collected',
                              value: formatCurrency(
                                preview.creditCollectionTotal,
                              ),
                              accent: const Color(0xFF7C3AED),
                            ),
                            _PreviewMetricCard(
                              label: 'Amount collected',
                              value: formatCurrency(preview.paymentTotal),
                              accent: const Color(0xFFB45309),
                            ),
                            _PreviewMetricCard(
                              label: 'Petrol sold',
                              value: formatLiters(preview.totals.sold.petrol),
                              accent: const Color(0xFF1E5CBA),
                            ),
                            _PreviewMetricCard(
                              label: 'Diesel sold',
                              value: formatLiters(preview.totals.sold.diesel),
                              accent: const Color(0xFF006C5C),
                            ),
                            if (preview.totals.sold.twoT > 0)
                              _PreviewMetricCard(
                                label: '2T oil sold',
                                value: formatLiters(preview.totals.sold.twoT),
                                accent: const Color(0xFFB45309),
                              ),
                          ],
                        ),
                        if (preview.priceSnapshot.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          const _PreviewSectionTitle('Applied Rates'),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              if ((preview.priceSnapshot['petrol']?['sellingPrice'] ??
                                      0) >
                                  0)
                                _PreviewRateChip(
                                  label: 'Petrol',
                                  value:
                                      '${formatCurrency(preview.priceSnapshot['petrol']!['sellingPrice']!)}/L',
                                  accent: const Color(0xFF1E5CBA),
                                ),
                              if ((preview.priceSnapshot['diesel']?['sellingPrice'] ??
                                      0) >
                                  0)
                                _PreviewRateChip(
                                  label: 'Diesel',
                                  value:
                                      '${formatCurrency(preview.priceSnapshot['diesel']!['sellingPrice']!)}/L',
                                  accent: const Color(0xFF006C5C),
                                ),
                              if ((preview.priceSnapshot['two_t_oil']?['sellingPrice'] ??
                                      0) >
                                  0)
                                _PreviewRateChip(
                                  label: '2T Oil',
                                  value:
                                      '${formatCurrency(preview.priceSnapshot['two_t_oil']!['sellingPrice']!)}/L',
                                  accent: const Color(0xFFB45309),
                                ),
                            ],
                          ),
                        ],
                        if (preview.mismatchAmount != 0 ||
                            preview.varianceNote.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: const Color(0xFFFCA5A5),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  preview.mismatchAmount == 0
                                      ? 'Variance Note'
                                      : '${preview.mismatchAmount > 0 ? 'Excess' : 'Short'} ${formatCurrency(preview.mismatchAmount.abs())}',
                                  style: const TextStyle(
                                    color: Color(0xFFB91C1C),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                  ),
                                ),
                                if (preview.mismatchAmount != 0) ...[
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: reasonController,
                                    maxLines: 3,
                                    decoration: const InputDecoration(
                                      labelText: 'Mismatch reason',
                                      hintText:
                                          'Required when sales settlement does not match computed revenue',
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
                                    style: const TextStyle(
                                      color: Color(0xFFB91C1C),
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(28),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed:
                              preview.mismatchAmount != 0 &&
                                  reasonController.text.trim().isEmpty
                              ? null
                              : () {
                                  result = reasonController.text.trim();
                                  Navigator.of(dialogContext).pop();
                                },
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Confirm Entry'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  reasonController.dispose();
  return result;
}

class _PreviewSectionTitle extends StatelessWidget {
  const _PreviewSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: Color(0xFF293340),
      ),
    );
  }
}

class _PreviewMetricCard extends StatelessWidget {
  const _PreviewMetricCard({
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
      width: 152,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 10),
          OneLineScaleText(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF55606E)),
          ),
          const SizedBox(height: 6),
          OneLineScaleText(
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

class _PreviewPill extends StatelessWidget {
  const _PreviewPill({
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OneLineScaleText(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const SizedBox(height: 4),
          OneLineScaleText(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF293340),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewRateChip extends StatelessWidget {
  const _PreviewRateChip({
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: OneLineScaleText(
        '$label $value',
        alignment: Alignment.center,
        style: TextStyle(
          color: const Color(0xFF293340),
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _PumpPreviewMetricCard extends StatelessWidget {
  const _PumpPreviewMetricCard({
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
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF55606E),
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 12),
          OneLineScaleText(
            value,
            textAlign: TextAlign.right,
            alignment: Alignment.centerRight,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: accent,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _PumpPreviewDifferenceCard extends StatelessWidget {
  const _PumpPreviewDifferenceCard({
    required this.label,
    required this.value,
    required this.highlight,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final accent = highlight
        ? const Color(0xFFB91C1C)
        : const Color(0xFF0F766E);
    final background = highlight
        ? const Color(0xFFFEF2F2)
        : const Color(0xFFF0FDF4);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF55606E),
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: OneLineScaleText(
              value,
              textAlign: TextAlign.right,
              alignment: Alignment.centerRight,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: accent,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PumpSectionCard extends StatelessWidget {
  const _PumpSectionCard({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF293340),
            ),
          ),
          if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: const TextStyle(color: Color(0xFF55606E), height: 1.35),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _PumpSummaryChip extends StatelessWidget {
  const _PumpSummaryChip({
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
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OneLineScaleText(
            label,
            style: TextStyle(
              color: accent,
              fontSize: 10,
              height: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          OneLineScaleText(
            value,
            style: const TextStyle(
              color: Color(0xFF293340),
              fontSize: 12,
              height: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

Future<MapEntry<String, PumpEntryDraft>?> showPumpEntryDialog({
  required BuildContext context,
  required StationPumpModel pump,
  required PumpReadings opening,
  required Map<String, Map<String, double>> priceSnapshot,
  required double flagThreshold,
  required PumpEntryDraft initialDraft,
  required List<StationSalesmanModel> salesmen,
  List<CreditCustomerSummaryModel> suggestedCustomers = const [],
}) async {
  return showDialog<MapEntry<String, PumpEntryDraft>>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: _PumpEntryDialog(
        pump: pump,
        opening: opening,
        priceSnapshot: priceSnapshot,
        flagThreshold: flagThreshold,
        initialDraft: initialDraft,
        salesmen: salesmen,
        suggestedCustomers: suggestedCustomers,
      ),
    ),
  );
}

Future<MapEntry<String, PumpEntryDraft>?> showPumpCashCollectionDialog({
  required BuildContext context,
  required StationPumpModel pump,
  required PumpEntryDraft initialDraft,
  required List<StationSalesmanModel> salesmen,
}) async {
  return showDialog<MapEntry<String, PumpEntryDraft>>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: _PumpCashCollectionDialog(
        pump: pump,
        initialDraft: initialDraft,
        salesmen: salesmen,
      ),
    ),
  );
}

Future<PaymentEntryDraft?> showPaymentEntryDialog({
  required BuildContext context,
  required PaymentEntryDraft initialDraft,
  required String entryDate,
  List<CreditCustomerSummaryModel> suggestedCustomers = const [],
}) async {
  return Navigator.of(context).push<PaymentEntryDraft>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _PaymentEntryPage(
        initialDraft: initialDraft,
        entryDate: entryDate,
        suggestedCustomers: suggestedCustomers,
      ),
    ),
  );
}

Future<List<CreditEntryModel>?> showCreditEntriesDialog({
  required BuildContext context,
  required List<CreditEntryModel> initialEntries,
  required double expectedTotal,
  List<CreditCustomerSummaryModel> suggestedCustomers = const [],
}) async {
  return showDialog<List<CreditEntryModel>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: _CreditEntriesDialog(
        initialEntries: initialEntries,
        expectedTotal: expectedTotal,
        suggestedCustomers: suggestedCustomers,
      ),
    ),
  );
}

class _CreditEntriesDialog extends StatefulWidget {
  const _CreditEntriesDialog({
    required this.initialEntries,
    required this.expectedTotal,
    required this.suggestedCustomers,
  });

  final List<CreditEntryModel> initialEntries;
  final double expectedTotal;
  final List<CreditCustomerSummaryModel> suggestedCustomers;

  @override
  State<_CreditEntriesDialog> createState() => _CreditEntriesDialogState();
}

class _CreditEntriesDialogState extends State<_CreditEntriesDialog> {
  late List<_CreditEntryControllers> _creditControllers;

  @override
  void initState() {
    super.initState();
    _creditControllers = widget.initialEntries.isEmpty
        ? [_CreditEntryControllers()]
        : widget.initialEntries
              .map(
                (entry) => _CreditEntryControllers(
                  customerId: entry.customerId,
                  name: entry.name,
                  amount: entry.amount == 0
                      ? ''
                      : entry.amount.toStringAsFixed(2),
                ),
              )
              .toList();
  }

  @override
  void dispose() {
    for (final item in _creditControllers) {
      item.dispose();
    }
    super.dispose();
  }

  CreditCustomerSummaryModel? _findCustomerById(String? customerId) {
    final lookup = customerId?.trim() ?? '';
    if (lookup.isEmpty) {
      return null;
    }
    for (final item in widget.suggestedCustomers) {
      if (item.customer.id == lookup) {
        return item;
      }
    }
    return null;
  }

  void _addCreditEntry() {
    setState(() {
      _creditControllers = [..._creditControllers, _CreditEntryControllers()];
    });
  }

  void _removeCreditEntry(int index) {
    final removed = _creditControllers[index];
    removed.dispose();
    setState(() {
      _creditControllers = [
        ..._creditControllers.sublist(0, index),
        ..._creditControllers.sublist(index + 1),
      ];
    });
  }

  double get _namedTotal => _creditControllers.fold<double>(0, (sum, item) {
    return sum + (double.tryParse(item.amountController.text.trim()) ?? 0);
  });

  void _save() {
    final rows = _creditControllers
        .map(
          (item) => CreditEntryModel(
            customerId: item.customerIdController.text.trim(),
            name: item.nameController.text.trim(),
            amount: double.tryParse(item.amountController.text.trim()) ?? 0,
          ),
        )
        .where((item) => item.name.isNotEmpty && item.amount > 0)
        .toList();
    final namedTotal = rows.fold<double>(0, (sum, item) => sum + item.amount);
    if (widget.expectedTotal > 0 &&
        (namedTotal - widget.expectedTotal).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Credit customer total must match ${formatCurrency(widget.expectedTotal)}.',
          ),
        ),
      );
      return;
    }
    if (widget.expectedTotal <= 0 && rows.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pump credit is zero. Remove credit customer rows first.',
          ),
        ),
      );
      return;
    }
    Navigator.of(context).pop(rows);
  }

  @override
  Widget build(BuildContext context) {
    final customerItems = widget.suggestedCustomers
        .map(
          (item) => DropdownMenuItem<String>(
            value: item.customer.id,
            child: Text(item.customer.name),
          ),
        )
        .toList();
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 560,
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
                      const Text(
                        'Credit Customer Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF293340),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Enter customer-wise credit names totaling ${formatCurrency(widget.expectedTotal)}.',
                        style: const TextStyle(color: Color(0xFF55606E)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Close',
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      widget.suggestedCustomers.isEmpty
                          ? 'Type a new customer name for each credit row.'
                          : 'Select an existing customer from the dropdown or type a new customer name.',
                      style: const TextStyle(
                        color: Color(0xFF55606E),
                        height: 1.4,
                      ),
                    ),
                  ),
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
                          ClayDropdownField<String>(
                            label: 'Existing customer',
                            value: item.customerIdController.text.isEmpty
                                ? null
                                : item.customerIdController.text,
                            items: customerItems,
                            onChanged: (value) {
                              setState(() {
                                item.customerIdController.text = value ?? '';
                                final selected = _findCustomerById(value);
                                if (selected != null) {
                                  item.nameController.text =
                                      selected.customer.name;
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: item.nameController,
                            onChanged: (value) {
                              final selected = _findCustomerById(
                                item.customerIdController.text,
                              );
                              if (selected != null &&
                                  value.trim() !=
                                      selected.customer.name.trim()) {
                                item.customerIdController.text = '';
                              }
                            },
                            decoration: InputDecoration(
                              labelText: 'Customer name ${index + 1}',
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: item.amountController,
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
                  TextButton.icon(
                    onPressed: _addCreditEntry,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add customer'),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Named credit total',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF9A3412),
                            ),
                          ),
                        ),
                        Text(
                          formatCurrency(_namedTotal),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF9A3412),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                BusyActionButton(
                  onPressed: _save,
                  builder: (context, busy, handlePressed) => FilledButton(
                    onPressed: busy ? null : handlePressed,
                    child: Text(busy ? 'Saving...' : 'Save Credit Names'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PumpEntryDialog extends StatefulWidget {
  const _PumpEntryDialog({
    required this.pump,
    required this.opening,
    required this.priceSnapshot,
    required this.flagThreshold,
    required this.initialDraft,
    required this.salesmen,
    required this.suggestedCustomers,
  });

  final StationPumpModel pump;
  final PumpReadings opening;
  final Map<String, Map<String, double>> priceSnapshot;
  final double flagThreshold;
  final PumpEntryDraft initialDraft;
  final List<StationSalesmanModel> salesmen;
  final List<CreditCustomerSummaryModel> suggestedCustomers;

  @override
  State<_PumpEntryDialog> createState() => _PumpEntryDialogState();
}

class _PumpEntryDialogState extends State<_PumpEntryDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _petrolController;
  late final TextEditingController _dieselController;
  late final TextEditingController _twoTController;
  late final TextEditingController _cashController;
  late final TextEditingController _checkController;
  late final TextEditingController _upiController;
  late final TextEditingController _testingPetrolController;
  late final TextEditingController _testingDieselController;
  late final TextEditingController _mismatchReasonController;
  late bool _testingEnabled;
  late bool _testingAddsToInventory;
  late List<_CreditEntryControllers> _creditEntryControllers;
  String? _selectedSalesmanId;

  @override
  void initState() {
    super.initState();
    _selectedSalesmanId = _resolveInitialSalesmanId();
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
      text:
          widget.initialDraft.closingReadings == null ||
              widget.initialDraft.closingReadings!.twoT == 0
          ? ''
          : (widget.initialDraft.closingReadings!.twoT - widget.opening.twoT)
                .toStringAsFixed(2),
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
    _testingPetrolController = TextEditingController(
      text: _formatTestingQuantityInput(widget.initialDraft.testing.petrol),
    );
    _testingDieselController = TextEditingController(
      text: _formatTestingQuantityInput(widget.initialDraft.testing.diesel),
    );
    _mismatchReasonController = TextEditingController(
      text: widget.initialDraft.mismatchReason,
    );
    _testingEnabled = widget.initialDraft.testingEnabled;
    _testingAddsToInventory = widget.initialDraft.testing.addToInventory;
    if (widget.initialDraft.creditEntries.isEmpty &&
        widget.initialDraft.payments.credit > 0) {
      _creditEntryControllers = [
        _CreditEntryControllers(
          customerMode: widget.suggestedCustomers.isNotEmpty
              ? _creditCustomerModeExisting
              : _creditCustomerModeNew,
          amount: widget.initialDraft.payments.credit.toStringAsFixed(2),
        ),
      ];
    } else {
      _creditEntryControllers = widget.initialDraft.creditEntries
          .map(
            (entry) => _CreditEntryControllers(
              customerMode: entry.customerId.trim().isNotEmpty
                  ? _creditCustomerModeExisting
                  : _creditCustomerModeNew,
              customerId: entry.customerId,
              name: entry.name,
              amount: entry.amount == 0 ? '' : entry.amount.toStringAsFixed(2),
            ),
          )
          .toList();
    }
    _petrolController.addListener(_refreshTotals);
    _dieselController.addListener(_refreshTotals);
    _twoTController.addListener(_refreshTotals);
    _cashController.addListener(_refreshTotals);
    _checkController.addListener(_refreshTotals);
    _upiController.addListener(_refreshTotals);
    _testingPetrolController.addListener(_refreshTotals);
    _testingDieselController.addListener(_refreshTotals);
    for (final item in _creditEntryControllers) {
      item.amountController.addListener(_refreshTotals);
    }
  }

  @override
  void dispose() {
    _petrolController.removeListener(_refreshTotals);
    _dieselController.removeListener(_refreshTotals);
    _twoTController.removeListener(_refreshTotals);
    _cashController.removeListener(_refreshTotals);
    _checkController.removeListener(_refreshTotals);
    _upiController.removeListener(_refreshTotals);
    _petrolController.dispose();
    _dieselController.dispose();
    _twoTController.dispose();
    _cashController.dispose();
    _checkController.dispose();
    _upiController.dispose();
    _mismatchReasonController.dispose();
    _testingPetrolController.removeListener(_refreshTotals);
    _testingDieselController.removeListener(_refreshTotals);
    for (final item in _creditEntryControllers) {
      item.amountController.removeListener(_refreshTotals);
      item.dispose();
    }
    _testingPetrolController.dispose();
    _testingDieselController.dispose();
    super.dispose();
  }

  String? _resolveInitialSalesmanId() {
    final draftSalesman = widget.initialDraft.salesman;
    if (draftSalesman.salesmanId.trim().isNotEmpty) {
      return draftSalesman.salesmanId.trim();
    }
    final draftCode = draftSalesman.salesmanCode.trim().toUpperCase();
    if (draftCode.isEmpty) {
      return null;
    }
    for (final salesman in widget.salesmen) {
      if (salesman.code.trim().toUpperCase() == draftCode) {
        return salesman.id;
      }
    }
    return null;
  }

  StationSalesmanModel? get _selectedSalesman {
    final lookup = _selectedSalesmanId?.trim() ?? '';
    if (lookup.isEmpty) {
      return null;
    }
    for (final salesman in widget.salesmen) {
      if (salesman.id == lookup) {
        return salesman;
      }
    }
    return null;
  }

  List<StationSalesmanModel> get _availableSalesmen {
    final selected = _selectedSalesman;
    final includedIds = <String>{};
    final available = <StationSalesmanModel>[];
    for (final salesman in widget.salesmen) {
      final shouldInclude =
          salesman.active || (selected != null && salesman.id == selected.id);
      if (!shouldInclude || includedIds.contains(salesman.id)) {
        continue;
      }
      includedIds.add(salesman.id);
      available.add(salesman);
    }
    available.sort(
      (left, right) => left.displayLabel.compareTo(right.displayLabel),
    );
    return available;
  }

  bool get _requiresSalesmanSelection {
    final petrolClosing = _parseClosingReadingForPreview(
      _petrolController.text,
      openingValue: widget.opening.petrol,
    );
    final dieselClosing = _parseClosingReadingForPreview(
      _dieselController.text,
      openingValue: widget.opening.diesel,
    );
    final hasMeterMovement =
        (petrolClosing - widget.opening.petrol).abs() >
            _readingComparisonTolerance ||
        (dieselClosing - widget.opening.diesel).abs() >
            _readingComparisonTolerance;
    final hasTwoTSales = _parseDirectSaleAmount(_twoTController.text) > 0;
    final hasCollections = _collectionTotal > 0;
    return hasMeterMovement ||
        hasTwoTSales ||
        hasCollections ||
        _testingEnabled;
  }

  String? _validateSalesmanSelection() {
    if (!_requiresSalesmanSelection) {
      return null;
    }
    if (_availableSalesmen.isEmpty) {
      return 'Add a salesman in settings first.';
    }
    if (_selectedSalesman == null) {
      return 'Select a salesman.';
    }
    return null;
  }

  bool get _supportsTwoT => true;

  void _refreshTotals() {
    if (mounted) {
      setState(() {});
    }
  }

  double _parseAmount(String raw) {
    return double.tryParse(raw.trim()) ?? 0;
  }

  double _parseClosingReadingForPreview(
    String raw, {
    required double openingValue,
  }) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return openingValue;
    }
    return double.tryParse(trimmed) ?? openingValue;
  }

  double _parseDirectSaleAmount(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return 0;
    }
    return double.tryParse(trimmed) ?? 0;
  }

  double _twoTClosingFromDirectSales() {
    return widget.opening.twoT + _parseDirectSaleAmount(_twoTController.text);
  }

  double _parseTestingQuantity(String raw) {
    return parseTestingQuantity(raw);
  }

  String? _validateRequiredReading(
    String label,
    String raw, {
    required double openingValue,
  }) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return '$label is required.';
    }
    final parsed = double.tryParse(trimmed);
    if (parsed == null) {
      return 'Enter a valid number for $label.';
    }
    if (parsed < 0) {
      return '$label cannot be negative.';
    }
    if (openingValue - parsed > _readingComparisonTolerance) {
      return 'Must be >= opening ${formatLiters(openingValue)}.';
    }
    return null;
  }

  String? _validateAmount(String label, String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final parsed = double.tryParse(trimmed);
    if (parsed == null) {
      return 'Enter a valid amount for $label.';
    }
    if (parsed < 0) {
      return '$label cannot be negative.';
    }
    return null;
  }

  String? _validateDirectSale(String label, String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final parsed = double.tryParse(trimmed);
    if (parsed == null) {
      return 'Enter a valid number for $label.';
    }
    if (parsed < 0) {
      return '$label cannot be negative.';
    }
    return null;
  }

  String? _validateTestingQuantity(String label, String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final parsed = double.tryParse(trimmed);
    if (parsed == null) {
      return 'Enter a valid $label quantity.';
    }
    if (parsed < 0) {
      return '$label quantity cannot be negative.';
    }
    return null;
  }

  String? _validateTestingSelection() {
    if (!_testingEnabled) {
      return null;
    }
    final petrol = _parseTestingQuantity(_testingPetrolController.text);
    final diesel = _parseTestingQuantity(_testingDieselController.text);
    if (petrol <= 0 && diesel <= 0) {
      return 'Enter petrol or diesel testing quantity greater than 0.';
    }
    return null;
  }

  double get _collectionTotal =>
      _parseAmount(_cashController.text) +
      _parseAmount(_checkController.text) +
      _parseAmount(_upiController.text) +
      _namedCreditTotal;

  double get _namedCreditTotal =>
      _creditEntryControllers.fold<double>(0, (sum, item) {
        return sum + (double.tryParse(item.amountController.text.trim()) ?? 0);
      });

  PumpReadings get _soldLiters {
    final petrolClosing = _parseClosingReadingForPreview(
      _petrolController.text,
      openingValue: widget.opening.petrol,
    );
    final dieselClosing = _parseClosingReadingForPreview(
      _dieselController.text,
      openingValue: widget.opening.diesel,
    );
    final twoTClosing = _supportsTwoT ? _twoTClosingFromDirectSales() : 0;
    final petrolRaw = petrolClosing - widget.opening.petrol;
    final dieselRaw = dieselClosing - widget.opening.diesel;
    final twoTRaw = twoTClosing - widget.opening.twoT;
    final testingPetrol = _testingEnabled
        ? _parseTestingQuantity(_testingPetrolController.text)
        : 0;
    final testingDiesel = _testingEnabled
        ? _parseTestingQuantity(_testingDieselController.text)
        : 0;
    final petrolSold = petrolRaw > 0
        ? (petrolRaw - testingPetrol).clamp(0, petrolRaw)
        : petrolRaw;
    final dieselSold = dieselRaw > 0
        ? (dieselRaw - testingDiesel).clamp(0, dieselRaw)
        : dieselRaw;
    return PumpReadings(
      petrol: petrolSold.toDouble(),
      diesel: dieselSold.toDouble(),
      twoT: twoTRaw,
    );
  }

  double _sellingPriceFor(String fuelKey) {
    return widget.priceSnapshot[fuelKey]?['sellingPrice'] ?? 0;
  }

  String _sellingPriceLabel(String fuelKey) {
    final price = _sellingPriceFor(fuelKey);
    if (price <= 0) {
      return 'Not set';
    }
    return '${formatCurrency(price)}/L';
  }

  double get _actualSalesValue {
    final sold = _soldLiters;
    return double.parse(
      (sold.petrol * _sellingPriceFor('petrol') +
              sold.diesel * _sellingPriceFor('diesel') +
              sold.twoT * _sellingPriceFor('two_t_oil'))
          .toStringAsFixed(2),
    );
  }

  double get _pumpDifference =>
      double.parse((_collectionTotal - _actualSalesValue).toStringAsFixed(2));

  bool get _hasRequiredSellingPrices => hasRequiredSellingPrices(
    widget.priceSnapshot,
    <String>['petrol', 'diesel', if (_supportsTwoT) 'two_t_oil'],
  );

  bool get _requiresMismatchReason =>
      _hasRequiredSellingPrices &&
      _pumpDifference.abs() >= widget.flagThreshold;

  CreditCustomerSummaryModel? _findCustomerById(String? customerId) {
    final lookup = customerId?.trim() ?? '';
    if (lookup.isEmpty) {
      return null;
    }
    for (final item in widget.suggestedCustomers) {
      if (item.customer.id == lookup) {
        return item;
      }
    }
    return null;
  }

  void _addCreditEntryRow() {
    final controller = _CreditEntryControllers(
      customerMode: widget.suggestedCustomers.isNotEmpty
          ? _creditCustomerModeExisting
          : _creditCustomerModeNew,
    );
    controller.amountController.addListener(_refreshTotals);
    setState(() {
      _creditEntryControllers = [..._creditEntryControllers, controller];
    });
  }

  void _removeCreditEntryRow(int index) {
    final removed = _creditEntryControllers[index];
    removed.amountController.removeListener(_refreshTotals);
    removed.dispose();
    setState(() {
      _creditEntryControllers = [
        ..._creditEntryControllers.sublist(0, index),
        ..._creditEntryControllers.sublist(index + 1),
      ];
    });
  }

  List<CreditEntryModel> _buildCreditEntries() {
    return _creditEntryControllers
        .map(
          (item) => CreditEntryModel(
            pumpId: widget.pump.id,
            customerId: item.customerIdController.text.trim(),
            name: item.nameController.text.trim(),
            amount: double.tryParse(item.amountController.text.trim()) ?? 0,
          ),
        )
        .where(
          (item) =>
              item.amount > 0 &&
              (item.customerId.trim().isNotEmpty ||
                  item.name.trim().isNotEmpty),
        )
        .toList();
  }

  String? _validateCreditCustomerRow(_CreditEntryControllers item) {
    if (item.customerMode == _creditCustomerModeExisting) {
      if (item.customerIdController.text.trim().isEmpty) {
        return 'Select an existing customer.';
      }
      return null;
    }
    if (item.nameController.text.trim().isEmpty) {
      return 'Enter a new customer name.';
    }
    return null;
  }

  String? _validateCreditAmountRow(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return 'Enter credit amount.';
    }
    final parsed = double.tryParse(trimmed);
    if (parsed == null) {
      return 'Enter a valid credit amount.';
    }
    if (parsed <= 0) {
      return 'Credit amount must be greater than zero.';
    }
    return null;
  }

  void _markPumpAsNil() {
    setState(() {
      _selectedSalesmanId = null;
      _petrolController.text = widget.opening.petrol.toStringAsFixed(2);
      _dieselController.text = widget.opening.diesel.toStringAsFixed(2);
      if (_supportsTwoT) {
        _twoTController.clear();
      }
      _cashController.clear();
      _checkController.clear();
      _upiController.clear();
      for (final item in _creditEntryControllers) {
        item.amountController.removeListener(_refreshTotals);
        item.dispose();
      }
      _creditEntryControllers = [];
      _testingEnabled = false;
      _testingAddsToInventory = false;
      _testingPetrolController.clear();
      _testingDieselController.clear();
      _mismatchReasonController.clear();
    });
  }

  void _savePump() {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }
    final testingError = _validateTestingSelection();
    if (testingError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(testingError)));
      return;
    }
    final salesmanError = _validateSalesmanSelection();
    if (salesmanError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(salesmanError)));
      return;
    }

    final namedCreditEntries = _buildCreditEntries();
    final creditAmount = namedCreditEntries.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );
    final mismatchReason = _mismatchReasonController.text.trim();
    if (_requiresMismatchReason && mismatchReason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Difference exceeds threshold ${formatCurrency(widget.flagThreshold)}. Enter a reason for this pump.',
          ),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      MapEntry(
        widget.pump.id,
        PumpEntryDraft(
          salesman: _selectedSalesman == null
              ? const PumpSalesmanModel(
                  salesmanId: '',
                  salesmanName: '',
                  salesmanCode: '',
                )
              : PumpSalesmanModel(
                  salesmanId: _selectedSalesman!.id,
                  salesmanName: _selectedSalesman!.name,
                  salesmanCode: _selectedSalesman!.code,
                ),
          attendant: _selectedSalesman?.displayLabel ?? '',
          closingReadings: PumpReadings(
            petrol: _parseAmount(_petrolController.text),
            diesel: _parseAmount(_dieselController.text),
            twoT: _supportsTwoT ? _twoTClosingFromDirectSales() : 0,
          ),
          testing: _testingEnabled
              ? PumpTestingModel(
                  petrol: _parseTestingQuantity(_testingPetrolController.text),
                  diesel: _parseTestingQuantity(_testingDieselController.text),
                  addToInventory: _testingAddsToInventory,
                )
              : const PumpTestingModel(
                  petrol: 0,
                  diesel: 0,
                  addToInventory: false,
                ),
          payments: PumpPaymentBreakdownModel(
            cash: _parseAmount(_cashController.text),
            check: _parseAmount(_checkController.text),
            upi: _parseAmount(_upiController.text),
            credit: creditAmount,
          ),
          creditEntries: namedCreditEntries,
          mismatchReason: mismatchReason,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 560,
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Update ${formatPumpLabel(widget.pump.id, widget.pump.label)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF293340),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Enter petrol and diesel closing readings, then record 2T as direct sales.',
                            style: TextStyle(color: Color(0xFF55606E)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Close',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    onPressed: _markPumpAsNil,
                    icon: const Icon(
                      Icons.do_not_disturb_alt_rounded,
                      size: 18,
                    ),
                    label: const Text('Mark Nil'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      foregroundColor: const Color(0xFF1E3A8A),
                      backgroundColor: const Color(0xFFE0E7FF),
                    ),
                  ),
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
                autovalidateMode: AutovalidateMode.disabled,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PumpSectionCard(
                      title: 'Fuel prices',
                      subtitle:
                          'Current selling prices used for this pump entry.',
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          const gap = 10.0;
                          final itemWidth = (constraints.maxWidth - gap) / 2;
                          return Wrap(
                            spacing: gap,
                            runSpacing: gap,
                            children: [
                              SizedBox(
                                width: itemWidth,
                                child: _PumpSummaryChip(
                                  label: 'Petrol',
                                  value: _sellingPriceLabel('petrol'),
                                  accent: const Color(0xFF1E5CBA),
                                ),
                              ),
                              SizedBox(
                                width: itemWidth,
                                child: _PumpSummaryChip(
                                  label: 'Diesel',
                                  value: _sellingPriceLabel('diesel'),
                                  accent: const Color(0xFF0F766E),
                                ),
                              ),
                              if (_supportsTwoT)
                                SizedBox(
                                  width: itemWidth,
                                  child: _PumpSummaryChip(
                                    label: '2T Oil',
                                    value: _sellingPriceLabel('two_t_oil'),
                                    accent: const Color(0xFF7C3AED),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    _PumpSectionCard(
                      title: 'Meter readings and 2T sales',
                      subtitle:
                          'Enter final petrol and diesel closing readings. For 2T oil, enter direct liters sold.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClayDropdownField<String>(
                            label: 'Salesman',
                            icon: Icons.person_outline_rounded,
                            value: _selectedSalesmanId,
                            helperText:
                                _selectedSalesman == null &&
                                    widget.initialDraft.attendant
                                        .trim()
                                        .isNotEmpty
                                ? 'Legacy value: ${widget.initialDraft.attendant}'
                                : 'Select from the salesman list in settings.',
                            items: _availableSalesmen
                                .map(
                                  (salesman) => DropdownMenuItem<String>(
                                    value: salesman.id,
                                    child: Text(salesman.displayLabel),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedSalesmanId = value;
                              });
                            },
                            validator: (_) => _validateSalesmanSelection(),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _petrolController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Petrol closing meter reading',
                              helperText:
                                  'Opening ${formatLiters(widget.opening.petrol)}',
                              helperMaxLines: 1,
                              errorMaxLines: 1,
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            validator: (value) => _validateRequiredReading(
                              'Petrol closing meter reading',
                              value ?? '',
                              openingValue: widget.opening.petrol,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _dieselController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Diesel closing meter reading',
                              helperText:
                                  'Opening ${formatLiters(widget.opening.diesel)}',
                              helperMaxLines: 1,
                              errorMaxLines: 1,
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            validator: (value) => _validateRequiredReading(
                              'Diesel closing meter reading',
                              value ?? '',
                              openingValue: widget.opening.diesel,
                            ),
                          ),
                          if (_supportsTwoT) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _twoTController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: '2T oil sold',
                                helperText:
                                    'Direct sale entry. No meter reading required.',
                                helperMaxLines: 1,
                                errorMaxLines: 1,
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              validator: (value) => _validateDirectSale(
                                '2T oil sold',
                                value ?? '',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _PumpSectionCard(
                      title: 'Collections',
                      subtitle:
                          'Record the payment amounts collected on this pump. Credit issued is entered separately below.',
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 420;
                          final fields = [
                            TextFormField(
                              controller: _cashController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Cash',
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              validator: (value) =>
                                  _validateAmount('Cash', value ?? ''),
                            ),
                            TextFormField(
                              controller: _checkController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'HP Pay',
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              validator: (value) =>
                                  _validateAmount('HP Pay', value ?? ''),
                            ),
                            TextFormField(
                              controller: _upiController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'UPI',
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              validator: (value) =>
                                  _validateAmount('UPI', value ?? ''),
                            ),
                          ];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isWide) ...[
                                Row(
                                  children: [
                                    Expanded(child: fields[0]),
                                    const SizedBox(width: 12),
                                    Expanded(child: fields[1]),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                fields[2],
                              ] else ...[
                                fields[0],
                                const SizedBox(height: 12),
                                fields[1],
                                const SizedBox(height: 12),
                                fields[2],
                              ],
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Collection total',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF293340),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      formatCurrency(_collectionTotal),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F766E),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
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
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Pump Credit',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF293340),
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _addCreditEntryRow,
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Add Credit'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Add one row per credit customer. Pump credit total is calculated from these rows and sent to Credit Ledger after approval.',
                            style: TextStyle(
                              color: Color(0xFF55606E),
                              height: 1.4,
                            ),
                          ),
                          if (_creditEntryControllers.isEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Text(
                                'No credit rows added for this pump.',
                                style: TextStyle(color: Color(0xFF55606E)),
                              ),
                            ),
                          ],
                          if (_creditEntryControllers.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            ...List.generate(_creditEntryControllers.length, (
                              index,
                            ) {
                              final item = _creditEntryControllers[index];
                              final customerItems = widget.suggestedCustomers
                                  .map(
                                    (customer) => DropdownMenuItem<String>(
                                      value: customer.customer.id,
                                      child: Text(customer.customer.name),
                                    ),
                                  )
                                  .toList();
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Credit ${index + 1}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF293340),
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              _removeCreditEntryRow(index),
                                          child: const Text('Remove'),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ClayDropdownField<String>(
                                      label: 'Customer type',
                                      icon: Icons.group_outlined,
                                      value: item.customerMode,
                                      items: const [
                                        DropdownMenuItem<String>(
                                          value: _creditCustomerModeExisting,
                                          child: Text('Existing'),
                                        ),
                                        DropdownMenuItem<String>(
                                          value: _creditCustomerModeNew,
                                          child: Text('New'),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        if (value == null) {
                                          return;
                                        }
                                        setState(() {
                                          item.customerMode = value;
                                          item.customerIdController.text = '';
                                          item.nameController.text = '';
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 10),
                                    if (item.customerMode ==
                                        _creditCustomerModeExisting) ...[
                                      ClayDropdownField<String>(
                                        label: widget.suggestedCustomers.isEmpty
                                            ? 'Existing customer (none available yet)'
                                            : 'Existing customer',
                                        icon: Icons.person_search_rounded,
                                        value:
                                            item
                                                .customerIdController
                                                .text
                                                .isEmpty
                                            ? null
                                            : item.customerIdController.text,
                                        items: customerItems,
                                        enabled: widget
                                            .suggestedCustomers
                                            .isNotEmpty,
                                        onChanged: (value) {
                                          setState(() {
                                            item.customerIdController.text =
                                                value ?? '';
                                            final selected = _findCustomerById(
                                              value,
                                            );
                                            item.nameController.text =
                                                selected?.customer.name ?? '';
                                          });
                                        },
                                        validator: (_) =>
                                            _validateCreditCustomerRow(item),
                                      ),
                                    ] else ...[
                                      TextFormField(
                                        controller: item.nameController,
                                        textInputAction: TextInputAction.next,
                                        decoration: InputDecoration(
                                          labelText:
                                              'Customer name ${index + 1}',
                                          filled: true,
                                          fillColor: Colors.white,
                                        ),
                                        validator: (_) =>
                                            _validateCreditCustomerRow(item),
                                      ),
                                    ],
                                    const SizedBox(height: 10),
                                    TextFormField(
                                      controller: item.amountController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: const InputDecoration(
                                        labelText: 'Credit amount',
                                        filled: true,
                                        fillColor: Colors.white,
                                      ),
                                      validator: (value) =>
                                          _validateCreditAmountRow(value ?? ''),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Pump credit total',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF9A3412),
                                    ),
                                  ),
                                ),
                                Text(
                                  formatCurrency(_namedCreditTotal),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF9A3412),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _PumpSectionCard(
                      title: 'Pump preview',
                      subtitle:
                          'Calculated locally from the readings and payment values entered in this pump.',
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 420;
                          final metrics = [
                            _PumpPreviewMetricCard(
                              label: 'Actual sales',
                              value: _hasRequiredSellingPrices
                                  ? formatCurrency(_actualSalesValue)
                                  : 'Unavailable',
                              accent: const Color(0xFF1E5CBA),
                            ),
                            _PumpPreviewMetricCard(
                              label: 'Collection',
                              value: formatCurrency(_collectionTotal),
                              accent: const Color(0xFF0F766E),
                            ),
                          ];
                          return Column(
                            children: [
                              if (isWide)
                                Row(
                                  children: [
                                    Expanded(child: metrics[0]),
                                    const SizedBox(width: 10),
                                    Expanded(child: metrics[1]),
                                  ],
                                )
                              else ...[
                                metrics[0],
                                const SizedBox(height: 10),
                                metrics[1],
                              ],
                              const SizedBox(height: 10),
                              _PumpPreviewDifferenceCard(
                                label:
                                    _hasRequiredSellingPrices &&
                                        widget.flagThreshold > 0
                                    ? 'Difference vs threshold ${formatCurrency(widget.flagThreshold)}'
                                    : 'Difference',
                                value: !_hasRequiredSellingPrices
                                    ? 'Fuel prices unavailable'
                                    : _pumpDifference == 0
                                    ? formatCurrency(0)
                                    : '${_pumpDifference > 0 ? 'Excess' : 'Short'} ${formatCurrency(_pumpDifference.abs())}',
                                highlight:
                                    _hasRequiredSellingPrices &&
                                    _requiresMismatchReason,
                              ),
                              if (!_hasRequiredSellingPrices) ...[
                                const SizedBox(height: 10),
                                const Text(
                                  'Fuel prices are still loading or not configured for this station. Actual sales and the difference will refresh after prices are available.',
                                  style: TextStyle(
                                    color: Color(0xFF9A3412),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                              if (_requiresMismatchReason) ...[
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _mismatchReasonController,
                                  minLines: 2,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    labelText: 'Difference reason',
                                    helperText:
                                        'Required when the pump difference exceeds the threshold.',
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  validator: (_) =>
                                      _requiresMismatchReason &&
                                          _mismatchReasonController.text
                                              .trim()
                                              .isEmpty
                                      ? 'Enter a reason for the difference.'
                                      : null,
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    _PumpSectionCard(
                      title: 'Testing',
                      subtitle:
                          'Exclude a small test dispense from the sale total when the pump was checked.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CheckboxListTile(
                            value: _testingEnabled,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: const Text('Enable testing deduction'),
                            subtitle: Text(
                              _testingSubtitle(
                                _testingEnabled
                                    ? PumpTestingModel(
                                        petrol: _parseTestingQuantity(
                                          _testingPetrolController.text,
                                        ),
                                        diesel: _parseTestingQuantity(
                                          _testingDieselController.text,
                                        ),
                                        addToInventory: _testingAddsToInventory,
                                      )
                                    : const PumpTestingModel(
                                        petrol: _defaultTestingQuantity,
                                        diesel: _defaultTestingQuantity,
                                      ),
                              ),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _testingEnabled = value ?? false;
                                if (_testingEnabled) {
                                  if (_parseTestingQuantity(
                                        _testingPetrolController.text,
                                      ) <=
                                      0) {
                                    _testingPetrolController.text =
                                        _formatTestingQuantityInput(
                                          _defaultTestingQuantity,
                                        );
                                  }
                                  if (_parseTestingQuantity(
                                        _testingDieselController.text,
                                      ) <=
                                      0) {
                                    _testingDieselController.text =
                                        _formatTestingQuantityInput(
                                          _defaultTestingQuantity,
                                        );
                                  }
                                } else {
                                  _testingAddsToInventory = false;
                                }
                              });
                            },
                          ),
                          if (_testingEnabled) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _testingPetrolController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Testing petrol quantity',
                                helperText:
                                    'This value is excluded only from petrol sales.',
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              validator: (value) => _validateTestingQuantity(
                                'petrol',
                                value ?? '',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _testingDieselController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Testing diesel quantity',
                                helperText:
                                    'This value is excluded only from diesel sales.',
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              validator: (value) => _validateTestingQuantity(
                                'diesel',
                                value ?? '',
                              ),
                            ),
                            const SizedBox(height: 12),
                            CheckboxListTile(
                              value: _testingAddsToInventory,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: const Text(
                                'Reduce testing from inventory',
                              ),
                              subtitle: const Text(
                                'If selected, inventory will reduce by the testing quantity too.',
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _testingAddsToInventory = value ?? false;
                                });
                              },
                            ),
                          ],
                        ],
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
                  child: BusyActionButton(
                    onPressed: _savePump,
                    builder: (context, busy, handlePressed) => FilledButton(
                      onPressed: busy ? null : handlePressed,
                      child: Text(busy ? 'Updating...' : 'Update Pump'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentEntryPage extends StatefulWidget {
  const _PaymentEntryPage({
    required this.initialDraft,
    required this.entryDate,
    required this.suggestedCustomers,
  });

  final PaymentEntryDraft initialDraft;
  final String entryDate;
  final List<CreditCustomerSummaryModel> suggestedCustomers;

  @override
  State<_PaymentEntryPage> createState() => _PaymentEntryPageState();
}

class _PaymentEntryPageState extends State<_PaymentEntryPage> {
  late final TextEditingController _cashController;
  late final TextEditingController _checkController;
  late final TextEditingController _upiController;
  late List<_CreditEntryControllers> _creditControllers;
  late List<_CreditCollectionControllers> _collectionControllers;

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
        ? <_CreditEntryControllers>[]
        : widget.initialDraft.creditEntries
              .map(
                (entry) => _CreditEntryControllers(
                  customerId: entry.customerId,
                  name: entry.name,
                  amount: entry.amount == 0
                      ? ''
                      : entry.amount.toStringAsFixed(2),
                ),
              )
              .toList();
    _collectionControllers = widget.initialDraft.creditCollections.isEmpty
        ? <_CreditCollectionControllers>[]
        : widget.initialDraft.creditCollections
              .map(
                (entry) => _CreditCollectionControllers(
                  customerId: entry.customerId,
                  name: entry.name,
                  amount: entry.amount == 0
                      ? ''
                      : entry.amount.toStringAsFixed(2),
                  date: entry.date.isEmpty ? widget.entryDate : entry.date,
                  paymentMode: entry.paymentMode,
                  note: entry.note,
                ),
              )
              .toList();
  }

  @override
  void dispose() {
    _cashController.dispose();
    _checkController.dispose();
    _upiController.dispose();
    for (final item in _creditControllers) {
      item.dispose();
    }
    for (final item in _collectionControllers) {
      item.dispose();
    }
    super.dispose();
  }

  void _addCreditEntry() {
    setState(() {
      _creditControllers = [..._creditControllers, _CreditEntryControllers()];
    });
  }

  void _removeCreditEntry(int index) {
    final removed = _creditControllers[index];
    removed.dispose();
    setState(() {
      _creditControllers = [
        ..._creditControllers.sublist(0, index),
        ..._creditControllers.sublist(index + 1),
      ];
    });
  }

  void _addCollectionEntry() {
    setState(() {
      _collectionControllers = [
        ..._collectionControllers,
        _CreditCollectionControllers(date: widget.entryDate),
      ];
    });
  }

  void _removeCollectionEntry(int index) {
    final removed = _collectionControllers[index];
    removed.dispose();
    setState(() {
      _collectionControllers = [
        ..._collectionControllers.sublist(0, index),
        ..._collectionControllers.sublist(index + 1),
      ];
    });
  }

  CreditCustomerSummaryModel? _findCustomerById(String? customerId) {
    final lookup = customerId?.trim() ?? '';
    if (lookup.isEmpty) {
      return null;
    }
    for (final item in widget.suggestedCustomers) {
      if (item.customer.id == lookup) {
        return item;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final customerItems = widget.suggestedCustomers
        .map(
          (item) => DropdownMenuItem<String>(
            value: item.customer.id,
            child: Text(item.customer.name),
          ),
        )
        .toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Payments & Credit'),
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
              controller: _checkController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'HP Pay',
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _upiController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'UPI',
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Collections recorded here count toward today\'s amount collected, but they stay separate from fuel sales mismatch.',
                style: TextStyle(color: Color(0xFF55606E), height: 1.4),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'New Credit Issued',
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
            if (_creditControllers.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Add a customer credit row when fuel is given on credit.',
                  style: TextStyle(color: Color(0xFF55606E)),
                ),
              ),
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
                    ClayDropdownField<String>(
                      label: 'Existing customer',
                      icon: Icons.person_search_rounded,
                      value: item.customerIdController.text.isEmpty
                          ? null
                          : item.customerIdController.text,
                      items: customerItems,
                      onChanged: (value) {
                        setState(() {
                          item.customerIdController.text = value ?? '';
                          final selected = _findCustomerById(value);
                          if (selected != null) {
                            item.nameController.text = selected.customer.name;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: item.nameController,
                      decoration: InputDecoration(
                        labelText: 'Customer name ${index + 1}',
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: item.amountController,
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
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Credit Collections',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF293340),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _addCollectionEntry,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_collectionControllers.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Record old credit collections here with date, amount, payment mode, and optional note.',
                  style: TextStyle(color: Color(0xFF55606E)),
                ),
              ),
            ...List.generate(_collectionControllers.length, (index) {
              final item = _collectionControllers[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    ClayDropdownField<String>(
                      label: 'Existing customer',
                      icon: Icons.person_search_rounded,
                      value: item.customerIdController.text.isEmpty
                          ? null
                          : item.customerIdController.text,
                      items: customerItems,
                      onChanged: (value) {
                        setState(() {
                          item.customerIdController.text = value ?? '';
                          final selected = _findCustomerById(value);
                          if (selected != null) {
                            item.nameController.text = selected.customer.name;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: item.nameController,
                      decoration: const InputDecoration(
                        labelText: 'Customer name',
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: item.amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Collected amount',
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: item.dateController,
                      decoration: const InputDecoration(
                        labelText: 'Collection date (YYYY-MM-DD)',
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClayDropdownField<String>(
                      label: 'Payment mode',
                      icon: Icons.payments_outlined,
                      value: item.paymentModeController.text.isEmpty
                          ? null
                          : item.paymentModeController.text,
                      items: const [
                        DropdownMenuItem(value: 'cash', child: Text('Cash')),
                        DropdownMenuItem(value: 'check', child: Text('HP Pay')),
                        DropdownMenuItem(value: 'upi', child: Text('UPI')),
                      ],
                      onChanged: (value) => setState(
                        () => item.paymentModeController.text = value ?? '',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: item.noteController,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    if (_collectionControllers.length > 1)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => _removeCollectionEntry(index),
                          child: const Text('Remove'),
                        ),
                      ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 20),
            BusyActionButton(
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
                            customerId: item.customerIdController.text.trim(),
                            name: item.nameController.text.trim(),
                            amount:
                                double.tryParse(item.amountController.text) ??
                                0,
                          ),
                        )
                        .where(
                          (item) => item.name.isNotEmpty && item.amount > 0,
                        )
                        .toList(),
                    creditCollections: _collectionControllers
                        .map(
                          (item) => CreditCollectionModel(
                            customerId: item.customerIdController.text.trim(),
                            name: item.nameController.text.trim(),
                            amount:
                                double.tryParse(item.amountController.text) ??
                                0,
                            date: item.dateController.text.trim(),
                            paymentMode: item.paymentModeController.text.trim(),
                            note: item.noteController.text.trim(),
                          ),
                        )
                        .where(
                          (item) =>
                              item.name.isNotEmpty &&
                              item.amount > 0 &&
                              item.date.isNotEmpty &&
                              item.paymentMode.isNotEmpty,
                        )
                        .toList(),
                  ),
                );
              },
              builder: (context, busy, handlePressed) => FilledButton(
                onPressed: busy ? null : handlePressed,
                child: Text(busy ? 'Updating...' : 'Update Payments & Credit'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PumpCashCollectionDialog extends StatefulWidget {
  const _PumpCashCollectionDialog({
    required this.pump,
    required this.initialDraft,
    required this.salesmen,
  });

  final StationPumpModel pump;
  final PumpEntryDraft initialDraft;
  final List<StationSalesmanModel> salesmen;

  @override
  State<_PumpCashCollectionDialog> createState() =>
      _PumpCashCollectionDialogState();
}

class _PumpCashCollectionDialogState extends State<_PumpCashCollectionDialog> {
  late final TextEditingController _cashController;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _selectedSalesmanId;

  @override
  void initState() {
    super.initState();
    _selectedSalesmanId = _resolveInitialSalesmanId();
    _cashController = TextEditingController(
      text: widget.initialDraft.payments.cash == 0
          ? ''
          : widget.initialDraft.payments.cash.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  String? _resolveInitialSalesmanId() {
    final draftSalesman = widget.initialDraft.salesman;
    if (draftSalesman.salesmanId.trim().isNotEmpty) {
      return draftSalesman.salesmanId.trim();
    }
    final draftCode = draftSalesman.salesmanCode.trim().toUpperCase();
    if (draftCode.isEmpty) {
      return null;
    }
    for (final salesman in widget.salesmen) {
      if (salesman.code.trim().toUpperCase() == draftCode) {
        return salesman.id;
      }
    }
    return null;
  }

  StationSalesmanModel? get _selectedSalesman {
    final lookup = _selectedSalesmanId?.trim() ?? '';
    if (lookup.isEmpty) {
      return null;
    }
    for (final salesman in widget.salesmen) {
      if (salesman.id == lookup) {
        return salesman;
      }
    }
    return null;
  }

  List<StationSalesmanModel> get _availableSalesmen {
    final selected = _selectedSalesman;
    final available = <StationSalesmanModel>[];
    for (final salesman in widget.salesmen) {
      if (!salesman.active &&
          (selected == null || salesman.id != selected.id)) {
        continue;
      }
      available.add(salesman);
    }
    available.sort(
      (left, right) => left.displayLabel.compareTo(right.displayLabel),
    );
    return available;
  }

  String? _validateSalesmanSelection() {
    final cash = _parseAmount(_cashController.text);
    if (cash <= 0) {
      return null;
    }
    if (_availableSalesmen.isEmpty) {
      return 'Add a salesman in settings first.';
    }
    if (_selectedSalesman == null) {
      return 'Select a salesman.';
    }
    return null;
  }

  double _parseAmount(String raw) => double.tryParse(raw.trim()) ?? 0;

  String? _validateCash(String raw) {
    if (raw.trim().isEmpty) {
      return null;
    }
    final value = double.tryParse(raw.trim());
    if (value == null) {
      return 'Enter a valid cash amount.';
    }
    if (value < 0) {
      return 'Cash cannot be negative.';
    }
    return null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final salesmanError = _validateSalesmanSelection();
    if (salesmanError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(salesmanError)));
      return;
    }
    final cash = _parseAmount(_cashController.text);
    Navigator.of(context).pop(
      MapEntry(
        widget.pump.id,
        PumpEntryDraft(
          salesman: _selectedSalesman == null
              ? const PumpSalesmanModel(
                  salesmanId: '',
                  salesmanName: '',
                  salesmanCode: '',
                )
              : PumpSalesmanModel(
                  salesmanId: _selectedSalesman!.id,
                  salesmanName: _selectedSalesman!.name,
                  salesmanCode: _selectedSalesman!.code,
                ),
          attendant: _selectedSalesman?.displayLabel ?? '',
          closingReadings: widget.initialDraft.closingReadings,
          testing: widget.initialDraft.testing,
          payments: PumpPaymentBreakdownModel(
            cash: cash,
            check: widget.initialDraft.payments.check,
            upi: widget.initialDraft.payments.upi,
            credit: widget.initialDraft.payments.credit,
          ),
          creditEntries: widget.initialDraft.creditEntries,
          mismatchReason: widget.initialDraft.mismatchReason,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cash Collection',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                formatPumpLabel(widget.pump.id, widget.pump.label),
                style: const TextStyle(
                  color: Color(0xFF55606E),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              ClayDropdownField<String>(
                label: 'Cash collected from',
                icon: Icons.person_outline_rounded,
                value: _selectedSalesmanId,
                helperText:
                    _selectedSalesman == null &&
                        widget.initialDraft.attendant.trim().isNotEmpty
                    ? 'Legacy value: ${widget.initialDraft.attendant}'
                    : 'Select from the salesman list in settings.',
                items: _availableSalesmen
                    .map(
                      (salesman) => DropdownMenuItem<String>(
                        value: salesman.id,
                        child: Text(salesman.displayLabel),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedSalesmanId = value;
                  });
                },
                validator: (_) => _validateSalesmanSelection(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cashController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Cash',
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) => _validateCash(value ?? ''),
                onFieldSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BusyActionButton(
                      onPressed: _save,
                      builder: (context, busy, handlePressed) => FilledButton(
                        onPressed: busy ? null : handlePressed,
                        child: Text(busy ? 'Saving...' : 'Save Cash'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreditEntryControllers {
  _CreditEntryControllers({
    this.customerMode = _creditCustomerModeNew,
    String customerId = '',
    String name = '',
    String amount = '',
  }) : customerIdController = TextEditingController(text: customerId),
       nameController = TextEditingController(text: name),
       amountController = TextEditingController(text: amount);

  String customerMode;
  final TextEditingController customerIdController;
  final TextEditingController nameController;
  final TextEditingController amountController;

  void dispose() {
    customerIdController.dispose();
    nameController.dispose();
    amountController.dispose();
  }
}

class _CreditCollectionControllers {
  _CreditCollectionControllers({
    String customerId = '',
    String name = '',
    String amount = '',
    String date = '',
    String paymentMode = '',
    String note = '',
  }) : customerIdController = TextEditingController(text: customerId),
       nameController = TextEditingController(text: name),
       amountController = TextEditingController(text: amount),
       dateController = TextEditingController(text: date),
       paymentModeController = TextEditingController(text: paymentMode),
       noteController = TextEditingController(text: note);

  final TextEditingController customerIdController;
  final TextEditingController nameController;
  final TextEditingController amountController;
  final TextEditingController dateController;
  final TextEditingController paymentModeController;
  final TextEditingController noteController;

  void dispose() {
    customerIdController.dispose();
    nameController.dispose();
    amountController.dispose();
    dateController.dispose();
    paymentModeController.dispose();
    noteController.dispose();
  }
}
