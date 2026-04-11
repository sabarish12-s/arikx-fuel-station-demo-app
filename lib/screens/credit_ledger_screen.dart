import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/credit_service.dart';
import '../utils/formatters.dart';
import '../utils/user_facing_errors.dart';
import '../widgets/clay_widgets.dart';
import '../widgets/responsive_text.dart';

class CreditLedgerScreen extends StatefulWidget {
  const CreditLedgerScreen({super.key});

  @override
  State<CreditLedgerScreen> createState() => _CreditLedgerScreenState();
}

class _CreditLedgerScreenState extends State<CreditLedgerScreen> {
  final CreditService _creditService = CreditService();
  final TextEditingController _searchController = TextEditingController();
  String _status = 'all';
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _loadingStandaloneCollectionCustomers = false;
  List<CreditCustomerSummaryModel> _latestCustomers = const [];
  late Future<(CreditLedgerSummaryModel, List<CreditCustomerSummaryModel>)>
  _future;

  String _errorText(Object? error) {
    return userFacingErrorMessage(error);
  }

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _toApiDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<(CreditLedgerSummaryModel, List<CreditCustomerSummaryModel>)> _load() {
    return _creditService.fetchCustomers(
      query: _searchController.text.trim(),
      status: _status,
      fromDate: _fromDate == null ? null : _toApiDate(_fromDate!),
      toDate: _toDate == null ? null : _toApiDate(_toDate!),
    );
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _openStandaloneCollectionDialogFromLedger() async {
    if (_loadingStandaloneCollectionCustomers) {
      return;
    }

    setState(() {
      _loadingStandaloneCollectionCustomers = true;
    });

    try {
      var customers = _latestCustomers;
      final shouldRefreshCustomerOptions =
          customers.isEmpty ||
          _searchController.text.trim().isNotEmpty ||
          _status != 'all' ||
          _fromDate != null ||
          _toDate != null;

      if (shouldRefreshCustomerOptions) {
        final (_, fetchedCustomers) = await _creditService.fetchCustomers();
        customers = fetchedCustomers;
      }

      if (!mounted) {
        return;
      }

      if (customers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFFB91C1C),
            content: Text('No credit customers are available to collect from.'),
          ),
        );
        return;
      }

      await _openStandaloneCollectionDialog(customers);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFB91C1C),
          content: Text(_errorText(error)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingStandaloneCollectionCustomers = false;
        });
      }
    }
  }

  Future<void> _pickDate(bool isFrom) async {
    final selected = await showDatePicker(
      context: context,
      initialDate:
          isFrom ? (_fromDate ?? DateTime.now()) : (_toDate ?? DateTime.now()),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      helpText: isFrom ? 'Select from date' : 'Select to date',
    );
    if (selected == null) return;
    setState(() {
      if (isFrom) {
        _fromDate = selected;
      } else {
        _toDate = selected;
      }
      _future = _load();
    });
  }

  Future<void> _openStandaloneCollectionDialog(
    List<CreditCustomerSummaryModel> customers,
  ) async {
    final amountController = TextEditingController();
    final dateController = TextEditingController(
      text: _toApiDate(DateTime.now()),
    );
    String paymentMode = 'cash';
    final noteController = TextEditingController();
    String? selectedCustomerId;

    final created = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('Record Credit Collection'),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final dropdownWidth =
                            constraints.maxWidth.isFinite
                                ? constraints.maxWidth
                                : MediaQuery.sizeOf(context).width - 96;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DropdownMenu<String>(
                              width: dropdownWidth,
                              enableFilter: true,
                              enableSearch: true,
                              requestFocusOnTap: true,
                              label: const Text('Customer'),
                              hintText: 'Search and select existing customer',
                              onSelected: (value) {
                                setState(() {
                                  selectedCustomerId = value;
                                });
                              },
                              dropdownMenuEntries:
                                  customers
                                      .map(
                                        (item) => DropdownMenuEntry<String>(
                                          value: item.customer.id,
                                          label: item.customer.name,
                                        ),
                                      )
                                      .toList(),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: amountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Amount',
                                filled: true,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: dateController,
                              decoration: const InputDecoration(
                                labelText: 'Date (YYYY-MM-DD)',
                                filled: true,
                              ),
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              initialValue: paymentMode,
                              decoration: const InputDecoration(
                                labelText: 'Payment mode',
                                filled: true,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'cash',
                                  child: Text('Cash'),
                                ),
                                DropdownMenuItem(
                                  value: 'check',
                                  child: Text('HP Pay'),
                                ),
                                DropdownMenuItem(
                                  value: 'upi',
                                  child: Text('UPI'),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  paymentMode = value ?? 'cash';
                                });
                              },
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: noteController,
                              decoration: const InputDecoration(
                                labelText: 'Note (optional)',
                                filled: true,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () async {
                        CreditCustomerSummaryModel? selectedCustomer;
                        for (final item in customers) {
                          if (item.customer.id == selectedCustomerId) {
                            selectedCustomer = item;
                            break;
                          }
                        }
                        if (selectedCustomer == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: Color(0xFFB91C1C),
                              content: Text(
                                'Select an existing customer from the list.',
                              ),
                            ),
                          );
                          return;
                        }
                        try {
                          await _creditService.recordCollection(
                            customerId: selectedCustomer.customer.id,
                            name: selectedCustomer.customer.name,
                            amount:
                                double.tryParse(amountController.text.trim()) ??
                                0,
                            date: dateController.text.trim(),
                            paymentMode: paymentMode,
                            note: noteController.text.trim(),
                          );
                          if (!context.mounted) return;
                          Navigator.of(context).pop(true);
                        } catch (error) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFFB91C1C),
                              content: Text(userFacingErrorMessage(error)),
                            ),
                          );
                        }
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
          ),
    );

    amountController.dispose();
    dateController.dispose();
    noteController.dispose();

    if (created == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kClayBg,
      appBar: AppBar(
        backgroundColor: kClayBg,
        title: const Text(
          'Credit Ledger',
          style: TextStyle(fontWeight: FontWeight.w900, color: kClayPrimary),
        ),
        iconTheme: const IconThemeData(color: kClayPrimary),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:
            _loadingStandaloneCollectionCustomers
                ? null
                : _openStandaloneCollectionDialogFromLedger,
        backgroundColor: const Color(0xFF1A3A7A),
        icon:
            _loadingStandaloneCollectionCustomers
                ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                : const Icon(Icons.payments_outlined, color: Colors.white),
        label: Text(
          _loadingStandaloneCollectionCustomers
              ? 'Loading...'
              : 'Record Collection',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: FutureBuilder<
        (CreditLedgerSummaryModel, List<CreditCustomerSummaryModel>)
      >(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(_errorText(snapshot.error)));
          }

          final (summary, customers) = snapshot.data!;
          _latestCustomers = customers;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              // ── Hero summary ──────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
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
                child: Row(
                  children: [
                    _HeroMetric(
                      label: 'Open',
                      value: '${summary.openCustomerCount}',
                      sub: 'customers',
                    ),
                    _HeroDivider(),
                    _HeroMetric(
                      label: 'Balance',
                      value: formatCurrency(summary.openBalanceTotal),
                      sub: 'outstanding',
                    ),
                    _HeroDivider(),
                    _HeroMetric(
                      label: 'Collected',
                      value: formatCurrency(summary.collectedInRangeTotal),
                      sub: 'in range',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── Filters ───────────────────────────────────────
              ClayCard(
                margin: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FILTERS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: kClaySub,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by customer name',
                        filled: true,
                        fillColor: kClayBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: IconButton(
                          onPressed: _reload,
                          icon: const Icon(Icons.search_rounded),
                        ),
                      ),
                      onSubmitted: (_) => _reload(),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final option in const ['all', 'open', 'closed'])
                          _StatusPill(
                            label: option.toUpperCase(),
                            selected: _status == option,
                            onTap: () {
                              setState(() {
                                _status = option;
                                _future = _load();
                              });
                            },
                          ),
                        _DatePill(
                          icon: Icons.date_range_rounded,
                          label:
                              _fromDate == null
                                  ? 'From'
                                  : formatDateLabel(_toApiDate(_fromDate!)),
                          onTap: () => _pickDate(true),
                        ),
                        _DatePill(
                          icon: Icons.event_rounded,
                          label:
                              _toDate == null
                                  ? 'To'
                                  : formatDateLabel(_toApiDate(_toDate!)),
                          onTap: () => _pickDate(false),
                        ),
                        if (_fromDate != null || _toDate != null)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _fromDate = null;
                                _toDate = null;
                                _future = _load();
                              });
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                'Clear Range',
                                style: TextStyle(
                                  color: Color(0xFFCE5828),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Customer list ─────────────────────────────────
              if (customers.isEmpty)
                ClayCard(
                  child: const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No credit customers found.',
                        style: TextStyle(color: kClaySub),
                      ),
                    ),
                  ),
                )
              else
                ...customers.map(
                  (item) => _CustomerCard(
                    item: item,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder:
                              (_) => CreditCustomerDetailScreen(
                                customerId: item.customer.id,
                              ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Hero metric ─────────────────────────────────────────────────────────────
class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
    required this.sub,
  });
  final String label;
  final String value;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OneLineScaleText(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          OneLineScaleText(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            sub,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _HeroDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: Colors.white.withValues(alpha: 0.20),
    );
  }
}

// ─── Status pill ─────────────────────────────────────────────────────────────
class _StatusPill extends StatelessWidget {
  const _StatusPill({
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? kClayPrimary : Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow:
              selected
                  ? null
                  : [
                    BoxShadow(
                      color: const Color(0xFFB8C0DC).withValues(alpha: 0.50),
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
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : kClaySub,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ─── Date pill ───────────────────────────────────────────────────────────────
class _DatePill extends StatelessWidget {
  const _DatePill({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFB8C0DC).withValues(alpha: 0.50),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: kClaySub),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: kClaySub,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Customer card ────────────────────────────────────────────────────────────
class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.item, required this.onTap});
  final CreditCustomerSummaryModel item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isOpen = item.status == 'open';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ClayCard(
        margin: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color:
                    isOpen
                        ? const Color(0xFFCE5828).withValues(alpha: 0.10)
                        : const Color(0xFF2AA878).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isOpen ? Icons.pending_rounded : Icons.check_circle_rounded,
                color:
                    isOpen ? const Color(0xFFCE5828) : const Color(0xFF2AA878),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.customer.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: kClayPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Balance ${formatCurrency(item.currentBalance)}  ·  Issued ${formatCurrency(item.totalIssued)}',
                    style: const TextStyle(color: kClaySub, fontSize: 12),
                  ),
                  if (item.lastActivityDate.isNotEmpty)
                    Text(
                      'Last activity ${formatDateLabel(item.lastActivityDate)}',
                      style: const TextStyle(color: kClaySub, fontSize: 11),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: kClaySub, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Credit Customer Detail Screen
// ─────────────────────────────────────────────────────────────────────────────
class CreditCustomerDetailScreen extends StatefulWidget {
  const CreditCustomerDetailScreen({super.key, required this.customerId});

  final String customerId;

  @override
  State<CreditCustomerDetailScreen> createState() =>
      _CreditCustomerDetailScreenState();
}

class _CreditCustomerDetailScreenState
    extends State<CreditCustomerDetailScreen> {
  final CreditService _creditService = CreditService();
  late Future<CreditCustomerDetailModel> _future;

  String _errorText(Object? error) {
    return userFacingErrorMessage(error);
  }

  @override
  void initState() {
    super.initState();
    _future = _creditService.fetchCustomerDetail(widget.customerId);
  }

  void _reload() {
    setState(() {
      _future = _creditService.fetchCustomerDetail(widget.customerId);
    });
  }

  Future<void> _recordCollection(CreditCustomerDetailModel detail) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final dateController = TextEditingController(
      text: DateTime.now().toIso8601String().split('T').first,
    );
    String paymentMode = 'cash';

    final saved = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: Text('Collect from ${detail.customer.name}'),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Amount',
                            filled: true,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: dateController,
                          decoration: const InputDecoration(
                            labelText: 'Date (YYYY-MM-DD)',
                            filled: true,
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: paymentMode,
                          decoration: const InputDecoration(
                            labelText: 'Payment mode',
                            filled: true,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'cash',
                              child: Text('Cash'),
                            ),
                            DropdownMenuItem(
                              value: 'check',
                              child: Text('HP Pay'),
                            ),
                            DropdownMenuItem(value: 'upi', child: Text('UPI')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              paymentMode = value ?? 'cash';
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: noteController,
                          decoration: const InputDecoration(
                            labelText: 'Note (optional)',
                            filled: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () async {
                        try {
                          await _creditService.recordCollection(
                            customerId: detail.customer.id,
                            name: detail.customer.name,
                            amount:
                                double.tryParse(amountController.text.trim()) ??
                                0,
                            date: dateController.text.trim(),
                            paymentMode: paymentMode,
                            note: noteController.text.trim(),
                          );
                          if (!context.mounted) return;
                          Navigator.of(context).pop(true);
                        } catch (error) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFFB91C1C),
                              content: Text(userFacingErrorMessage(error)),
                            ),
                          );
                        }
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
          ),
    );

    amountController.dispose();
    noteController.dispose();
    dateController.dispose();
    if (saved == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kClayBg,
      appBar: AppBar(
        backgroundColor: kClayBg,
        iconTheme: const IconThemeData(color: kClayPrimary),
        title: const Text(
          'Credit Detail',
          style: TextStyle(fontWeight: FontWeight.w900, color: kClayPrimary),
        ),
      ),
      body: FutureBuilder<CreditCustomerDetailModel>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(_errorText(snapshot.error)));
          }

          final detail = snapshot.data!;
          final isOpen = detail.status == 'open';

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // ── Customer hero ────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            detail.customer.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            detail.status.toUpperCase(),
                            style: TextStyle(
                              color:
                                  isOpen
                                      ? const Color(0xFFFFB649)
                                      : const Color(0xFF7EEFC0),
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _DetailMetric(
                          label: 'Balance',
                          value: formatCurrency(detail.currentBalance),
                        ),
                        _DetailDivider(),
                        _DetailMetric(
                          label: 'Issued',
                          value: formatCurrency(detail.totalIssued),
                        ),
                        _DetailDivider(),
                        _DetailMetric(
                          label: 'Collected',
                          value: formatCurrency(detail.totalCollected),
                        ),
                      ],
                    ),
                    if (detail.openedAt.isNotEmpty ||
                        detail.lastClosedAt.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        children: [
                          if (detail.openedAt.isNotEmpty)
                            Text(
                              'Opened ${formatDateLabel(detail.openedAt)}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          if (detail.lastClosedAt.isNotEmpty)
                            Text(
                              'Closed ${formatDateLabel(detail.lastClosedAt)}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: () => _recordCollection(detail),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.18),
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.30),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.payments_outlined, size: 16),
                        label: const Text(
                          'Record Collection',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── Transactions ─────────────────────────────────
              if (detail.transactions.isEmpty)
                ClayCard(
                  child: const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No transactions yet.',
                        style: TextStyle(color: kClaySub),
                      ),
                    ),
                  ),
                )
              else
                ...detail.transactions.map(
                  (item) => _TransactionCard(item: item),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Detail metric ────────────────────────────────────────────────────────────
class _DetailMetric extends StatelessWidget {
  const _DetailMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _DetailDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.white.withValues(alpha: 0.20),
    );
  }
}

// ─── Transaction card ─────────────────────────────────────────────────────────
class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.item});
  final CreditTransactionModel item;

  @override
  Widget build(BuildContext context) {
    final isCredit =
        item.type.toLowerCase() == 'credit' ||
        item.type.toLowerCase() == 'issue';
    return ClayCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color:
                  isCredit
                      ? const Color(0xFFCE5828).withValues(alpha: 0.10)
                      : const Color(0xFF2AA878).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCredit
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              color:
                  isCredit ? const Color(0xFFCE5828) : const Color(0xFF2AA878),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OneLineScaleText(
                        '${item.type.toUpperCase()}  ·  ${formatDateLabel(item.date)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: kClayPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    OneLineScaleText(
                      formatCurrency(item.amount),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color:
                            isCredit
                                ? const Color(0xFFCE5828)
                                : const Color(0xFF2AA878),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Running balance ${formatCurrency(item.runningBalance)}',
                  style: const TextStyle(color: kClaySub, fontSize: 12),
                ),
                if (item.paymentMode.isNotEmpty)
                  Text(
                    'Mode ${item.paymentMode.toUpperCase()}',
                    style: const TextStyle(color: kClaySub, fontSize: 12),
                  ),
                if (item.note.isNotEmpty)
                  Text(
                    item.note,
                    style: const TextStyle(color: kClaySub, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
