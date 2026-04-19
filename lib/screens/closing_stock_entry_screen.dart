import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/credit_service.dart';
import '../services/inventory_service.dart';
import '../services/sales_service.dart';
import '../utils/fuel_prices.dart';
import '../utils/formatters.dart';
import '../utils/user_facing_errors.dart';
import '../widgets/clay_widgets.dart';
import '../widgets/daily_fuel_widgets.dart';
import '../widgets/daily_entry_dialogs.dart';
import '../widgets/responsive_text.dart';
import 'daily_fuel_history_screen.dart';

class ClosingStockEntryScreen extends StatefulWidget {
  const ClosingStockEntryScreen({super.key});

  @override
  State<ClosingStockEntryScreen> createState() =>
      _ClosingStockEntryScreenState();
}

class _ClosingStockEntryScreenState extends State<ClosingStockEntryScreen> {
  static const double _heroControlHeight = 58;

  final SalesService _salesService = SalesService();
  final CreditService _creditService = CreditService();
  final InventoryService _inventoryService = InventoryService();
  SalesDashboardModel? _dashboard;
  Map<String, Map<String, double>> _resolvedPriceSnapshot =
      const <String, Map<String, double>>{};
  List<CreditCustomerSummaryModel> _suggestedCustomers = const [];
  String? _selectedDate;
  String? _persistedEntryId;
  DailyEntryDraft? _draft;
  bool _submitting = false;
  bool _savingDailyFuel = false;
  String? _busyPumpActionKey;
  Future<void>? _supportDataFuture;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String? date}) async {
    try {
      final dashboard = await _salesService.fetchDashboardForDate(
        date: date,
        forceRefresh: true,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _dashboard = dashboard;
        _resolvedPriceSnapshot = dashboard.priceSnapshot;
        _selectedDate = dashboard.date;
        _persistedEntryId = dashboard.selectedEntry?.id;
        _draft = _seedDraft(dashboard);
        _error = null;
      });
      _scheduleSupportDataLoad();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = userFacingErrorMessage(error);
      });
    }
  }

  bool _hasUsablePriceSnapshot(Map<String, Map<String, double>> snapshot) {
    const fuelKeys = ['petrol', 'diesel', 'two_t_oil'];
    for (final fuelKey in fuelKeys) {
      final prices = snapshot[fuelKey];
      if (prices == null) {
        continue;
      }
      if ((prices['sellingPrice'] ?? 0) > 0 || (prices['costPrice'] ?? 0) > 0) {
        return true;
      }
    }
    return false;
  }

  void _scheduleSupportDataLoad({
    bool forceCustomers = false,
    bool forcePrices = false,
  }) {
    final shouldLoadCustomers = forceCustomers || _suggestedCustomers.isEmpty;
    final shouldLoadPrices =
        forcePrices || !_hasUsablePriceSnapshot(_resolvedPriceSnapshot);
    if (!shouldLoadCustomers && !shouldLoadPrices) {
      return;
    }
    if (_supportDataFuture != null) {
      return;
    }

    _supportDataFuture = _loadSupportData(
      loadCustomers: shouldLoadCustomers,
      loadPrices: shouldLoadPrices,
    ).whenComplete(() {
      _supportDataFuture = null;
    });
  }

  Future<void> _loadSupportData({
    required bool loadCustomers,
    required bool loadPrices,
  }) async {
    final customersFuture =
        loadCustomers ? _creditService.fetchCustomers() : null;
    final pricesFuture =
        loadPrices ? _inventoryService.fetchPrices(activeOnly: true) : null;

    (CreditLedgerSummaryModel, List<CreditCustomerSummaryModel>)?
    customersResult;
    List<FuelPriceModel>? prices;

    if (customersFuture != null) {
      try {
        customersResult = await customersFuture;
      } catch (_) {
        customersResult = null;
      }
    }

    if (pricesFuture != null) {
      try {
        prices = await pricesFuture;
      } catch (_) {
        prices = null;
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      if (customersResult != null) {
        _suggestedCustomers = customersResult.$2;
      }
      if (prices != null && prices.isNotEmpty) {
        _resolvedPriceSnapshot = mergePriceSnapshots(
          primary: _resolvedPriceSnapshot,
          fallback: buildPriceSnapshotFromPrices(prices),
        );
      }
    });
  }

  Future<void> _ensureSupportDataReady() async {
    final shouldLoadCustomers = _suggestedCustomers.isEmpty;
    final shouldLoadPrices = !_hasUsablePriceSnapshot(_resolvedPriceSnapshot);
    if (!shouldLoadCustomers && !shouldLoadPrices) {
      return;
    }
    if (_supportDataFuture != null) {
      await _supportDataFuture;
      return;
    }
    _scheduleSupportDataLoad(
      forceCustomers: shouldLoadCustomers,
      forcePrices: shouldLoadPrices,
    );
    if (_supportDataFuture != null) {
      await _supportDataFuture;
    }
  }

  Future<void> _runPumpAction({
    required String actionKey,
    required Future<void> Function() action,
  }) async {
    if (_submitting || _busyPumpActionKey != null) {
      return;
    }

    setState(() {
      _busyPumpActionKey = actionKey;
      _error = null;
    });

    try {
      await action();
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
          _busyPumpActionKey = null;
        });
      }
    }
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

  DailyEntryDraft? _savePumpEdit(String pumpId, PumpEntryDraft pumpDraft) {
    final draft = _draft;
    if (draft == null) {
      return null;
    }
    final remainingCredits =
        draft.creditEntries.where((item) => item.pumpId != pumpId).toList();
    final updatedDraft = draft.copyWith(
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
    setState(() {
      _draft = updatedDraft;
    });
    return updatedDraft;
  }

  Future<void> _saveDraft(DailyEntryDraft draft) async {
    final selectedEntry = _dashboard?.selectedEntry;
    if (_selectedEntryApproved ||
        (selectedEntry != null &&
            selectedEntry.status.trim().toLowerCase() != 'draft')) {
      return;
    }

    final saved = await _salesService.saveDraftEntry(
      date: draft.date,
      closingReadings: draft.closingReadings,
      pumpAttendants: draft.pumpAttendants,
      pumpTesting: draft.pumpTesting,
      pumpPayments: draft.pumpPayments,
      pumpCollections: draft.pumpCollections,
      paymentBreakdown: draft.paymentBreakdown,
      creditEntries: draft.creditEntries,
      creditCollections: draft.creditCollections,
      mismatchReason: _buildEntryMismatchReason(draft),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _persistedEntryId = saved.id;
      _error = null;
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

  double _salesSettlementTotal(DailyEntryDraft draft) {
    final modes = _settlementModes(draft);
    return modes.cash + modes.check + modes.upi + _pumpCreditTotal(draft);
  }

  bool get _selectedEntryApproved =>
      _dashboard?.selectedEntry?.status.trim().toLowerCase() == 'approved';

  String _entryStatusLabel(SalesDashboardModel dashboard) {
    final selectedStatus =
        dashboard.selectedEntry?.status.trim().toLowerCase() ?? '';
    if (selectedStatus == 'draft' ||
        (dashboard.selectedEntry == null && _persistedEntryId != null)) {
      return 'Draft';
    }
    return dashboard.todaysEntries.isNotEmpty ? 'Added' : 'Pending';
  }

  bool _supportsTwoT(String pumpId) => true;

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

    if (_selectedEntryApproved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This entry is already approved. Admin can edit it from Entries.',
          ),
        ),
      );
      return;
    }
    await _runPumpAction(
      actionKey: 'pump:${pump.id}',
      action: () async {
        await _ensureSupportDataReady();
        if (!mounted) {
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

        final updatedDraft = _savePumpEdit(result.key, result.value);
        if (updatedDraft != null) {
          await _saveDraft(updatedDraft);
        }
      },
    );
  }

  Future<void> _editPumpCashCollection(StationPumpModel pump) async {
    final dashboard = _dashboard;
    final draft = _draft;
    if (dashboard == null || draft == null) {
      return;
    }

    if (_selectedEntryApproved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This entry is already approved. Admin can edit it from Entries.',
          ),
        ),
      );
      return;
    }

    await _runPumpAction(
      actionKey: 'collection:${pump.id}',
      action: () async {
        final result = await showPumpCashCollectionDialog(
          context: context,
          pump: pump,
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
        );
        if (!mounted || result == null) {
          return;
        }

        final updatedDraft = _savePumpEdit(result.key, result.value);
        if (updatedDraft != null) {
          await _saveDraft(updatedDraft);
        }
      },
    );
  }

  Future<void> _submitEntry() async {
    final dashboard = _dashboard;
    final draft = _draft;
    if (dashboard == null || _selectedDate == null || draft == null) {
      return;
    }

    if (!dashboard.setupExists || dashboard.allowedEntryDate.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            dashboard.entryLockedReason.isNotEmpty
                ? dashboard.entryLockedReason
                : 'Management must create the first day setup before sales entry can start.',
          ),
        ),
      );
      return;
    }

    if (_selectedEntryApproved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This entry is already approved. Admin can edit it from Entries.',
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
    final dashboard = _dashboard;
    if (dashboard == null) {
      return;
    }

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

      final existingEntry = dashboard.selectedEntry;
      final existingEntryId = existingEntry?.id ?? _persistedEntryId;
      final wasDraft =
          existingEntry?.status.trim().toLowerCase() == 'draft' ||
          (existingEntry == null && _persistedEntryId != null);
      if (existingEntryId == null) {
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
      } else {
        await _salesService.updateEntry(
          entryId: existingEntryId,
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
      }
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existingEntryId == null || wasDraft
                ? 'Entry submitted. Collected ${formatCurrency(preview.paymentTotal)}.'
                : 'Entry updated. Collected ${formatCurrency(preview.paymentTotal)}.',
          ),
        ),
      );
      await _load(date: draft.date);
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

  Future<void> _saveDailyFuelRecord(Map<String, double> density) async {
    final targetDate = _selectedDate ?? _dashboard?.date;
    if (targetDate == null) {
      return;
    }
    setState(() {
      _savingDailyFuel = true;
      _error = null;
    });
    try {
      await _inventoryService.saveDailyFuelRecord(
        date: targetDate,
        density: density,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Daily fuel density saved.')),
      );
      await _load(date: targetDate);
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
          _savingDailyFuel = false;
        });
      }
    }
  }

  Future<void> _openDailyFuelHistory() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const DailyFuelHistoryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = _dashboard;
    final draft = _draft;
    final canWorkOnEntry =
        dashboard != null &&
        dashboard.setupExists &&
        dashboard.allowedEntryDate.trim().isNotEmpty &&
        dashboard.date == dashboard.allowedEntryDate;
    final summary =
        dashboard != null && draft != null
            ? _draftSoldTotals(dashboard, draft)
            : const PumpReadings(petrol: 0, diesel: 0, twoT: 0);
    return Scaffold(
      backgroundColor: kClayBg,
      body:
          dashboard == null
              ? ColoredBox(
                color: kClayBg,
                child: Center(
                  child:
                      _error == null
                          ? const CircularProgressIndicator()
                          : Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: kClayPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                ),
              )
              : ListView(
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
                        const Text(
                          'DAILY SALES ENTRY',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w800,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          dashboard.station.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dashboard.setupExists
                              ? 'Complete the next pending day entry pump by pump.'
                              : 'Management must create the first day setup before sales entry can start.',
                          style: TextStyle(
                            color: Colors.white70,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Container(
                                height: _heroControlHeight,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.28),
                                  ),
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_month_rounded,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Date: ${formatDateLabel(_selectedDate ?? dashboard.date)}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: _ClosingHeroStatusCard(
                                label:
                                    dashboard.setupExists
                                        ? 'Entry today'
                                        : 'Setup status',
                                value:
                                    dashboard.setupExists
                                        ? _entryStatusLabel(dashboard)
                                        : 'Required',
                              ),
                            ),
                          ],
                        ),
                        if (dashboard.entryLockedReason.trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Text(
                              dashboard.entryLockedReason,
                              style: const TextStyle(
                                color: Colors.white,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  DailyFuelEntrySection(
                    targetDate: _selectedDate ?? dashboard.date,
                    record: dashboard.dailyFuelRecord,
                    busy: _savingDailyFuel,
                    onSave: _saveDailyFuelRecord,
                    onHistory: _openDailyFuelHistory,
                  ),
                  const SizedBox(height: 16),
                  const _ClosingSectionLabel(label: 'PUMPS'),
                  const SizedBox(height: 10),
                  ...dashboard.station.pumps.map((pump) {
                    final opening =
                        dashboard.openingReadings[pump.id] ??
                        const PumpReadings(petrol: 0, diesel: 0, twoT: 0);
                    final existing = dashboard.selectedEntry;
                    final attendant =
                        draft?.pumpAttendants[pump.id] ??
                        existing?.pumpAttendants[pump.id] ??
                        '';
                    final closing =
                        draft?.closingReadings[pump.id] ??
                        existing?.closingReadings[pump.id];
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
                                _ClosingPill(
                                  label: attendant,
                                  color: kClayHeroStart,
                                ),
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
                            accent: const Color(0xFF0F8A73),
                          ),
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
                            accent: const Color(0xFF0F8A73),
                          ),
                          _PumpRow(
                            label: 'Entered 2T oil sold',
                            value:
                                _supportsTwoT(pump.id)
                                    ? _twoTSoldLabel(opening, closing)
                                    : 'Not supported',
                            accent: const Color(0xFFC36A10),
                          ),
                          _PumpRow(
                            label: 'Cash collected from',
                            value: _cashCollectedFromLabel(pump.id, draft),
                            accent: const Color(0xFFC36A10),
                          ),
                          _PumpRow(
                            label: 'Cash',
                            value: formatCurrency(
                              draft?.pumpPayments[pump.id]?.cash ??
                                  existing?.pumpPayments[pump.id]?.cash ??
                                  0,
                            ),
                            accent: const Color(0xFFC36A10),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed:
                                      (!canWorkOnEntry ||
                                              _selectedEntryApproved)
                                          ? null
                                          : () => _editPumpCashCollection(pump),
                                  icon: const Icon(Icons.payments_outlined),
                                  label: const Text('Cash Collection'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed:
                                      (!canWorkOnEntry ||
                                              _selectedEntryApproved)
                                          ? null
                                          : () => _editPump(pump),
                                  icon:
                                      _busyPumpActionKey == 'pump:${pump.id}'
                                          ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                          : const Icon(Icons.edit_rounded),
                                  label: Text(
                                    existing == null
                                        ? 'Update Pump'
                                        : 'Edit Pump',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  const _ClosingSectionLabel(label: 'SUMMARY'),
                  const SizedBox(height: 10),
                  ClayCard(
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
                                  color: kClayPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Cash, check, UPI, and newly issued pump credit come from the pump entries.',
                          style: TextStyle(
                            color: kClaySub,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
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
                          label: 'HP Pay total',
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
                          label: 'New credit issued',
                          value: formatCurrency(
                            draft == null ? 0 : _issuedCreditTotal(draft),
                          ),
                        ),
                        _PaymentRow(
                          label: 'Sales settlement total',
                          value: formatCurrency(
                            draft == null ? 0 : _salesSettlementTotal(draft),
                          ),
                        ),
                        const SizedBox(height: 12),
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
                                draft == null || _pumpCreditTotal(draft) <= 0
                                    ? 'No pump credit added yet. Use Add Credit inside a pump to create customer-wise credit rows.'
                                    : 'Pump credit is built from the customer-wise credit rows added inside each pump. Once approved, these names will be shown in Credit Ledger.',
                                style: const TextStyle(
                                  color: kClaySub,
                                  height: 1.4,
                                  fontWeight: FontWeight.w600,
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
                              const SizedBox(height: 10),
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
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
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
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed:
                        (_submitting || !canWorkOnEntry) ? null : _submitEntry,
                    icon: const Icon(Icons.edit_note_rounded),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      backgroundColor: kClayHeroStart,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    label: Text(
                      _submitting
                          ? 'Submitting...'
                          : _selectedEntryApproved
                          ? 'Entry Approved'
                          : dashboard.selectedEntry == null
                          ? 'Submit Entry'
                          : 'Update Entry',
                    ),
                  ),
                ],
              ),
    );
  }
}

class _ClosingSectionLabel extends StatelessWidget {
  const _ClosingSectionLabel({required this.label});

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

class _ClosingHeroStatusCard extends StatelessWidget {
  const _ClosingHeroStatusCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final normalized = value.trim().toLowerCase();
    final accent =
        normalized == 'added'
            ? const Color(0xFF2AA878)
            : const Color(0xFFFFD166);
    final textColor =
        normalized == 'added' ? Colors.white : const Color(0xFF1A2561);

    return Container(
      height: _ClosingStockEntryScreenState._heroControlHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Entry today',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: OneLineScaleText(
              value,
              alignment: Alignment.centerLeft,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClosingPill extends StatelessWidget {
  const _ClosingPill({required this.label, required this.color});

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
