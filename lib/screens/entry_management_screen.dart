import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/management_service.dart';
import '../services/sales_service.dart';
import '../utils/formatters.dart';
import '../widgets/daily_entry_dialogs.dart';

class EntryManagementScreen extends StatefulWidget {
  const EntryManagementScreen({super.key});

  @override
  State<EntryManagementScreen> createState() => _EntryManagementScreenState();
}

class _EntryManagementScreenState extends State<EntryManagementScreen> {
  final ManagementService _managementService = ManagementService();
  final SalesService _salesService = SalesService();
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
      mismatchReason: entry.mismatchReason,
    );
  }

  Future<String?> _pickEntryDate({String? initialDate}) async {
    final initial =
        DateTime.tryParse(initialDate ?? '') ?? DateTime.tryParse(currentMonthKey()) ?? DateTime.now();
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

      final draft = await showDailyEntryEditorDialog(
        context: context,
        station: dashboard.station,
        title: 'Daily Admin Entry',
        initialDate: date,
        openingReadings: dashboard.openingReadings,
        initialDraft: dashboard.selectedEntry == null
            ? null
            : _draftFromEntry(dashboard.selectedEntry!),
        allowDateEdit: false,
      );
      if (draft == null) {
        return;
      }

      await _previewAndSubmitAdminEntry(
        draft,
        existingEntry: dashboard.selectedEntry,
      );
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

  Future<void> _previewAndSubmitAdminEntry(
    DailyEntryDraft draft, {
    ShiftEntryModel? existingEntry,
  }) async {
    final preview = await _salesService.previewEntry(
      date: draft.date,
      closingReadings: draft.closingReadings,
      pumpAttendants: draft.pumpAttendants,
      pumpTesting: draft.pumpTesting,
      pumpPayments: draft.pumpPayments,
      pumpCollections: draft.pumpCollections,
      paymentBreakdown: draft.paymentBreakdown,
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

    if (existingEntry == null) {
      await _salesService.submitEntry(
        date: draft.date,
        closingReadings: draft.closingReadings,
        pumpAttendants: draft.pumpAttendants,
        pumpTesting: draft.pumpTesting,
        pumpPayments: draft.pumpPayments,
        pumpCollections: draft.pumpCollections,
        paymentBreakdown: draft.paymentBreakdown,
        creditEntries: draft.creditEntries,
        mismatchReason: mismatchReason,
      );
    } else {
      await _managementService.updateEntry(
        entryId: existingEntry.id,
        closingReadings: draft.closingReadings,
        pumpAttendants: draft.pumpAttendants,
        pumpTesting: draft.pumpTesting,
        pumpPayments: draft.pumpPayments,
        pumpCollections: draft.pumpCollections,
        paymentBreakdown: draft.paymentBreakdown,
        creditEntries: draft.creditEntries,
        mismatchReason: mismatchReason,
      );
    }
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Entry saved. Collected ${formatCurrency(preview.paymentTotal)}.',
        ),
      ),
    );
    await _reload();
  }

  Future<void> _editEntry(ShiftEntryModel entry, StationConfigModel station) async {
    final draft = await showDailyEntryEditorDialog(
      context: context,
      station: station,
      title: 'Edit Daily Entry',
      initialDate: entry.date,
      openingReadings: entry.openingReadings,
      initialDraft: _draftFromEntry(entry),
      allowDateEdit: false,
    );

    if (draft == null) {
      return;
    }

    final preview = await _salesService.previewEntry(
      date: draft.date,
      closingReadings: draft.closingReadings,
      pumpAttendants: draft.pumpAttendants,
      pumpTesting: draft.pumpTesting,
      pumpPayments: draft.pumpPayments,
      pumpCollections: draft.pumpCollections,
      paymentBreakdown: draft.paymentBreakdown,
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

    await _managementService.updateEntry(
      entryId: entry.id,
      closingReadings: draft.closingReadings,
      pumpAttendants: draft.pumpAttendants,
      pumpTesting: draft.pumpTesting,
      pumpPayments: draft.pumpPayments,
      pumpCollections: draft.pumpCollections,
      paymentBreakdown: draft.paymentBreakdown,
      creditEntries: draft.creditEntries,
      mismatchReason: mismatchReason,
    );
    await _reload();
  }

  Future<void> _approveEntry(ShiftEntryModel entry) async {
    await _managementService.approveEntry(entry.id);
    await _reload();
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
                children: [Center(child: Text('${snapshot.error}'))],
              );
            }

            final data = snapshot.data!;
            final entries = data.entries;
            final approvedCount =
                entries.where((entry) => entry.status == 'approved').length;
            final flaggedCount = entries.where((entry) => entry.flagged).length;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
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
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Admins and sales staff now work from the same one-entry-per-day sales record.',
                        style: TextStyle(color: Colors.white70, height: 1.4),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
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
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Approved',
                        value: '$approvedCount',
                        subtitle: 'Ready for reports',
                        accent: const Color(0xFF0F9D58),
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
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _monthController,
                          decoration: const InputDecoration(
                            labelText: 'Month (YYYY-MM)',
                            filled: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _reload,
                        icon: const Icon(Icons.filter_alt_rounded),
                        label: const Text('Apply'),
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
                  ...entries
                      .reversed
                      .map(
                        (entry) => Container(
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
                                  Text(
                                    '2T Oil ${formatLiters(entry.totals.sold.twoT)}',
                                  ),
                                  Text(
                                    'Revenue ${formatCurrency(entry.revenue)}',
                                  ),
                                  Text(
                                    'Collected ${formatCurrency(entry.paymentTotal)}',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Submitted by ${entry.submittedBy}',
                                style: const TextStyle(color: Color(0xFF55606E)),
                              ),
                              if (entry.pumpAttendants.values.any((name) => name.isNotEmpty))
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    entry.pumpAttendants.entries
                                        .where((item) => item.value.isNotEmpty)
                                        .map((item) => '${item.key}: ${item.value}')
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
                                    onPressed: () =>
                                        _editEntry(entry, data.dashboard.station),
                                    child: const Text('Edit Entry'),
                                  ),
                                  const SizedBox(width: 10),
                                  if (entry.status != 'approved')
                                    FilledButton(
                                      onPressed: () => _approveEntry(entry),
                                      child: const Text('Approve'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EntryManagementData {
  const _EntryManagementData({
    required this.entries,
    required this.dashboard,
  });

  final List<ShiftEntryModel> entries;
  final SalesDashboardModel dashboard;
}

class _DashboardChip extends StatelessWidget {
  const _DashboardChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
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
  });

  final String title;
  final String value;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF55606E),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF55606E)),
          ),
        ],
      ),
    );
  }
}
