import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../utils/formatters.dart';
import '../utils/user_facing_errors.dart';
import 'clay_widgets.dart';
import 'responsive_text.dart';

const String _notEntered = 'Not entered';

class EntryDetailSheet extends StatelessWidget {
  const EntryDetailSheet({
    super.key,
    required this.future,
    this.showSubmittedBy = false,
    this.showCreditCollections = false,
    this.showProfitInSettlement = true,
  });

  final Future<ShiftEntryModel> future;
  final bool showSubmittedBy;
  final bool showCreditCollections;
  final bool showProfitInSettlement;

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

                    return _EntryDetailContent(
                      entry: snapshot.data!,
                      showSubmittedBy: showSubmittedBy,
                      showCreditCollections: showCreditCollections,
                      showProfitInSettlement: showProfitInSettlement,
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

class _EntryDetailContent extends StatelessWidget {
  const _EntryDetailContent({
    required this.entry,
    required this.showSubmittedBy,
    required this.showCreditCollections,
    required this.showProfitInSettlement,
  });

  final ShiftEntryModel entry;
  final bool showSubmittedBy;
  final bool showCreditCollections;
  final bool showProfitInSettlement;

  @override
  Widget build(BuildContext context) {
    final showMismatchReason = _shouldShowMismatchReason(entry);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        _DetailSection(
          title: 'Header',
          child: Column(
            children: [
              _EntryHeaderHero(entry: entry),
              const SizedBox(height: 12),
              _HeaderInfoGrid(
                items: [
                  if (showSubmittedBy)
                    _HeaderInfoItem(
                      label: 'Submitted by',
                      value: _displayOrPlaceholder(entry.submittedByName),
                    ),
                  _HeaderInfoItem(
                    label: 'Submitted at',
                    value: _formatDateTimeOrPlaceholder(entry.submittedAt),
                  ),
                  _HeaderInfoItem(
                    label: 'Updated at',
                    value: _formatDateTimeOrPlaceholder(entry.updatedAt),
                  ),
                  _HeaderInfoItem(
                    label: 'Approved at',
                    value: _formatDateTimeOrPlaceholder(entry.approvedAt),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _DetailSection(
          title: 'Stock',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FuelBreakdownTile(
                title: 'Opening total',
                totals: entry.totals.opening,
              ),
              const SizedBox(height: 10),
              _FuelBreakdownTile(
                title: 'Closing total',
                totals: entry.totals.closing,
              ),
              const SizedBox(height: 10),
              _FuelBreakdownTile(
                title: 'Sold total',
                totals: entry.totals.sold,
              ),
              const SizedBox(height: 14),
              const _SubSectionLabel('Readings'),
              const SizedBox(height: 8),
              ..._buildPumpReadingCards(entry),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _DetailSection(
          title: 'Pump Details',
          child: Column(children: _buildPumpDetailCards(entry)),
        ),
        const SizedBox(height: 12),
        _DetailSection(
          title: 'Settlement',
          child: Column(
            children: [
              _MoneyBreakdownTile(
                title: 'Payments',
                values: _settlementPaymentValues(entry),
              ),
              const SizedBox(height: 10),
              _DetailRow(
                label: 'Computed revenue',
                value: formatCurrency(entry.computedRevenue),
              ),
              _DetailRow(
                label: 'Sales settlement',
                value: formatCurrency(entry.salesSettlementTotal),
              ),
              _DetailRow(
                label: 'Mismatch amount',
                value: formatCurrency(entry.mismatchAmount),
                isLast: !showMismatchReason && !showProfitInSettlement,
              ),
              if (showMismatchReason)
                _DetailRow(
                  label: 'Mismatch reason',
                  value: _displayOrPlaceholder(entry.mismatchReason),
                  isLast: !showProfitInSettlement,
                ),
              if (showProfitInSettlement)
                _DetailRow(
                  label: 'Profit',
                  value: formatCurrency(entry.profit),
                  isLast: true,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _DetailSection(
          title: 'Credit',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SubSectionLabel('Issued'),
              const SizedBox(height: 8),
              ..._buildCreditEntryCards(entry.creditEntries),
              if (showCreditCollections) ...[
                const SizedBox(height: 14),
                const _SubSectionLabel('Collected'),
                const SizedBox(height: 8),
                ..._buildCreditCollectionCards(entry.creditCollections),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _DetailSection(
          title: 'Notes',
          child: Column(
            children: [
              _DetailRow(
                label: 'Variance note',
                value: _displayOrPlaceholder(entry.varianceNote),
                isLast: !showMismatchReason,
              ),
              if (showMismatchReason)
                _DetailRow(
                  label: 'Mismatch reason',
                  value: _displayOrPlaceholder(entry.mismatchReason),
                  isLast: true,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

List<Widget> _buildPumpReadingCards(ShiftEntryModel entry) {
  final pumpIds = _pumpIds(entry);
  if (pumpIds.isEmpty) {
    return const [_EmptySubCard(message: _notEntered)];
  }
  return [
    for (int index = 0; index < pumpIds.length; index++) ...[
      _SubCard(
        title: formatPumpLabel(pumpIds[index]),
        child: Column(
          children: [
            _FuelBreakdownTile(
              title: 'Opening',
              totals: entry.openingReadings[pumpIds[index]],
            ),
            const SizedBox(height: 10),
            _FuelBreakdownTile(
              title: 'Closing',
              totals: entry.closingReadings[pumpIds[index]],
            ),
            const SizedBox(height: 10),
            _FuelBreakdownTile(
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

List<Widget> _buildPumpDetailCards(ShiftEntryModel entry) {
  final pumpIds = _pumpIds(entry);
  if (pumpIds.isEmpty) {
    return const [_EmptySubCard(message: _notEntered)];
  }
  return [
    for (int index = 0; index < pumpIds.length; index++) ...[
      _SubCard(
        title: formatPumpLabel(pumpIds[index]),
        child: Column(
          children: [
            _DetailRow(
              label: 'Attendant',
              value: _displayOrPlaceholder(
                entry.pumpAttendants[pumpIds[index]] ?? '',
              ),
            ),
            _DetailRow(
              label: 'Testing',
              value: _formatTesting(entry.pumpTesting[pumpIds[index]]),
              valueAlign: TextAlign.left,
            ),
            if (entry.pumpPayments.containsKey(pumpIds[index])) ...[
              _MoneyBreakdownTile(
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
              const _DetailRow(label: 'Pump payments', value: _notEntered),
            ],
            _DetailRow(
              label: 'Pump collection',
              value: entry.pumpCollections.containsKey(pumpIds[index])
                  ? formatCurrency(entry.pumpCollections[pumpIds[index]] ?? 0)
                  : _notEntered,
              isLast: true,
            ),
          ],
        ),
      ),
      if (index != pumpIds.length - 1) const SizedBox(height: 10),
    ],
  ];
}

List<Widget> _buildCreditEntryCards(List<CreditEntryModel> entries) {
  if (entries.isEmpty) {
    return const [_EmptySubCard(message: _notEntered)];
  }
  return [
    for (int index = 0; index < entries.length; index++) ...[
      _SubCard(
        title: entries[index].name.trim().isEmpty
            ? 'Credit entry ${index + 1}'
            : entries[index].name.trim(),
        child: Column(
          children: [
            _DetailRow(
              label: 'Pump',
              value: entries[index].pumpId.trim().isEmpty
                  ? _notEntered
                  : formatPumpLabel(entries[index].pumpId),
            ),
            _DetailRow(
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

List<Widget> _buildCreditCollectionCards(
  List<CreditCollectionModel> collections,
) {
  if (collections.isEmpty) {
    return const [_EmptySubCard(message: _notEntered)];
  }
  return [
    for (int index = 0; index < collections.length; index++) ...[
      _SubCard(
        title: collections[index].name.trim().isEmpty
            ? 'Collection ${index + 1}'
            : collections[index].name.trim(),
        child: Column(
          children: [
            _DetailRow(
              label: 'Amount',
              value: formatCurrency(collections[index].amount),
            ),
            _DetailRow(
              label: 'Date',
              value: _displayOrPlaceholder(
                collections[index].date.isEmpty
                    ? ''
                    : formatDateLabel(collections[index].date),
              ),
            ),
            _DetailRow(
              label: 'Payment mode',
              value: _displayOrPlaceholder(collections[index].paymentMode),
            ),
            _DetailRow(
              label: 'Note',
              value: _displayOrPlaceholder(collections[index].note),
              isLast: true,
            ),
          ],
        ),
      ),
      if (index != collections.length - 1) const SizedBox(height: 10),
    ],
  ];
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});

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

class _EntryHeaderHero extends StatelessWidget {
  const _EntryHeaderHero({required this.entry});

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
      child: Row(
        children: [
          Expanded(
            child: OneLineScaleText(
              formatDateLabel(entry.date),
              style: const TextStyle(
                color: kClayPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          _HeaderBadge(
            label: _statusLabel(entry),
            accent: _statusAccent(entry),
          ),
        ],
      ),
    );
  }
}

class _HeaderInfoItem {
  const _HeaderInfoItem({required this.label, required this.value});

  final String label;
  final String value;
}

class _HeaderInfoGrid extends StatelessWidget {
  const _HeaderInfoGrid({required this.items});

  final List<_HeaderInfoItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in items)
              SizedBox(
                width: itemWidth,
                child: _HeaderInfoCard(label: item.label, value: item.value),
              ),
          ],
        );
      },
    );
  }
}

class _HeaderInfoCard extends StatelessWidget {
  const _HeaderInfoCard({required this.label, required this.value});

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

class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge({required this.label, this.accent = kClayPrimary});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
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

class _SubSectionLabel extends StatelessWidget {
  const _SubSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: kClayPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.isLast = false,
    this.valueAlign = TextAlign.right,
  });

  final String label;
  final String value;
  final bool isLast;
  final TextAlign valueAlign;

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
              textAlign: valueAlign,
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

class _FuelBreakdownTile extends StatelessWidget {
  const _FuelBreakdownTile({required this.title, required this.totals});

  final String title;
  final Object? totals;

  @override
  Widget build(BuildContext context) {
    if (totals == null) {
      return _DataBlock(
        title: title,
        child: const Text(
          _notEntered,
          style: TextStyle(
            color: kClaySub,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return _DataBlock(
      title: title,
      child: Column(
        children: [
          _MiniValueRow(
            label: 'Petrol',
            value: formatLiters(_fuelPetrol(totals)),
          ),
          const SizedBox(height: 8),
          _MiniValueRow(
            label: 'Diesel',
            value: formatLiters(_fuelDiesel(totals)),
          ),
          const SizedBox(height: 8),
          _MiniValueRow(
            label: '2T Oil',
            value: formatLiters(_fuelTwoT(totals)),
          ),
        ],
      ),
    );
  }
}

class _MoneyBreakdownTile extends StatelessWidget {
  const _MoneyBreakdownTile({required this.title, required this.values});

  final String title;
  final Map<String, double> values;

  @override
  Widget build(BuildContext context) {
    return _DataBlock(
      title: title,
      child: Column(
        children: [
          for (int index = 0; index < values.entries.length; index++) ...[
            _MiniValueRow(
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

class _DataBlock extends StatelessWidget {
  const _DataBlock({required this.title, required this.child});

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

class _MiniValueRow extends StatelessWidget {
  const _MiniValueRow({required this.label, required this.value});

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
        Expanded(
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

class _SubCard extends StatelessWidget {
  const _SubCard({required this.title, required this.child});

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

class _EmptySubCard extends StatelessWidget {
  const _EmptySubCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _SubCard(
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

String _statusLabel(ShiftEntryModel entry) {
  if (entry.flagged) {
    return 'Flagged';
  }
  if (entry.status.trim().isEmpty) {
    return _notEntered;
  }
  return _shiftCase(entry.status);
}

Color _statusAccent(ShiftEntryModel entry) {
  if (entry.flagged) {
    return const Color(0xFFB91C1C);
  }
  if (entry.status.trim().toLowerCase() == 'approved') {
    return const Color(0xFF2AA878);
  }
  return kClayPrimary;
}

String _displayOrPlaceholder(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? _notEntered : trimmed;
}

String _formatDateTimeOrPlaceholder(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? _notEntered : formatDateTimeLabel(trimmed);
}

String _formatTesting(PumpTestingModel? testing) {
  if (testing == null || !testing.enabled) {
    return _notEntered;
  }
  final addToInventory = testing.addToInventory ? 'Yes' : 'No';
  return 'Petrol ${formatLiters(testing.petrol)}, Diesel ${formatLiters(testing.diesel)}\nAdd to inventory: $addToInventory';
}

bool _shouldShowMismatchReason(ShiftEntryModel entry) {
  return entry.flagged && entry.mismatchAmount.abs() > 0;
}

Map<String, double> _settlementPaymentValues(ShiftEntryModel entry) {
  double pumpCash = 0;
  double pumpCheck = 0;
  double pumpUpi = 0;
  double pumpCredit = 0;
  var hasPumpPaymentValues = false;

  for (final payment in entry.pumpPayments.values) {
    pumpCash += payment.cash;
    pumpCheck += payment.check;
    pumpUpi += payment.upi;
    pumpCredit += payment.credit;
    hasPumpPaymentValues =
        hasPumpPaymentValues ||
        payment.cash != 0 ||
        payment.check != 0 ||
        payment.upi != 0 ||
        payment.credit != 0;
  }

  final creditFromRows = entry.creditEntries.fold<double>(
    0,
    (sum, credit) => sum + credit.amount,
  );

  return {
    'Cash': entry.paymentBreakdown.cash + pumpCash,
    'HP Pay': entry.paymentBreakdown.check + pumpCheck,
    'UPI': entry.paymentBreakdown.upi + pumpUpi,
    'Credit': hasPumpPaymentValues ? pumpCredit : creditFromRows,
  };
}

List<String> _pumpIds(ShiftEntryModel entry) {
  final ids = <String>{
    ...entry.openingReadings.keys,
    ...entry.closingReadings.keys,
    ...entry.soldByPump.keys,
    ...entry.pumpAttendants.keys,
    ...entry.pumpTesting.keys,
    ...entry.pumpPayments.keys,
    ...entry.pumpCollections.keys,
  }.toList()..sort();
  return ids;
}

double _fuelPetrol(Object? totals) {
  if (totals is FuelTotals) {
    return totals.petrol;
  }
  if (totals is PumpReadings) {
    return totals.petrol;
  }
  return 0;
}

double _fuelDiesel(Object? totals) {
  if (totals is FuelTotals) {
    return totals.diesel;
  }
  if (totals is PumpReadings) {
    return totals.diesel;
  }
  return 0;
}

double _fuelTwoT(Object? totals) {
  if (totals is FuelTotals) {
    return totals.twoT;
  }
  if (totals is PumpReadings) {
    return totals.twoT;
  }
  return 0;
}

String _shiftCase(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return _notEntered;
  }
  return trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
}
