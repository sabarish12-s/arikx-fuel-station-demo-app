import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/management_service.dart';
import '../services/sales_service.dart';
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
                priceSnapshot:
                    dashboard.selectedEntry?.priceSnapshot ??
                    dashboard.priceSnapshot,
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
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder:
            (_) => EntryWorkflowScreen(
              title: 'Edit Daily Entry',
              station: station,
              openingReadings: entry.openingReadings,
              priceSnapshot: entry.priceSnapshot,
              initialDraft: _draftFromEntry(entry),
              onSubmit: (draft, mismatchReason) async {
                await _managementService.updateEntry(
                  entryId: entry.id,
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
            final selectedMonthLabel = _formatMonthFilter(
              _monthController.text,
            );

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
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
                      Text(
                        '${data.dashboard.station.name} - ${formatDateLabel(data.dashboard.date)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Admins and sales staff now work from the same one-entry-per-day sales record.',
                        style: TextStyle(color: Colors.white70, height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      GridView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              mainAxisExtent: 84,
                            ),
                        children: [
                          _DashboardChip(
                            label: 'Revenue today',
                            value: formatCurrency(data.dashboard.revenue),
                          ),
                          _DashboardChip(
                            label: 'Collected today',
                            value: formatCurrency(data.dashboard.paymentTotal),
                          ),
                          _DashboardChip(
                            label: 'Entries today',
                            value: '${data.dashboard.entriesCompleted}/1',
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
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Filtered entries',
                        value: '${entries.length}',
                        subtitle: _monthController.text.trim(),
                        accent: const Color(0xFF1E5CBA),
                        icon: Icons.filter_alt_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Approved',
                        value: '$approvedCount',
                        subtitle: 'Ready for reports',
                        accent: const Color(0xFF0F9D58),
                        icon: Icons.verified_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quick Admin Daily Entry',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF293340),
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Choose a date, then fill the full daily entry in a popup.',
                              style: TextStyle(color: Color(0xFF55606E)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _submitting ? null : _openAdminEntryDialog,
                        icon: const Icon(Icons.add_task_rounded),
                        label: Text(_submitting ? 'Opening...' : 'Open'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
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
                        'Entry Filter',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF293340),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Open the popup to choose a month and refresh the list.',
                        style: TextStyle(color: Color(0xFF55606E)),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FF),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_month_rounded,
                              color: Color(0xFF1E5CBA),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Current period',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF55606E),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    selectedMonthLabel,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF293340),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilledButton.icon(
                              onPressed: _openMonthFilterDialog,
                              icon: const Icon(Icons.filter_alt_rounded),
                              label: const Text('Filter'),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                                  formatDateLabel(entry.date),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              Chip(label: Text(entry.status)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 14,
                            runSpacing: 8,
                            children: [
                              Text(
                                'Petrol ${formatLiters(entry.totals.sold.petrol)}',
                              ),
                              Text(
                                'Diesel ${formatLiters(entry.totals.sold.diesel)}',
                              ),
                              if (entry.totals.sold.twoT > 0)
                                Text(
                                  '2T Oil ${formatLiters(entry.totals.sold.twoT)}',
                                ),
                              Text('Revenue ${formatCurrency(entry.revenue)}'),
                              Text(
                                'Collected ${formatCurrency(entry.paymentTotal)}',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Submitted by $submittedLabel',
                            style: const TextStyle(color: Color(0xFF55606E)),
                          ),
                          if (entry.pumpAttendants.values.any(
                            (name) => name.isNotEmpty,
                          ))
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                entry.pumpAttendants.entries
                                    .where((item) => item.value.isNotEmpty)
                                    .map(
                                      (item) =>
                                          '${formatPumpLabel(item.key)}: ${item.value}',
                                    )
                                    .join('  •  '),
                                style: const TextStyle(
                                  color: Color(0xFF55606E),
                                ),
                              ),
                            ),
                          if (entry.varianceNote.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                entry.varianceNote,
                                style: const TextStyle(
                                  color: Color(0xFFB91C1C),
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              OutlinedButton(
                                onPressed:
                                    _submitting
                                        ? null
                                        : () => _editEntry(
                                          entry,
                                          data.dashboard.station,
                                        ),
                                child: const Text('Edit Entry'),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFB91C1C),
                                ),
                                onPressed:
                                    _submitting
                                        ? null
                                        : () => _deleteEntry(entry),
                                child: Text(
                                  entry.status == 'approved'
                                      ? 'Override Delete'
                                      : 'Delete Entry',
                                ),
                              ),
                              const SizedBox(width: 10),
                              if (entry.status != 'approved')
                                FilledButton(
                                  onPressed:
                                      _submitting
                                          ? null
                                          : () => _approveEntry(entry),
                                  child: const Text('Approve'),
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

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accent,
    required this.icon,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF55606E),
                  ),
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF55606E)),
          ),
        ],
      ),
    );
  }
}
