import 'dart:async';

import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/api_response_cache.dart';
import '../services/inventory_service.dart';
import '../services/management_service.dart';
import '../services/sales_service.dart';
import '../utils/fuel_prices.dart';
import '../utils/formatters.dart';
import '../utils/user_facing_errors.dart';
import '../widgets/app_date_range_picker.dart';
import '../widgets/daily_fuel_widgets.dart';
import '../widgets/responsive_text.dart';
import 'daily_fuel_history_screen.dart';
import 'entry_workflow_screen.dart';

class EntryManagementScreen extends StatefulWidget {
  const EntryManagementScreen({super.key});

  @override
  State<EntryManagementScreen> createState() => _EntryManagementScreenState();
}

enum _EntryAction { approve, delete }

class _EntryManagementScreenState extends State<EntryManagementScreen> {
  final ManagementService _managementService = ManagementService();
  final SalesService _salesService = SalesService();
  final InventoryService _inventoryService = InventoryService();
  static const List<String> _monthNames = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  // Filter state — either month mode or date-range mode
  String _filterMonth = currentMonthKey(); // 'YYYY-MM'
  String? _filterFromDate; // 'YYYY-MM-DD'
  String? _filterToDate; // 'YYYY-MM-DD'
  bool _filterByDateRange = false;

  late Future<_EntryManagementData> _future;
  late final StreamSubscription<ApiResponseCacheUpdate> _cacheSubscription;
  bool _submitting = false;
  bool _savingDailyFuel = false;
  String? _activeEntryId;
  _EntryAction? _activeAction;
  // null = All, 'approved', 'pending', 'flagged'
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
    _cacheSubscription = ApiResponseCache.updates.listen((update) {
      if (!mounted || !update.background) {
        return;
      }
      if (!update.path.startsWith('/management/entries') &&
          !update.path.startsWith('/sales/dashboard')) {
        return;
      }
      setState(() => _future = _loadData());
    });
  }

  @override
  void dispose() {
    _cacheSubscription.cancel();
    super.dispose();
  }

  Future<_EntryManagementData> _loadData({bool forceRefresh = false}) async {
    final results = await Future.wait([
      _filterByDateRange
          ? _managementService.fetchEntries(
            fromDate: _filterFromDate,
            toDate: _filterToDate,
            forceRefresh: true,
          )
          : _managementService.fetchEntries(
            month: _filterMonth,
            forceRefresh: true,
          ),
      _salesService.fetchDashboard(forceRefresh: true),
    ]);

    var entries = results[0] as List<ShiftEntryModel>;

    // Client-side safety filter for date range mode
    if (_filterByDateRange) {
      final from =
          _filterFromDate != null ? DateTime.tryParse(_filterFromDate!) : null;
      final to =
          _filterToDate != null ? DateTime.tryParse(_filterToDate!) : null;
      entries =
          entries.where((e) {
            final d = DateTime.tryParse(e.date);
            if (d == null) {
              return true;
            }
            final day = DateTime(d.year, d.month, d.day);
            if (from != null &&
                day.isBefore(DateTime(from.year, from.month, from.day))) {
              return false;
            }
            if (to != null &&
                day.isAfter(DateTime(to.year, to.month, to.day))) {
              return false;
            }
            return true;
          }).toList();
    }

    return _EntryManagementData(
      entries: entries,
      dashboard: results[1] as SalesDashboardModel,
    );
  }

  Future<void> _reload() async {
    setState(() => _future = _loadData(forceRefresh: true));
    await _future;
  }

  static String _fmtDate(String raw) => formatDateLabel(raw);

  String get _periodLabel {
    if (_filterByDateRange) {
      final from = _filterFromDate != null ? _fmtDate(_filterFromDate!) : '—';
      final to = _filterToDate != null ? _fmtDate(_filterToDate!) : '—';
      return '$from – $to';
    }
    final parts = _filterMonth.split('-');
    if (parts.length != 2) return _filterMonth;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (y == null || m == null || m < 1 || m > 12) return _filterMonth;
    return '${_monthNames[m - 1]} $y';
  }

  String get _periodShort {
    if (_filterByDateRange) {
      const short = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      String shortDate(String? d) {
        if (d == null) return '—';
        final dt = DateTime.tryParse(d);
        if (dt == null) return d;
        return '${short[dt.month - 1]} ${dt.day}';
      }

      return '${shortDate(_filterFromDate)} – ${shortDate(_filterToDate)}';
    }
    final parts = _filterMonth.split('-');
    if (parts.length != 2) return _filterMonth;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (y == null || m == null || m < 1 || m > 12) return _filterMonth;
    const short = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${short[m - 1]} $y';
  }

  Future<void> _openFilterDialog() async {
    final now = DateTime.now();

    // Local dialog state
    bool byRange = _filterByDateRange;
    final parts = _filterMonth.split('-');
    int selYear = int.tryParse(parts.firstOrNull ?? '') ?? now.year;
    int selMonth = int.tryParse(parts.length > 1 ? parts[1] : '') ?? now.month;
    DateTime? fromDt =
        _filterFromDate != null ? DateTime.tryParse(_filterFromDate!) : null;
    DateTime? toDt =
        _filterToDate != null ? DateTime.tryParse(_filterToDate!) : null;

    Future<void> pickRange(BuildContext pickerContext, StateSetter set) async {
      final picked = await showAppDateRangePicker(
        context: pickerContext,
        fromDate: fromDt,
        toDate: toDt,
        firstDate: DateTime(2024),
        lastDate: now,
        helpText: 'Select entry range',
      );
      if (picked != null) {
        set(() {
          fromDt = picked.start;
          toDt = picked.end;
        });
      }
    }

    String formatDialogDate(DateTime? dt) {
      if (dt == null) return 'Tap to choose';
      return formatDateLabel(
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}',
      );
    }

    String formatDialogRange() {
      if (fromDt == null || toDt == null) return 'Tap to choose';
      return '${formatDialogDate(fromDt)} to ${formatDialogDate(toDt)}';
    }

    final applied = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final years = List<int>.generate(
              now.year - 2024 + 1,
              (i) => now.year - i,
            );

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 24,
              ),
              title: const Text('Filter Entries'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Mode toggle ─────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFECEFF8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          _ToggleTab(
                            label: 'By Month',
                            selected: !byRange,
                            onTap: () => setDialogState(() => byRange = false),
                          ),
                          _ToggleTab(
                            label: 'Date Range',
                            selected: byRange,
                            onTap: () => setDialogState(() => byRange = true),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (!byRange) ...[
                      // ── Month mode ───────────────────────────
                      DropdownButtonFormField<int>(
                        initialValue: selMonth,
                        decoration: const InputDecoration(
                          labelText: 'Month',
                          filled: true,
                        ),
                        items: List.generate(
                          _monthNames.length,
                          (i) => DropdownMenuItem<int>(
                            value: i + 1,
                            child: Text(_monthNames[i]),
                          ),
                        ),
                        onChanged: (v) {
                          if (v == null) return;
                          setDialogState(() => selMonth = v);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: selYear,
                        decoration: const InputDecoration(
                          labelText: 'Year',
                          filled: true,
                        ),
                        items:
                            years
                                .map(
                                  (y) => DropdownMenuItem<int>(
                                    value: y,
                                    child: Text('$y'),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setDialogState(() => selYear = v);
                        },
                      ),
                      const SizedBox(height: 16),
                      _PreviewBox(
                        text: '${_monthNames[selMonth - 1]} $selYear',
                      ),
                    ] else ...[
                      // ── Date range mode ──────────────────────
                      _DatePickerRow(
                        label: 'Date Range',
                        value: formatDialogRange(),
                        onTap: () => pickRange(dialogContext, setDialogState),
                      ),
                      const SizedBox(height: 16),
                      if (fromDt != null && toDt != null)
                        _PreviewBox(
                          text:
                              '${formatDialogDate(fromDt)} – ${formatDialogDate(toDt)}',
                        ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    final cur = currentMonthKey().split('-');
                    setDialogState(() {
                      byRange = false;
                      selYear = int.tryParse(cur[0]) ?? now.year;
                      selMonth = int.tryParse(cur[1]) ?? now.month;
                    });
                  },
                  child: const Text('This Month'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    if (byRange && (fromDt == null || toDt == null)) return;
                    Navigator.of(dialogContext).pop(true);
                  },
                  icon: const Icon(Icons.filter_alt_rounded),
                  label: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    if (applied != true) return;

    setState(() {
      _filterByDateRange = byRange;
      if (byRange) {
        _filterFromDate =
            fromDt != null
                ? '${fromDt!.year}-${fromDt!.month.toString().padLeft(2, '0')}-${fromDt!.day.toString().padLeft(2, '0')}'
                : null;
        _filterToDate =
            toDt != null
                ? '${toDt!.year}-${toDt!.month.toString().padLeft(2, '0')}-${toDt!.day.toString().padLeft(2, '0')}'
                : null;
      } else {
        _filterMonth = '$selYear-${selMonth.toString().padLeft(2, '0')}';
        _filterFromDate = null;
        _filterToDate = null;
      }
    });
    await _reload();
  }

  DailyEntryDraft _draftFromEntry(ShiftEntryModel entry) {
    return DailyEntryDraft(
      date: entry.date,
      closingReadings: entry.closingReadings,
      pumpAttendants: entry.pumpAttendants,
      pumpTesting: entry.pumpTesting,
      pumpPayments: entry.pumpPayments,
      pumpCollections: entry.pumpCollections,
      paymentBreakdown: entry.paymentBreakdown,
      creditEntries: entry.creditEntries,
      creditCollections: entry.creditCollections,
      mismatchReason: entry.mismatchReason,
    );
  }

  Future<void> _openAdminEntryDialog([String? preselectedDate]) async {
    setState(() => _submitting = true);

    try {
      final dashboard = await _salesService.fetchDashboardForDate(
        date: preselectedDate,
        forceRefresh: true,
      );
      if (!dashboard.dailyFuelRecordComplete) {
        throw Exception(
          'Save petrol and diesel density before creating an entry.',
        );
      }
      final date = preselectedDate ?? dashboard.allowedEntryDate;
      if (!dashboard.setupExists || date.trim().isEmpty) {
        throw Exception(
          dashboard.entryLockedReason.isNotEmpty
              ? dashboard.entryLockedReason
              : 'Create a day setup before sales entry can start.',
        );
      }
      if (!mounted) return;

      final created = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder:
              (_) => EntryWorkflowScreen(
                title:
                    dashboard.selectedEntry == null
                        ? 'Daily Admin Entry'
                        : 'Edit Daily Entry',
                station: dashboard.station,
                openingReadings: dashboard.openingReadings,
                priceSnapshot: mergePriceSnapshots(
                  primary:
                      dashboard.selectedEntry?.priceSnapshot ??
                      const <String, Map<String, double>>{},
                  fallback: dashboard.priceSnapshot,
                ),
                initialDraft:
                    dashboard.selectedEntry == null
                        ? DailyEntryDraft(
                          date: date,
                          closingReadings: const {},
                          pumpAttendants: {
                            for (final pump in dashboard.station.pumps)
                              pump.id: '',
                          },
                          pumpTesting: {
                            for (final pump in dashboard.station.pumps)
                              pump.id: const PumpTestingModel(
                                petrol: 0,
                                diesel: 0,
                              ),
                          },
                          pumpPayments: const {},
                          pumpCollections: const {},
                          paymentBreakdown: const PaymentBreakdownModel(
                            cash: 0,
                            check: 0,
                            upi: 0,
                          ),
                          creditEntries: const [],
                          creditCollections: const [],
                        )
                        : _draftFromEntry(dashboard.selectedEntry!),
                dailyFuelRecord: dashboard.dailyFuelRecord,
                isAdmin: true,
                existingEntryId: dashboard.selectedEntry?.id,
                canChangeDate: false,
                onSubmit: (draft, mismatchReason) async {
                  if (dashboard.selectedEntry == null) {
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
                    await _managementService.updateEntry(
                      entryId: dashboard.selectedEntry!.id,
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
                },
              ),
        ),
      );
      if (created != true) return;
      await _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFB91C1C),
          content: Text(userFacingErrorMessage(error)),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _editEntry(
    ShiftEntryModel entry,
    StationConfigModel station,
    String allowedEntryDate,
  ) async {
    if (allowedEntryDate.trim().isNotEmpty && entry.date != allowedEntryDate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFB91C1C),
          content: Text(
            'Entry edits are restricted to ${formatDateLabel(allowedEntryDate)}.',
          ),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final detailedEntry = await _managementService.fetchEntryDetail(
        entry.id,
        forceRefresh: true,
      );
      final dailyFuelRecord = await _inventoryService.fetchDailyFuelRecord(
        date: detailedEntry.date,
        forceRefresh: true,
      );
      if (!mounted) return;

      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder:
              (_) => EntryWorkflowScreen(
                title: 'Edit Daily Entry',
                station: station,
                openingReadings: detailedEntry.openingReadings,
                priceSnapshot: detailedEntry.priceSnapshot,
                initialDraft: _draftFromEntry(detailedEntry),
                dailyFuelRecord: dailyFuelRecord,
                isAdmin: true,
                existingEntryId: detailedEntry.id,
                canChangeDate: false,
                onSubmit: (draft, mismatchReason) async {
                  await _managementService.updateEntry(
                    entryId: detailedEntry.id,
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
                },
              ),
        ),
      );

      if (saved != true) return;
      await _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFB91C1C),
          content: Text(userFacingErrorMessage(error)),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _saveDailyFuelRecord(
    SalesDashboardModel dashboard,
    Map<String, double> density,
  ) async {
    setState(() {
      _savingDailyFuel = true;
    });
    try {
      await _inventoryService.saveDailyFuelRecord(
        date: dashboard.date,
        density: density,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Daily fuel density saved.')),
      );
      await _reload();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingErrorMessage(error))));
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

  void _setEntryActionBusy(ShiftEntryModel entry, _EntryAction action) {
    setState(() {
      _submitting = true;
      _activeEntryId = entry.id;
      _activeAction = action;
    });
  }

  void _clearEntryActionBusy() {
    if (!mounted) {
      return;
    }
    setState(() {
      _submitting = false;
      _activeEntryId = null;
      _activeAction = null;
    });
  }

  Future<bool> _confirmApproveEntry(ShiftEntryModel entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Approve Entry'),
            content: Text(
              'Approve the entry for ${formatDateLabel(entry.date)}? Once approved, the date cannot be changed and sales staff cannot edit it.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Approve'),
              ),
            ],
          ),
    );
    return confirmed == true;
  }

  Future<void> _approveEntry(ShiftEntryModel entry) async {
    final confirmed = await _confirmApproveEntry(entry);
    if (!confirmed) return;
    if (!mounted) return;

    _setEntryActionBusy(entry, _EntryAction.approve);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Approving entry...')));

    try {
      await _managementService.approveEntry(entry.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Entry approved.')));
      await _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFB91C1C),
            content: Text(userFacingErrorMessage(error)),
          ),
        );
    } finally {
      _clearEntryActionBusy();
    }
  }

  Future<bool> _confirmDeleteEntry(ShiftEntryModel entry) async {
    final isApproved = entry.isFinalized;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(isApproved ? 'Override Delete Entry' : 'Delete Entry'),
            content: Text(
              isApproved
                  ? 'This entry is already approved. Deleting it will override that approval and recalculate opening readings for later dates. Continue?'
                  : 'Delete the entry for ${formatDateLabel(entry.date)}? Later dates will be recalculated automatically.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB91C1C),
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(isApproved ? 'Override Delete' : 'Delete'),
              ),
            ],
          ),
    );
    return confirmed == true;
  }

  Future<void> _deleteEntry(ShiftEntryModel entry) async {
    final confirmed = await _confirmDeleteEntry(entry);
    if (!confirmed) return;
    if (!mounted) return;

    _setEntryActionBusy(entry, _EntryAction.delete);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Deleting entry...')));

    try {
      await _managementService.deleteEntry(entry.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              entry.isFinalized
                  ? 'Approved entry deleted and override applied.'
                  : 'Entry deleted.',
            ),
          ),
        );
      await _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFB91C1C),
            content: Text(userFacingErrorMessage(error)),
          ),
        );
    } finally {
      _clearEntryActionBusy();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECEFF8),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<_EntryManagementData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Center(child: Text(userFacingErrorMessage(snapshot.error))),
                ],
              );
            }

            final data = snapshot.data!;
            final allEntries = data.entries;
            final approvedCount =
                allEntries.where((e) => e.status == 'approved').length;
            final flaggedCount =
                allEntries
                    .where((e) => e.flagged && e.status != 'approved')
                    .length;
            final pendingCount = allEntries.length - approvedCount;

            final entries =
                _statusFilter == null
                    ? allEntries
                    : _statusFilter == 'approved'
                    ? allEntries.where((e) => e.status == 'approved').toList()
                    : _statusFilter == 'flagged'
                    ? allEntries
                        .where((e) => e.flagged && e.status != 'approved')
                        .toList()
                    : allEntries.where((e) => e.status != 'approved').toList();
            final periodLabel = _periodLabel;
            final periodShort = _periodShort;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                // ── Hero header ─────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A3A7A), Color(0xFF0D2460)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0D2460).withValues(alpha: 0.45),
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data.dashboard.station.name,
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                const Text(
                                  'Entries',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Period pill
                          GestureDetector(
                            onTap: _openFilterDialog,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.calendar_month_rounded,
                                    color: Colors.white70,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    periodShort,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: Colors.white60,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          _HeroStat(
                            label: 'Total',
                            value: '${allEntries.length}',
                            active: _statusFilter == null,
                            onTap: () => setState(() => _statusFilter = null),
                          ),
                          const SizedBox(width: 8),
                          _HeroStat(
                            label: 'Approved',
                            value: '$approvedCount',
                            active: _statusFilter == 'approved',
                            onTap:
                                () => setState(
                                  () =>
                                      _statusFilter =
                                          _statusFilter == 'approved'
                                              ? null
                                              : 'approved',
                                ),
                          ),
                          const SizedBox(width: 8),
                          _HeroStat(
                            label: 'Pending',
                            value: '$pendingCount',
                            active: _statusFilter == 'pending',
                            onTap:
                                () => setState(
                                  () =>
                                      _statusFilter =
                                          _statusFilter == 'pending'
                                              ? null
                                              : 'pending',
                                ),
                          ),
                          const SizedBox(width: 8),
                          _HeroStat(
                            label: 'Flagged',
                            value: '$flaggedCount',
                            active: _statusFilter == 'flagged',
                            onTap:
                                () => setState(
                                  () =>
                                      _statusFilter =
                                          _statusFilter == 'flagged'
                                              ? null
                                              : 'flagged',
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── New Entry button ─────────────────────────────────────
                DailyFuelEntrySection(
                  targetDate: data.dashboard.date,
                  record: data.dashboard.dailyFuelRecord,
                  busy: _savingDailyFuel,
                  onSave:
                      (density) =>
                          _saveDailyFuelRecord(data.dashboard, density),
                  onHistory: _openDailyFuelHistory,
                ),
                const SizedBox(height: 14),
                _ClayButton(
                  icon: Icons.add_rounded,
                  label:
                      _submitting
                          ? 'Opening...'
                          : data.dashboard.dailyFuelRecordComplete
                          ? 'New Entry'
                          : 'Save Density First',
                  onTap:
                      (_submitting || !data.dashboard.dailyFuelRecordComplete)
                          ? null
                          : _openAdminEntryDialog,
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _openDailyFuelHistory,
                  icon: const Icon(Icons.history_rounded),
                  label: const Text('Fuel Register History'),
                ),

                const SizedBox(height: 18),

                // ── Period label ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 10),
                  child: Text(
                    periodLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8A93B8),
                      letterSpacing: 0.2,
                    ),
                  ),
                ),

                // ── Entry cards ──────────────────────────────────────────
                if (entries.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFB8C0DC).withValues(alpha: 0.7),
                          offset: const Offset(6, 6),
                          blurRadius: 16,
                        ),
                        const BoxShadow(
                          color: Colors.white,
                          offset: Offset(-5, -5),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'No entries found for this period.',
                        style: TextStyle(
                          color: Color(0xFF8A93B8),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  )
                else
                  ...entries.reversed.map((entry) {
                    final submittedLabel =
                        entry.submittedByName.trim().isNotEmpty
                            ? entry.submittedByName.trim()
                            : entry.submittedBy.trim();
                    return _EntryCard(
                      entry: entry,
                      station: data.dashboard.station,
                      submittedLabel: submittedLabel,
                      submitting: _submitting,
                      activeAction:
                          _activeEntryId == entry.id ? _activeAction : null,
                      onEdit:
                          () => _editEntry(
                            entry,
                            data.dashboard.station,
                            data.dashboard.allowedEntryDate,
                          ),
                      onDelete: () => _deleteEntry(entry),
                      onApprove: () => _approveEntry(entry),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Clay action button ────────────────────────────────────────────────────────
class _ClayButton extends StatefulWidget {
  const _ClayButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  State<_ClayButton> createState() => _ClayButtonState();
}

class _ClayButtonState extends State<_ClayButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;
    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
      onTapUp:
          disabled
              ? null
              : (_) {
                setState(() => _pressed = false);
                widget.onTap!();
              },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: 52,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF1A3A7A),
          borderRadius: BorderRadius.circular(18),
          boxShadow:
              _pressed || disabled
                  ? [
                    BoxShadow(
                      color: const Color(0xFF0D2460).withValues(alpha: 0.3),
                      offset: const Offset(2, 2),
                      blurRadius: 6,
                    ),
                  ]
                  : [
                    BoxShadow(
                      color: const Color(0xFF0D2460).withValues(alpha: 0.5),
                      offset: const Offset(0, 8),
                      blurRadius: 20,
                    ),
                  ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              widget.label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Hero stat cell ────────────────────────────────────────────────────────────
class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label,
    required this.value,
    required this.active,
    required this.onTap,
  });
  final String label;
  final String value;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color:
                active
                    ? Colors.white.withValues(alpha: 0.22)
                    : Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border:
                active
                    ? Border.all(color: Colors.white.withValues(alpha: 0.45))
                    : Border.all(color: Colors.transparent),
          ),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 22,
                child: OneLineScaleText(
                  value,
                  alignment: Alignment.center,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              OneLineScaleText(
                label,
                alignment: Alignment.center,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: active ? Colors.white : Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Entry card ────────────────────────────────────────────────────────────────
class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.station,
    required this.submittedLabel,
    required this.submitting,
    required this.activeAction,
    required this.onEdit,
    required this.onDelete,
    required this.onApprove,
  });

  final ShiftEntryModel entry;
  final StationConfigModel station;
  final String submittedLabel;
  final bool submitting;
  final _EntryAction? activeAction;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    final isApproved = entry.isFinalized;
    final isFlagged = entry.flagged;
    final isDeleting = activeAction == _EntryAction.delete;
    final isApproving = activeAction == _EntryAction.approve;
    final weekday = formatWeekdayLabel(entry.date);
    final pumpLabels = {
      for (final pump in station.pumps)
        pump.id: formatPumpLabel(pump.id, pump.label),
    };
    final attendantLabels =
        entry.pumpAttendants.entries
            .where((item) => item.value.trim().isNotEmpty)
            .map(
              (item) =>
                  '${pumpLabels[item.key] ?? formatPumpLabel(item.key)}: ${item.value.trim()}',
            )
            .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB8C0DC).withValues(alpha: 0.75),
            offset: const Offset(6, 6),
            blurRadius: 16,
          ),
          const BoxShadow(
            color: Colors.white,
            offset: Offset(-5, -5),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Date + status ──────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Text(
                  weekday.isEmpty
                      ? formatDateLabel(entry.date)
                      : '${formatDateLabel(entry.date)} ($weekday)',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    color: Color(0xFF1A2561),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              _StatusBadge(status: entry.status, flagged: isFlagged),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'by $submittedLabel',
            style: const TextStyle(
              color: Color(0xFF8A93B8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 14),

          // ── Metrics grid ───────────────────────────────────────────
          Builder(
            builder: (context) {
              final diff = entry.paymentTotal - entry.computedRevenue;
              return _EntryMetricsGrid(
                items: [
                  _EntryMetricItem(
                    label: 'Petrol',
                    value: formatLiters(entry.totals.sold.petrol),
                  ),
                  _EntryMetricItem(
                    label: 'Sales',
                    value: formatCurrency(entry.revenue),
                    accent: const Color(0xFF1A3A7A),
                  ),
                  _EntryMetricItem(
                    label: 'Diesel',
                    value: formatLiters(entry.totals.sold.diesel),
                  ),
                  _EntryMetricItem(
                    label: 'Collected',
                    value: formatCurrency(entry.paymentTotal),
                    accent: const Color(0xFF1A7A5A),
                  ),
                  _EntryMetricItem(
                    label: '2T Oil',
                    value: formatLiters(entry.totals.sold.twoT),
                  ),
                  _EntryMetricItem(
                    label: 'Difference',
                    value: formatCurrency(diff),
                    accent:
                        diff >= 0
                            ? const Color(0xFF2AA878)
                            : const Color(0xFFB91C1C),
                  ),
                ],
              );
            },
          ),

          // ── Pump attendants ────────────────────────────────────────
          if (attendantLabels.isNotEmpty) ...[
            const SizedBox(height: 10),
            _PumpAttendantGrid(labels: attendantLabels),
          ],

          // ── Variance note ──────────────────────────────────────────
          if (entry.varianceNote.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFB91C1C).withValues(alpha: 0.15),
                ),
              ),
              child: Text(
                entry.varianceNote,
                style: const TextStyle(
                  color: Color(0xFFB91C1C),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),

          // ── Action buttons ─────────────────────────────────────────
          Row(
            children: [
              _ActionBtn(
                icon: Icons.edit_rounded,
                label: 'Edit',
                onTap: submitting ? null : onEdit,
              ),
              const SizedBox(width: 8),
              _ActionBtn(
                icon: Icons.delete_outline_rounded,
                label:
                    isDeleting
                        ? 'Deleting...'
                        : isApproved
                        ? 'Override'
                        : 'Delete',
                onTap: submitting ? null : onDelete,
                danger: true,
                loading: isDeleting,
              ),
              if (!isApproved) ...[
                const SizedBox(width: 8),
                _ActionBtn(
                  icon: Icons.verified_rounded,
                  label: isApproving ? 'Approving...' : 'Approve',
                  onTap: submitting ? null : onApprove,
                  filled: true,
                  loading: isApproving,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Metric cell ───────────────────────────────────────────────────────────────
class _EntryMetricItem {
  const _EntryMetricItem({
    required this.label,
    required this.value,
    this.accent,
  });

  final String label;
  final String value;
  final Color? accent;
}

class _EntryMetricsGrid extends StatelessWidget {
  const _EntryMetricsGrid({required this.items});

  final List<_EntryMetricItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFECEFF8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i += 2) ...[
            Row(
              children: [
                Expanded(child: _EntryMetricTile(item: items[i])),
                const SizedBox(width: 8),
                Expanded(child: _EntryMetricTile(item: items[i + 1])),
              ],
            ),
            if (i + 2 < items.length) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _EntryMetricTile extends StatelessWidget {
  const _EntryMetricTile({required this.item});

  final _EntryMetricItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OneLineScaleText(
            item.label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF8A93B8),
            ),
          ),
          const SizedBox(height: 5),
          OneLineScaleText(
            item.value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: item.accent ?? const Color(0xFF1A2561),
            ),
          ),
        ],
      ),
    );
  }
}

class _PumpAttendantGrid extends StatelessWidget {
  const _PumpAttendantGrid({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < labels.length; i += 2)
          Padding(
            padding: EdgeInsets.only(bottom: i + 2 < labels.length ? 6 : 0),
            child: Row(
              children: [
                Expanded(child: _PumpAttendantRow(label: labels[i])),
                const SizedBox(width: 8),
                if (i + 1 < labels.length)
                  Expanded(child: _PumpAttendantRow(label: labels[i + 1]))
                else
                  const Spacer(),
              ],
            ),
          ),
      ],
    );
  }
}

class _PumpAttendantRow extends StatelessWidget {
  const _PumpAttendantRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFECEFF8),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB8C0DC).withValues(alpha: 0.5),
            offset: const Offset(2, 2),
            blurRadius: 5,
          ),
          const BoxShadow(
            color: Colors.white,
            offset: Offset(-2, -2),
            blurRadius: 4,
          ),
        ],
      ),
      child: OneLineScaleText(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF4A5598),
        ),
      ),
    );
  }
}

// ─── Status badge ──────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.flagged});
  final String status;
  final bool flagged;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final String label;
    final IconData icon;

    if (flagged) {
      bg = const Color(0xFFFEF2F2);
      fg = const Color(0xFFB91C1C);
      label = 'Flagged';
      icon = Icons.flag_rounded;
    } else if (status == 'approved') {
      bg = const Color(0xFFE8F8EF);
      fg = const Color(0xFF0A7A4A);
      label = 'Approved';
      icon = Icons.verified_rounded;
    } else {
      bg = const Color(0xFFEEF2FF);
      fg = const Color(0xFF3D5AFE);
      label = _capitalize(status);
      icon = Icons.hourglass_top_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 5),
          Flexible(
            child: OneLineScaleText(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _capitalize(String v) =>
      v.isEmpty ? v : '${v[0].toUpperCase()}${v.substring(1)}';
}

// ─── Action button ─────────────────────────────────────────────────────────────
class _ActionBtn extends StatefulWidget {
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
    this.filled = false,
    this.loading = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;
  final bool filled;
  final bool loading;

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null || widget.loading;

    final Color bg;
    final Color fg;
    if (widget.filled) {
      bg = const Color(0xFF1A3A7A);
      fg = Colors.white;
    } else if (widget.danger) {
      bg = const Color(0xFFFEF2F2);
      fg = const Color(0xFFB91C1C);
    } else {
      bg = const Color(0xFFECEFF8);
      fg = const Color(0xFF1A2561);
    }

    return Expanded(
      child: GestureDetector(
        onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
        onTapUp:
            disabled
                ? null
                : (_) {
                  setState(() => _pressed = false);
                  widget.onTap!();
                },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          height: 40,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            boxShadow:
                widget.filled && !_pressed && !disabled
                    ? [
                      BoxShadow(
                        color: const Color(0xFF0D2460).withValues(alpha: 0.35),
                        offset: const Offset(0, 4),
                        blurRadius: 10,
                      ),
                    ]
                    : !widget.filled && !widget.danger && !_pressed && !disabled
                    ? [
                      BoxShadow(
                        color: const Color(0xFFB8C0DC).withValues(alpha: 0.65),
                        offset: const Offset(3, 3),
                        blurRadius: 8,
                      ),
                      const BoxShadow(
                        color: Colors.white,
                        offset: Offset(-2, -2),
                        blurRadius: 6,
                      ),
                    ]
                    : [],
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    widget.loading
                        ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              fg.withValues(alpha: 0.85),
                            ),
                          ),
                        )
                        : Icon(
                          widget.icon,
                          size: 14,
                          color: disabled ? fg.withValues(alpha: 0.4) : fg,
                        ),
                    const SizedBox(width: 5),
                    Text(
                      widget.label,
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: disabled ? fg.withValues(alpha: 0.4) : fg,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EntryManagementData {
  const _EntryManagementData({required this.entries, required this.dashboard});

  final List<ShiftEntryModel> entries;
  final SalesDashboardModel dashboard;
}

// ─── Dialog toggle tab ─────────────────────────────────────────────────────────
class _ToggleTab extends StatelessWidget {
  const _ToggleTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow:
                selected
                    ? [
                      BoxShadow(
                        color: const Color(0xFFB8C0DC).withValues(alpha: 0.5),
                        offset: const Offset(2, 2),
                        blurRadius: 6,
                      ),
                    ]
                    : [],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color:
                  selected ? const Color(0xFF1A2561) : const Color(0xFF8A93B8),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Date picker row ───────────────────────────────────────────────────────────
class _DatePickerRow extends StatelessWidget {
  const _DatePickerRow({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != 'Tap to choose';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFECEFF8),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFB8C0DC).withValues(alpha: 0.5),
              offset: const Offset(3, 3),
              blurRadius: 8,
            ),
            const BoxShadow(
              color: Colors.white,
              offset: Offset(-2, -2),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 16,
              color:
                  hasValue ? const Color(0xFF1A3A7A) : const Color(0xFF8A93B8),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8A93B8),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color:
                          hasValue
                              ? const Color(0xFF1A2561)
                              : const Color(0xFFAAB3D0),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF8A93B8),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Preview box ───────────────────────────────────────────────────────────────
class _PreviewBox extends StatelessWidget {
  const _PreviewBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A2561),
          fontSize: 13,
        ),
      ),
    );
  }
}
