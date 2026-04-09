import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/credit_service.dart';
import '../utils/formatters.dart';

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
  List<CreditCustomerSummaryModel> _latestCustomers = const [];
  late Future<(CreditLedgerSummaryModel, List<CreditCustomerSummaryModel>)>
  _future;

  String _errorText(Object? error) {
    return error.toString().replaceFirst('Exception: ', '');
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

  Future<void> _pickDate(bool isFrom) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: isFrom ? (_fromDate ?? DateTime.now()) : (_toDate ?? DateTime.now()),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      helpText: isFrom ? 'Select from date' : 'Select to date',
    );
    if (selected == null) {
      return;
    }
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownMenu<String>(
                          width: double.infinity,
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
                            DropdownMenuItem(value: 'cash', child: Text('Cash')),
                            DropdownMenuItem(value: 'check', child: Text('Check')),
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
                          if (!context.mounted) {
                            return;
                          }
                          Navigator.of(context).pop(true);
                        } catch (error) {
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFFB91C1C),
                              content: Text(
                                error.toString().replaceFirst('Exception: ', ''),
                              ),
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

    if (created == true) {
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(title: const Text('Credit Ledger')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:
            _latestCustomers.isEmpty
                ? null
                : () => _openStandaloneCollectionDialog(_latestCustomers),
        icon: const Icon(Icons.payments_outlined),
        label: const Text('Record Collection'),
      ),
      body: FutureBuilder<(CreditLedgerSummaryModel, List<CreditCustomerSummaryModel>)>(
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Credit Filters',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF293340),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by customer name',
                        filled: true,
                        fillColor: const Color(0xFFF8F9FF),
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
                          ChoiceChip(
                            label: Text(option.toUpperCase()),
                            selected: _status == option,
                            onSelected: (_) {
                              setState(() {
                                _status = option;
                                _future = _load();
                              });
                            },
                          ),
                        OutlinedButton.icon(
                          onPressed: () => _pickDate(true),
                          icon: const Icon(Icons.date_range_rounded),
                          label: Text(
                            _fromDate == null
                                ? 'From'
                                : formatDateLabel(_toApiDate(_fromDate!)),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _pickDate(false),
                          icon: const Icon(Icons.event_rounded),
                          label: Text(
                            _toDate == null
                                ? 'To'
                                : formatDateLabel(_toApiDate(_toDate!)),
                          ),
                        ),
                        if (_fromDate != null || _toDate != null)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _fromDate = null;
                                _toDate = null;
                                _future = _load();
                              });
                            },
                            child: const Text('Clear Range'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _CreditMetricCard(
                      label: 'Open customers',
                      value: '${summary.openCustomerCount}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _CreditMetricCard(
                      label: 'Open balance',
                      value: formatCurrency(summary.openBalanceTotal),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _CreditMetricCard(
                      label: 'Collected',
                      value: formatCurrency(summary.collectedInRangeTotal),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (customers.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(child: Text('No credit customers found.')),
                )
              else
                ...customers.map(
                  (item) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Text(
                        item.customer.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Balance ${formatCurrency(item.currentBalance)} • Issued ${formatCurrency(item.totalIssued)} • Collected ${formatCurrency(item.totalCollected)}',
                            ),
                            if (item.lastActivityDate.isNotEmpty)
                              Text(
                                'Last activity ${formatDateLabel(item.lastActivityDate)}',
                                style: const TextStyle(
                                  color: Color(0xFF55606E),
                                ),
                              ),
                          ],
                        ),
                      ),
                      trailing: Chip(
                        label: Text(item.status.toUpperCase()),
                        backgroundColor:
                            item.status == 'open'
                                ? const Color(0xFFFFF7ED)
                                : const Color(0xFFF3F4F6),
                      ),
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
                ),
            ],
          );
        },
      ),
    );
  }
}

class CreditCustomerDetailScreen extends StatefulWidget {
  const CreditCustomerDetailScreen({super.key, required this.customerId});

  final String customerId;

  @override
  State<CreditCustomerDetailScreen> createState() =>
      _CreditCustomerDetailScreenState();
}

class _CreditCustomerDetailScreenState extends State<CreditCustomerDetailScreen> {
  final CreditService _creditService = CreditService();
  late Future<CreditCustomerDetailModel> _future;

  String _errorText(Object? error) {
    return error.toString().replaceFirst('Exception: ', '');
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
                            DropdownMenuItem(value: 'cash', child: Text('Cash')),
                            DropdownMenuItem(value: 'check', child: Text('Check')),
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
                          if (!context.mounted) {
                            return;
                          }
                          Navigator.of(context).pop(true);
                        } catch (error) {
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFFB91C1C),
                              content: Text(
                                error.toString().replaceFirst('Exception: ', ''),
                              ),
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
    if (saved == true) {
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(title: const Text('Credit Detail')),
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
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
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
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF293340),
                            ),
                          ),
                        ),
                        Chip(label: Text(detail.status.toUpperCase())),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Text('Balance ${formatCurrency(detail.currentBalance)}'),
                        Text('Issued ${formatCurrency(detail.totalIssued)}'),
                        Text('Collected ${formatCurrency(detail.totalCollected)}'),
                        if (detail.openedAt.isNotEmpty)
                          Text('Opened ${formatDateLabel(detail.openedAt)}'),
                        if (detail.lastClosedAt.isNotEmpty)
                          Text('Closed ${formatDateLabel(detail.lastClosedAt)}'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => _recordCollection(detail),
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Record Collection'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ...detail.transactions.map(
                (item) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item.type.toUpperCase()} • ${formatDateLabel(item.date)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            formatCurrency(item.amount),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF293340),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Running balance ${formatCurrency(item.runningBalance)}',
                        style: const TextStyle(color: Color(0xFF55606E)),
                      ),
                      if (item.paymentMode.isNotEmpty)
                        Text(
                          'Mode ${item.paymentMode.toUpperCase()}',
                          style: const TextStyle(color: Color(0xFF55606E)),
                        ),
                      if (item.note.isNotEmpty)
                        Text(
                          item.note,
                          style: const TextStyle(color: Color(0xFF55606E)),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CreditMetricCard extends StatelessWidget {
  const _CreditMetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF293340),
            ),
          ),
        ],
      ),
    );
  }
}
