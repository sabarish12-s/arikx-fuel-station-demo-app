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
import '../widgets/clay_widgets.dart';
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

const String _entryDetailNotEntered = 'Not entered';

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
              forceRefresh: forceRefresh,
            )
          : _managementService.fetchEntries(
              month: _filterMonth,
              forceRefresh: forceRefresh,
            ),
      _salesService.fetchDashboard(forceRefresh: forceRefresh),
    ]);

    var entries = results[0] as List<ShiftEntryModel>;

    // Client-side safety filter for date range mode
    if (_filterByDateRange) {
      final from = _filterFromDate != null
          ? DateTime.tryParse(_filterFromDate!)
          : null;
      final to = _filterToDate != null
          ? DateTime.tryParse(_filterToDate!)
          : null;
      entries = entries.where((e) {
        final d = DateTime.tryParse(e.date);
        if (d == null) {
          return true;
        }
        final day = DateTime(d.year, d.month, d.day);
        if (from != null &&
            day.isBefore(DateTime(from.year, from.month, from.day))) {
          return false;
        }
        if (to != null && day.isAfter(DateTime(to.year, to.month, to.day))) {
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
    final today = DateTime(now.year, now.month, now.day);

    // Local dialog state
    bool byRange = _filterByDateRange;
    final parts = _filterMonth.split('-');
    int selYear = int.tryParse(parts.firstOrNull ?? '') ?? now.year;
    int selMonth = int.tryParse(parts.length > 1 ? parts[1] : '') ?? now.month;
    DateTime? fromDt = _filterFromDate != null
        ? DateTime.tryParse(_filterFromDate!)
        : null;
    DateTime? toDt = _filterToDate != null
        ? DateTime.tryParse(_filterToDate!)
        : null;

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

    void applyQuickRange(StateSetter set, int dayCount) {
      set(() {
        byRange = true;
        fromDt = today.subtract(Duration(days: dayCount - 1));
        toDt = today;
      });
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
                      _DialogDropdownField<int>(
                        label: 'Year',
                        icon: Icons.event_note_rounded,
                        value: selYear,
                        items: years
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
                      const SizedBox(height: 12),
                      _DialogDropdownField<int>(
                        label: 'Month',
                        icon: Icons.calendar_month_rounded,
                        value: selMonth,
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
                    ] else ...[
                      // ── Date range mode ──────────────────────
                      _DatePickerRow(
                        label: 'Date Range',
                        value: formatDialogRange(),
                        onTap: () => pickRange(dialogContext, setDialogState),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _QuickRangeButton(
                              label: 'Last 7 Days',
                              selected:
                                  fromDt != null &&
                                  toDt != null &&
                                  fromDt!.isAtSameMomentAs(
                                    today.subtract(const Duration(days: 6)),
                                  ) &&
                                  toDt!.isAtSameMomentAs(today),
                              onTap: () => applyQuickRange(setDialogState, 7),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _QuickRangeButton(
                              label: 'Last 30 Days',
                              selected:
                                  fromDt != null &&
                                  toDt != null &&
                                  fromDt!.isAtSameMomentAs(
                                    today.subtract(const Duration(days: 29)),
                                  ) &&
                                  toDt!.isAtSameMomentAs(today),
                              onTap: () => applyQuickRange(setDialogState, 30),
                            ),
                          ),
                        ],
                      ),
                      if (fromDt != null && toDt != null)
                        _PreviewBox(
                          text:
                              '${formatDialogDate(fromDt)} – ${formatDialogDate(toDt)}',
                        ),
                    ],
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              actions: [
                SizedBox(
                  width: double.maxFinite,
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text('Cancel'),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: () {
                          if (byRange && (fromDt == null || toDt == null)) {
                            return;
                          }
                          Navigator.of(dialogContext).pop(true);
                        },
                        icon: const Icon(Icons.filter_alt_rounded),
                        label: const Text('Apply'),
                      ),
                    ],
                  ),
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
        _filterFromDate = fromDt != null
            ? '${fromDt!.year}-${fromDt!.month.toString().padLeft(2, '0')}-${fromDt!.day.toString().padLeft(2, '0')}'
            : null;
        _filterToDate = toDt != null
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
          builder: (_) => EntryWorkflowScreen(
            title: dashboard.selectedEntry == null
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
            initialDraft: dashboard.selectedEntry == null
                ? DailyEntryDraft(
                    date: date,
                    closingReadings: const {},
                    pumpAttendants: {
                      for (final pump in dashboard.station.pumps) pump.id: '',
                    },
                    pumpTesting: {
                      for (final pump in dashboard.station.pumps)
                        pump.id: const PumpTestingModel(petrol: 0, diesel: 0),
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
          builder: (_) => EntryWorkflowScreen(
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
      builder: (context) => AlertDialog(
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
      builder: (context) => AlertDialog(
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

  Future<void> _showEntryDetails(ShiftEntryModel entry) async {
    final detailFuture = _managementService.fetchEntryDetail(
      entry.id,
      forceRefresh: true,
    );
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ManagementEntryDetailSheet(future: detailFuture),
    );
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
            final approvedCount = allEntries
                .where((e) => e.status == 'approved')
                .length;
            final flaggedCount = allEntries
                .where((e) => e.flagged && e.status != 'approved')
                .length;
            final pendingCount = allEntries.length - approvedCount;

            final entries = _statusFilter == null
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
                      Container(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.1),
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
                            onTap: () => setState(
                              () => _statusFilter = _statusFilter == 'approved'
                                  ? null
                                  : 'approved',
                            ),
                          ),
                          const SizedBox(width: 8),
                          _HeroStat(
                            label: 'Pending',
                            value: '$pendingCount',
                            active: _statusFilter == 'pending',
                            onTap: () => setState(
                              () => _statusFilter = _statusFilter == 'pending'
                                  ? null
                                  : 'pending',
                            ),
                          ),
                          const SizedBox(width: 8),
                          _HeroStat(
                            label: 'Flagged',
                            value: '$flaggedCount',
                            active: _statusFilter == 'flagged',
                            onTap: () => setState(
                              () => _statusFilter = _statusFilter == 'flagged'
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
                  onSave: (density) =>
                      _saveDailyFuelRecord(data.dashboard, density),
                  onHistory: _openDailyFuelHistory,
                ),
                const SizedBox(height: 14),
                _ClayButton(
                  icon: Icons.add_rounded,
                  label: _submitting ? 'Opening...' : 'New Entry',
                  onTap: _submitting ? null : _openAdminEntryDialog,
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
                      activeAction: _activeEntryId == entry.id
                          ? _activeAction
                          : null,
                      onEdit: () => _editEntry(
                        entry,
                        data.dashboard.station,
                        data.dashboard.allowedEntryDate,
                      ),
                      onView: () => _showEntryDetails(entry),
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
      onTapUp: disabled
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
          boxShadow: _pressed || disabled
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
            color: active
                ? Colors.white.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: active
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
    required this.onView,
    required this.onDelete,
    required this.onApprove,
  });

  final ShiftEntryModel entry;
  final StationConfigModel station;
  final String submittedLabel;
  final bool submitting;
  final _EntryAction? activeAction;
  final VoidCallback onEdit;
  final VoidCallback onView;
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
    final attendantLabels = entry.pumpAttendants.entries
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
                    accent: diff >= 0
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
                icon: Icons.visibility_outlined,
                label: 'View',
                onTap: onView,
              ),
              const SizedBox(width: 8),
              _ActionBtn(
                icon: Icons.edit_rounded,
                label: 'Edit',
                onTap: submitting ? null : onEdit,
              ),
              const SizedBox(width: 8),
              _ActionBtn(
                icon: Icons.delete_outline_rounded,
                label: isDeleting
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
        onTapUp: disabled
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
            boxShadow: widget.filled && !_pressed && !disabled
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

class _ManagementEntryDetailSheet extends StatelessWidget {
  const _ManagementEntryDetailSheet({required this.future});

  final Future<ShiftEntryModel> future;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Container(
        decoration: const BoxDecoration(
          color: kClayBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: kClaySub.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Entry Details',
                        style: TextStyle(
                          color: kClayPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: kClayPrimary,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<ShiftEntryModel>(
                  future: future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              userFacingErrorMessage(snapshot.error),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: kClayPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 42,
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Close'),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final entry = snapshot.data!;
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      children: [
                        _ManagementDetailSection(
                          title: 'Header',
                          child: Column(
                            children: [
                              _ManagementEntryHeaderHero(entry: entry),
                              const SizedBox(height: 12),
                              _ManagementHeaderInfoGrid(
                                items: [
                                  _ManagementHeaderInfoItem(
                                    label: 'Submitted by',
                                    value: _managementDisplayOrPlaceholder(
                                      entry.submittedByName,
                                    ),
                                  ),
                                  _ManagementHeaderInfoItem(
                                    label: 'Submitted at',
                                    value:
                                        _managementFormatDateTimeOrPlaceholder(
                                          entry.submittedAt,
                                        ),
                                  ),
                                  _ManagementHeaderInfoItem(
                                    label: 'Updated at',
                                    value:
                                        _managementFormatDateTimeOrPlaceholder(
                                          entry.updatedAt,
                                        ),
                                  ),
                                  _ManagementHeaderInfoItem(
                                    label: 'Approved at',
                                    value:
                                        _managementFormatDateTimeOrPlaceholder(
                                          entry.approvedAt,
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _ManagementDetailSection(
                          title: 'Readings',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _ManagementFuelBreakdownTile(
                                title: 'Opening total',
                                totals: entry.totals.opening,
                              ),
                              const SizedBox(height: 10),
                              _ManagementFuelBreakdownTile(
                                title: 'Closing total',
                                totals: entry.totals.closing,
                              ),
                              const SizedBox(height: 10),
                              _ManagementFuelBreakdownTile(
                                title: 'Sold total',
                                totals: entry.totals.sold,
                              ),
                              const SizedBox(height: 10),
                              _ManagementFuelBreakdownTile(
                                title: 'Inventory total',
                                totals: entry.inventoryTotals,
                              ),
                              const SizedBox(height: 14),
                              ..._managementBuildPumpReadingCards(entry),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _ManagementDetailSection(
                          title: 'Pump Details',
                          child: Column(
                            children: _managementBuildPumpDetailCards(entry),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _ManagementDetailSection(
                          title: 'Settlement',
                          child: Column(
                            children: [
                              _ManagementMoneyBreakdownTile(
                                title: 'Payments',
                                values: {
                                  'Cash': entry.paymentBreakdown.cash,
                                  'HP Pay': entry.paymentBreakdown.check,
                                  'UPI': entry.paymentBreakdown.upi,
                                },
                              ),
                              const SizedBox(height: 10),
                              _ManagementDetailRow(
                                label: 'Payment total',
                                value: formatCurrency(entry.paymentTotal),
                              ),
                              _ManagementDetailRow(
                                label: 'Recorded sales',
                                value: formatCurrency(entry.revenue),
                              ),
                              _ManagementDetailRow(
                                label: 'Computed revenue',
                                value: formatCurrency(entry.computedRevenue),
                              ),
                              _ManagementDetailRow(
                                label: 'Sales settlement',
                                value: formatCurrency(
                                  entry.salesSettlementTotal,
                                ),
                              ),
                              _ManagementDetailRow(
                                label: 'Mismatch amount',
                                value: formatCurrency(entry.mismatchAmount),
                              ),
                              _ManagementDetailRow(
                                label: 'Mismatch reason',
                                value: _managementDisplayOrPlaceholder(
                                  entry.mismatchReason,
                                ),
                                isLast: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _ManagementDetailSection(
                          title: 'Credit',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _ManagementSubSectionLabel('Issued'),
                              const SizedBox(height: 8),
                              ..._managementBuildCreditEntryCards(
                                entry.creditEntries,
                              ),
                              const SizedBox(height: 14),
                              const _ManagementSubSectionLabel('Collected'),
                              const SizedBox(height: 8),
                              ..._managementBuildCreditCollectionCards(
                                entry.creditCollections,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _ManagementDetailSection(
                          title: 'Totals',
                          child: Column(
                            children: [
                              _ManagementFuelBreakdownTile(
                                title: 'Opening',
                                totals: entry.totals.opening,
                              ),
                              const SizedBox(height: 10),
                              _ManagementFuelBreakdownTile(
                                title: 'Closing',
                                totals: entry.totals.closing,
                              ),
                              const SizedBox(height: 10),
                              _ManagementFuelBreakdownTile(
                                title: 'Sold',
                                totals: entry.totals.sold,
                              ),
                              const SizedBox(height: 10),
                              _ManagementFuelBreakdownTile(
                                title: 'Inventory',
                                totals: entry.inventoryTotals,
                              ),
                              const SizedBox(height: 10),
                              _ManagementDetailRow(
                                label: 'Credit collection total',
                                value: formatCurrency(
                                  entry.creditCollectionTotal,
                                ),
                              ),
                              _ManagementDetailRow(
                                label: 'Profit',
                                value: formatCurrency(entry.profit),
                                isLast: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _ManagementDetailSection(
                          title: 'Notes',
                          child: Column(
                            children: [
                              _ManagementDetailRow(
                                label: 'Variance note',
                                value: _managementDisplayOrPlaceholder(
                                  entry.varianceNote,
                                ),
                              ),
                              _ManagementDetailRow(
                                label: 'Mismatch reason',
                                value: _managementDisplayOrPlaceholder(
                                  entry.mismatchReason,
                                ),
                                isLast: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<Widget> _managementBuildPumpReadingCards(ShiftEntryModel entry) {
  final pumpIds = _managementPumpIds(entry);
  if (pumpIds.isEmpty) {
    return const [_ManagementEmptySubCard(message: _entryDetailNotEntered)];
  }
  return [
    for (int index = 0; index < pumpIds.length; index++) ...[
      _ManagementSubCard(
        title: formatPumpLabel(pumpIds[index]),
        child: Column(
          children: [
            _ManagementFuelBreakdownTile(
              title: 'Opening',
              totals: entry.openingReadings[pumpIds[index]],
            ),
            const SizedBox(height: 10),
            _ManagementFuelBreakdownTile(
              title: 'Closing',
              totals: entry.closingReadings[pumpIds[index]],
            ),
            const SizedBox(height: 10),
            _ManagementFuelBreakdownTile(
              title: 'Sold',
              totals: entry.soldByPump[pumpIds[index]],
            ),
          ],
        ),
      ),
      if (index != pumpIds.length - 1) const SizedBox(height: 10),
    ],
  ];
}

List<Widget> _managementBuildPumpDetailCards(ShiftEntryModel entry) {
  final pumpIds = _managementPumpIds(entry);
  if (pumpIds.isEmpty) {
    return const [_ManagementEmptySubCard(message: _entryDetailNotEntered)];
  }
  return [
    for (int index = 0; index < pumpIds.length; index++) ...[
      _ManagementSubCard(
        title: formatPumpLabel(pumpIds[index]),
        child: Column(
          children: [
            _ManagementDetailRow(
              label: 'Attendant',
              value: _managementDisplayOrPlaceholder(
                entry.pumpAttendants[pumpIds[index]] ?? '',
              ),
            ),
            _ManagementDetailRow(
              label: 'Testing',
              value: _managementFormatTesting(entry.pumpTesting[pumpIds[index]]),
            ),
            if (entry.pumpPayments.containsKey(pumpIds[index])) ...[
              _ManagementMoneyBreakdownTile(
                title: 'Pump payments',
                values: {
                  'Cash': entry.pumpPayments[pumpIds[index]]!.cash,
                  'HP Pay': entry.pumpPayments[pumpIds[index]]!.check,
                  'UPI': entry.pumpPayments[pumpIds[index]]!.upi,
                  'Credit': entry.pumpPayments[pumpIds[index]]!.credit,
                  'Total': entry.pumpPayments[pumpIds[index]]!.total,
                },
              ),
              const SizedBox(height: 10),
            ] else ...[
              const _ManagementDetailRow(
                label: 'Pump payments',
                value: _entryDetailNotEntered,
              ),
            ],
            _ManagementDetailRow(
              label: 'Pump collection',
              value: entry.pumpCollections.containsKey(pumpIds[index])
                  ? formatCurrency(entry.pumpCollections[pumpIds[index]] ?? 0)
                  : _entryDetailNotEntered,
              isLast: true,
            ),
          ],
        ),
      ),
      if (index != pumpIds.length - 1) const SizedBox(height: 10),
    ],
  ];
}

List<Widget> _managementBuildCreditEntryCards(List<CreditEntryModel> entries) {
  if (entries.isEmpty) {
    return const [_ManagementEmptySubCard(message: _entryDetailNotEntered)];
  }
  return [
    for (int index = 0; index < entries.length; index++) ...[
      _ManagementSubCard(
        title: entries[index].name.trim().isEmpty
            ? 'Credit entry ${index + 1}'
            : entries[index].name.trim(),
        child: Column(
          children: [
            _ManagementDetailRow(
              label: 'Pump',
              value: entries[index].pumpId.trim().isEmpty
                  ? _entryDetailNotEntered
                  : formatPumpLabel(entries[index].pumpId),
            ),
            _ManagementDetailRow(
              label: 'Amount',
              value: formatCurrency(entries[index].amount),
              isLast: true,
            ),
          ],
        ),
      ),
      if (index != entries.length - 1) const SizedBox(height: 10),
    ],
  ];
}

List<Widget> _managementBuildCreditCollectionCards(
  List<CreditCollectionModel> collections,
) {
  if (collections.isEmpty) {
    return const [_ManagementEmptySubCard(message: _entryDetailNotEntered)];
  }
  return [
    for (int index = 0; index < collections.length; index++) ...[
      _ManagementSubCard(
        title: collections[index].name.trim().isEmpty
            ? 'Collection ${index + 1}'
            : collections[index].name.trim(),
        child: Column(
          children: [
            _ManagementDetailRow(
              label: 'Amount',
              value: formatCurrency(collections[index].amount),
            ),
            _ManagementDetailRow(
              label: 'Date',
              value: _managementDisplayOrPlaceholder(
                collections[index].date.isEmpty
                    ? ''
                    : formatDateLabel(collections[index].date),
              ),
            ),
            _ManagementDetailRow(
              label: 'Payment mode',
              value: _managementDisplayOrPlaceholder(
                collections[index].paymentMode,
              ),
            ),
            _ManagementDetailRow(
              label: 'Note',
              value: _managementDisplayOrPlaceholder(collections[index].note),
              isLast: true,
            ),
          ],
        ),
      ),
      if (index != collections.length - 1) const SizedBox(height: 10),
    ],
  ];
}

class _ManagementDetailSection extends StatelessWidget {
  const _ManagementDetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: kClayPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ManagementEntryHeaderHero extends StatelessWidget {
  const _ManagementEntryHeaderHero({required this.entry});

  final ShiftEntryModel entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FD),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E9F7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatDateLabel(entry.date),
            style: const TextStyle(
              color: kClayPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ManagementHeaderBadge(
                label: formatShiftLabel(entry.shift),
                filled: false,
              ),
              _ManagementHeaderBadge(
                label: _managementStatusLabel(entry),
                accent: _managementStatusAccent(entry),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ManagementHeaderInfoItem {
  const _ManagementHeaderInfoItem({required this.label, required this.value});

  final String label;
  final String value;
}

class _ManagementHeaderInfoGrid extends StatelessWidget {
  const _ManagementHeaderInfoGrid({required this.items});

  final List<_ManagementHeaderInfoItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final item in items)
              SizedBox(
                width: itemWidth,
                child: _ManagementHeaderInfoCard(
                  label: item.label,
                  value: item.value,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ManagementHeaderInfoCard extends StatelessWidget {
  const _ManagementHeaderInfoCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E9F7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: kClaySub,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: kClayPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagementHeaderBadge extends StatelessWidget {
  const _ManagementHeaderBadge({
    required this.label,
    this.accent = kClayPrimary,
    this.filled = true,
  });

  final String label;
  final Color accent;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? accent.withValues(alpha: 0.12) : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ManagementSubSectionLabel extends StatelessWidget {
  const _ManagementSubSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: kClaySub,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _ManagementDetailRow extends StatelessWidget {
  const _ManagementDetailRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(
                color: kClaySub,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: kClayPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagementFuelBreakdownTile extends StatelessWidget {
  const _ManagementFuelBreakdownTile({
    required this.title,
    required this.totals,
  });

  final String title;
  final Object? totals;

  @override
  Widget build(BuildContext context) {
    if (totals == null) {
      return _ManagementDataBlock(
        title: title,
        child: const Text(
          _entryDetailNotEntered,
          style: TextStyle(
            color: kClaySub,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return _ManagementDataBlock(
      title: title,
      child: Column(
        children: [
          _ManagementMiniValueRow(
            label: 'Petrol',
            value: formatLiters(_managementFuelPetrol(totals)),
          ),
          const SizedBox(height: 8),
          _ManagementMiniValueRow(
            label: 'Diesel',
            value: formatLiters(_managementFuelDiesel(totals)),
          ),
          const SizedBox(height: 8),
          _ManagementMiniValueRow(
            label: '2T Oil',
            value: formatLiters(_managementFuelTwoT(totals)),
          ),
        ],
      ),
    );
  }
}

class _ManagementMoneyBreakdownTile extends StatelessWidget {
  const _ManagementMoneyBreakdownTile({
    required this.title,
    required this.values,
  });

  final String title;
  final Map<String, double> values;

  @override
  Widget build(BuildContext context) {
    return _ManagementDataBlock(
      title: title,
      child: Column(
        children: [
          for (int index = 0; index < values.entries.length; index++) ...[
            _ManagementMiniValueRow(
              label: values.entries.elementAt(index).key,
              value: formatCurrency(values.entries.elementAt(index).value),
            ),
            if (index != values.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _ManagementDataBlock extends StatelessWidget {
  const _ManagementDataBlock({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E9F7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: kClayPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ManagementMiniValueRow extends StatelessWidget {
  const _ManagementMiniValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: kClayPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _ManagementSubCard extends StatelessWidget {
  const _ManagementSubCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FD),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E9F7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: kClayPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ManagementEmptySubCard extends StatelessWidget {
  const _ManagementEmptySubCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _ManagementSubCard(
      title: 'Details',
      child: Text(
        message,
        style: const TextStyle(
          color: kClaySub,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _managementStatusLabel(ShiftEntryModel entry) {
  if (entry.flagged) {
    return 'Flagged';
  }
  if (entry.status.trim().isEmpty) {
    return _entryDetailNotEntered;
  }
  return _managementShiftCase(entry.status);
}

Color _managementStatusAccent(ShiftEntryModel entry) {
  if (entry.flagged) {
    return const Color(0xFFB91C1C);
  }
  if (entry.status.trim().toLowerCase() == 'approved') {
    return const Color(0xFF2AA878);
  }
  return kClayPrimary;
}

String _managementDisplayOrPlaceholder(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? _entryDetailNotEntered : trimmed;
}

String _managementFormatDateTimeOrPlaceholder(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? _entryDetailNotEntered : formatDateTimeLabel(trimmed);
}

String _managementFormatTesting(PumpTestingModel? testing) {
  if (testing == null || !testing.enabled) {
    return _entryDetailNotEntered;
  }
  final addToInventory = testing.addToInventory ? 'Yes' : 'No';
  return 'Petrol ${formatLiters(testing.petrol)}, Diesel ${formatLiters(testing.diesel)}, Add to inventory $addToInventory';
}

List<String> _managementPumpIds(ShiftEntryModel entry) {
  final ids = <String>{
    ...entry.openingReadings.keys,
    ...entry.closingReadings.keys,
    ...entry.soldByPump.keys,
    ...entry.pumpAttendants.keys,
    ...entry.pumpTesting.keys,
    ...entry.pumpPayments.keys,
    ...entry.pumpCollections.keys,
  }.toList()
    ..sort();
  return ids;
}

double _managementFuelPetrol(Object? totals) {
  if (totals is FuelTotals) {
    return totals.petrol;
  }
  if (totals is PumpReadings) {
    return totals.petrol;
  }
  return 0;
}

double _managementFuelDiesel(Object? totals) {
  if (totals is FuelTotals) {
    return totals.diesel;
  }
  if (totals is PumpReadings) {
    return totals.diesel;
  }
  return 0;
}

double _managementFuelTwoT(Object? totals) {
  if (totals is FuelTotals) {
    return totals.twoT;
  }
  if (totals is PumpReadings) {
    return totals.twoT;
  }
  return 0;
}

String _managementShiftCase(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return _entryDetailNotEntered;
  }
  return trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
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
            boxShadow: selected
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
              color: selected
                  ? const Color(0xFF1A2561)
                  : const Color(0xFF8A93B8),
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
              color: hasValue
                  ? const Color(0xFF1A3A7A)
                  : const Color(0xFF8A93B8),
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
                      color: hasValue
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
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _DialogDropdownField<T> extends StatelessWidget {
  const _DialogDropdownField({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: DropdownButtonFormField<T>(
        initialValue: value,
        items: items,
        onChanged: onChanged,
        isExpanded: true,
        borderRadius: BorderRadius.circular(16),
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: Color(0xFF8A93B8),
        ),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF1A3A7A), size: 18),
          filled: true,
          fillColor: Colors.transparent,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          labelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF8A93B8),
          ),
        ),
      ),
    );
  }
}

class _QuickRangeButton extends StatelessWidget {
  const _QuickRangeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1A3A7A) : const Color(0xFFECEFF8),
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0D2460).withValues(alpha: 0.22),
                    offset: const Offset(0, 6),
                    blurRadius: 14,
                  ),
                ]
              : [
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
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : const Color(0xFF1A2561),
            ),
          ),
        ),
      ),
    );
  }
}
