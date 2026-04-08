import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/management_service.dart';
import '../services/sales_service.dart';
import '../utils/fuel_prices.dart';
import '../utils/formatters.dart';
import 'entry_workflow_screen.dart';

class EntryManagementScreen extends StatefulWidget {
  const EntryManagementScreen({super.key});

  @override
  State<EntryManagementScreen> createState() => _EntryManagementScreenState();
}

class _EntryManagementScreenState extends State<EntryManagementScreen> {
  final ManagementService _managementService = ManagementService();
  final SalesService _salesService = SalesService();
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
  final TextEditingController _monthController = TextEditingController(
    text: currentMonthKey(),
  );
  late Future<_EntryManagementData> _future;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  @override
  void dispose() {
    _monthController.dispose();
    super.dispose();
  }

  Future<_EntryManagementData> _loadData() async {
    final results = await Future.wait([
      _managementService.fetchEntries(month: _monthController.text.trim()),
      _salesService.fetchDashboard(),
    ]);
    return _EntryManagementData(
      entries: results[0] as List<ShiftEntryModel>,
      dashboard: results[1] as SalesDashboardModel,
    );
  }

  Future<void> _reload() async {
    setState(() {
      _future = _loadData();
    });
    await _future;
  }

  String _formatMonthFilter(String raw) {
    final parts = raw.trim().split('-');
    if (parts.length != 2) {
      return raw.trim().isEmpty ? 'No month selected' : raw.trim();
    }
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null || month < 1 || month > 12) {
      return raw.trim();
    }
    return '${_monthNames[month - 1]} $year';
  }

  Future<void> _openMonthFilterDialog() async {
    final now = DateTime.now();
    final parts = _monthController.text.trim().split('-');
    int selectedYear = int.tryParse(parts.firstOrNull ?? '') ?? now.year;
    int selectedMonth =
        int.tryParse(parts.length > 1 ? parts[1] : '') ?? now.month;

    final applied = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final years = List<int>.generate(
              now.year - 2024 + 1,
              (index) => now.year - index,
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
                    const Text(
                      'Choose the month you want to view.',
                      style: TextStyle(color: Color(0xFF55606E)),
                    ),
                    const SizedBox(height: 18),
                    DropdownButtonFormField<int>(
                      initialValue: selectedMonth,
                      decoration: const InputDecoration(
                        labelText: 'Month',
                        filled: true,
                      ),
                      items: List.generate(
                        _monthNames.length,
                        (index) => DropdownMenuItem<int>(
                          value: index + 1,
                          child: Text(_monthNames[index]),
                        ),
                      ),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setDialogState(() {
                          selectedMonth = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: selectedYear,
                      decoration: const InputDecoration(
                        labelText: 'Year',
                        filled: true,
                      ),
                      items:
                          years
                              .map(
                                (year) => DropdownMenuItem<int>(
                                  value: year,
                                  child: Text('$year'),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setDialogState(() {
                          selectedYear = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Selected period: ${_monthNames[selectedMonth - 1]} $selectedYear',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF293340),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    final current = currentMonthKey();
                    final currentParts = current.split('-');
                    final currentYear =
                        int.tryParse(currentParts[0]) ?? now.year;
                    final currentMonth =
                        int.tryParse(currentParts[1]) ?? now.month;
                    setDialogState(() {
                      selectedYear = currentYear;
                      selectedMonth = currentMonth;
                    });
                  },
                  child: const Text('This Month'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  icon: const Icon(Icons.filter_alt_rounded),
                  label: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    if (applied != true) {
      return;
    }

    final month = selectedMonth.toString().padLeft(2, '0');
    _monthController.text = '$selectedYear-$month';
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

  Future<String?> _pickEntryDate({String? initialDate}) async {
    final initial =
        DateTime.tryParse(initialDate ?? '') ??
        DateTime.tryParse(currentMonthKey()) ??
        DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      helpText: 'Select entry date',
    );
    if (picked == null) {
      return null;
    }
    final month = picked.month.toString().padLeft(2, '0');
    final day = picked.day.toString().padLeft(2, '0');
    return '${picked.year}-$month-$day';
  }

  Future<void> _openAdminEntryDialog([String? preselectedDate]) async {
    final date = preselectedDate ?? await _pickEntryDate();
    if (date == null) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final dashboard = await _salesService.fetchDashboardForDate(date: date);
      if (!mounted) {
        return;
      }

      final created = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder:
              (_) => EntryWorkflowScreen(
                title:
                    dashboard.selectedEntry == null
                        ? 'Daily Admin Entry'
                        : 'Edit Daily Entry',
                station: dashboard.station,
                openingReadings:
                    dashboard.selectedEntry?.openingReadings ??
                    dashboard.openingReadings,
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
      if (created != true) {
        return;
      }
      await _reload();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFB91C1C),
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _editEntry(
    ShiftEntryModel entry,
    StationConfigModel station,
  ) async {
    setState(() {
      _submitting = true;
    });
    try {
      final detailedEntry = await _managementService.fetchEntryDetail(entry.id);
      if (!mounted) {
        return;
      }

      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder:
              (_) => EntryWorkflowScreen(
                title: 'Edit Daily Entry',
                station: station,
                openingReadings: detailedEntry.openingReadings,
                priceSnapshot: detailedEntry.priceSnapshot,
                initialDraft: _draftFromEntry(detailedEntry),
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

      if (saved != true) {
        return;
      }
      await _reload();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFB91C1C),
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _approveEntry(ShiftEntryModel entry) async {
    await _managementService.approveEntry(entry.id);
    await _reload();
  }

  Future<bool> _confirmDeleteEntry(ShiftEntryModel entry) async {
    final isApproved = entry.status == 'approved';
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
    if (!confirmed) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      await _managementService.deleteEntry(entry.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            entry.status == 'approved'
                ? 'Approved entry deleted and override applied.'
                : 'Entry deleted.',
          ),
        ),
      );
      await _reload();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFB91C1C),
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
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
                padding: const EdgeInsets.all(24),
                children: [
                  Center(
                    child: Text(
                      snapshot.error.toString().replaceFirst('Exception: ', ''),
                    ),
                  ),
                ],
              );
            }

            final data = snapshot.data!;
            final entries = data.entries;
            final approvedCount =
                entries.where((entry) => entry.status == 'approved').length;
            final flaggedCount =
                entries
                    .where(
                      (entry) => entry.flagged && entry.status != 'approved',
                    )
                    .length;
            final pendingCount = entries.length - approvedCount;
            final selectedMonthLabel = _formatMonthFilter(
              _monthController.text,
            );

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E5CBA), Color(0xFF0F3D91)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'ENTRY CONTROL',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.9,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Entries Overview',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${data.dashboard.station.name}  |  $selectedMonthLabel',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _DashboardChip(
                            label: 'Filtered',
                            value: '${entries.length}',
                          ),
                          _DashboardChip(
                            label: 'Approved',
                            value: '$approvedCount',
                          ),
                          _DashboardChip(
                            label: 'Pending',
                            value: '$pendingCount',
                          ),
                          _DashboardChip(
                            label: 'Flagged',
                            value: '$flaggedCount',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked = constraints.maxWidth < 640;
                      final quickEntryPanel = Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.add_task_rounded,
                                  color: Color(0xFF1E5CBA),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Quick Daily Entry',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF293340),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Open the full daily entry workflow for any date.',
                              style: TextStyle(
                                color: Color(0xFF55606E),
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed:
                                  _submitting ? null : _openAdminEntryDialog,
                              icon: const Icon(Icons.open_in_new_rounded),
                              label: Text(
                                _submitting ? 'Opening...' : 'Open Entry',
                              ),
                            ),
                          ],
                        ),
                      );
                      final filterPanel = Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.filter_alt_rounded,
                                  color: Color(0xFF1E5CBA),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Entry Filter',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF293340),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Choose the month you want to review or manage.',
                              style: TextStyle(
                                color: Color(0xFF55606E),
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              selectedMonthLabel,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF293340),
                              ),
                            ),
                            const SizedBox(height: 14),
                            FilledButton.icon(
                              onPressed: _openMonthFilterDialog,
                              icon: const Icon(Icons.calendar_month_rounded),
                              label: const Text('Change Period'),
                            ),
                          ],
                        ),
                      );
                      if (stacked) {
                        return Column(
                          children: [
                            quickEntryPanel,
                            const SizedBox(height: 12),
                            filterPanel,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: quickEntryPanel),
                          const SizedBox(width: 12),
                          Expanded(child: filterPanel),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
                if (entries.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Center(
                      child: Text('No entries found for this period.'),
                    ),
                  )
                else
                  ...entries.reversed.map((entry) {
                    final submittedLabel =
                        entry.submittedByName.trim().isNotEmpty
                            ? entry.submittedByName.trim()
                            : entry.submittedBy.trim();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x120F172A),
                            blurRadius: 18,
                            offset: Offset(0, 8),
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
                                  formatDateLabel(entry.date),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                              _EntryStatusBadge(
                                status: entry.status,
                                flagged: entry.flagged,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Submitted by $submittedLabel',
                            style: const TextStyle(
                              color: Color(0xFF55606E),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _EntryMetricChip(
                                label: 'Petrol',
                                value: formatLiters(entry.totals.sold.petrol),
                                accent: const Color(0xFF1E5CBA),
                              ),
                              _EntryMetricChip(
                                label: 'Diesel',
                                value: formatLiters(entry.totals.sold.diesel),
                                accent: const Color(0xFF0F766E),
                              ),
                              if (entry.totals.sold.twoT > 0)
                                _EntryMetricChip(
                                  label: '2T Oil',
                                  value: formatLiters(entry.totals.sold.twoT),
                                  accent: const Color(0xFFB45309),
                                ),
                              _EntryMetricChip(
                                label: 'Revenue',
                                value: formatCurrency(entry.revenue),
                                accent: const Color(0xFF7C3AED),
                              ),
                              _EntryMetricChip(
                                label: 'Collected',
                                value: formatCurrency(entry.paymentTotal),
                                accent: const Color(0xFF059669),
                              ),
                            ],
                          ),
                          if (entry.pumpAttendants.values.any(
                            (name) => name.isNotEmpty,
                          ))
                            Container(
                              margin: const EdgeInsets.only(top: 14),
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F9FF),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Pump attendants',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF293340),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    entry.pumpAttendants.entries
                                        .where((item) => item.value.isNotEmpty)
                                        .map(
                                          (item) =>
                                              '${formatPumpLabel(item.key)}: ${item.value}',
                                        )
                                        .join(' | '),
                                    style: const TextStyle(
                                      color: Color(0xFF55606E),
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (entry.varianceNote.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 14),
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(
                                    0xFFB91C1C,
                                  ).withValues(alpha: 0.12),
                                ),
                              ),
                              child: Text(
                                entry.varianceNote,
                                style: const TextStyle(
                                  color: Color(0xFFB91C1C),
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              OutlinedButton.icon(
                                onPressed:
                                    _submitting
                                        ? null
                                        : () => _editEntry(
                                          entry,
                                          data.dashboard.station,
                                        ),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Edit Entry'),
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFB91C1C),
                                ),
                                onPressed:
                                    _submitting
                                        ? null
                                        : () => _deleteEntry(entry),
                                icon: const Icon(Icons.delete_outline_rounded),
                                label: Text(
                                  entry.status == 'approved'
                                      ? 'Override Delete'
                                      : 'Delete Entry',
                                ),
                              ),
                              if (entry.status != 'approved')
                                FilledButton.icon(
                                  onPressed:
                                      _submitting
                                          ? null
                                          : () => _approveEntry(entry),
                                  icon: const Icon(Icons.verified_rounded),
                                  label: const Text('Approve'),
                                ),
                            ],
                          ),
                        ],
                      ),
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

class _EntryManagementData {
  const _EntryManagementData({required this.entries, required this.dashboard});

  final List<ShiftEntryModel> entries;
  final SalesDashboardModel dashboard;
}

class _DashboardChip extends StatelessWidget {
  const _DashboardChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 116,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryStatusBadge extends StatelessWidget {
  const _EntryStatusBadge({required this.status, required this.flagged});

  final String status;
  final bool flagged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color:
            flagged
                ? const Color(0xFFFEF2F2)
                : status == 'approved'
                ? const Color(0xFFE7F8EE)
                : const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        flagged ? 'Flagged' : _capitalize(status),
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color:
              flagged
                  ? const Color(0xFFB91C1C)
                  : status == 'approved'
                  ? const Color(0xFF047857)
                  : const Color(0xFF1E5CBA),
        ),
      ),
    );
  }

  String _capitalize(String value) {
    if (value.isEmpty) {
      return value;
    }
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }
}

class _EntryMetricChip extends StatelessWidget {
  const _EntryMetricChip({
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
      constraints: const BoxConstraints(minWidth: 126),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF55606E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w800, color: accent),
          ),
        ],
      ),
    );
  }
}
