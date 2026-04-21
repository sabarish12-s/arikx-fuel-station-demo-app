import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/inventory_service.dart';
import '../utils/formatters.dart';
import '../utils/user_facing_errors.dart';
import '../widgets/clay_widgets.dart';
import '../widgets/responsive_text.dart';

class FuelPriceUpdateRequestsScreen extends StatefulWidget {
  const FuelPriceUpdateRequestsScreen({
    super.key,
    required this.canReview,
    this.embedded = false,
    this.onBack,
  });

  final bool canReview;
  final bool embedded;
  final VoidCallback? onBack;

  @override
  State<FuelPriceUpdateRequestsScreen> createState() =>
      _FuelPriceUpdateRequestsScreenState();
}

class _FuelPriceUpdateRequestsScreenState
    extends State<FuelPriceUpdateRequestsScreen> {
  final InventoryService _inventoryService = InventoryService();

  DaySetupStateModel? _daySetupState;
  List<FuelPriceUpdateRequestModel> _requests = const [];
  bool _busy = false;
  String? _error;

  bool get _canSubmit => !widget.canReview;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        _inventoryService.fetchDaySetupState(forceRefresh: forceRefresh),
        _inventoryService.fetchFuelPriceUpdateRequests(
          forceRefresh: forceRefresh,
        ),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _daySetupState = results[0] as DaySetupStateModel;
        _requests = results[1] as List<FuelPriceUpdateRequestModel>;
      });
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
          _busy = false;
        });
      }
    }
  }

  StationDaySetupModel? _activeSetup() {
    final state = _daySetupState;
    if (state == null || state.setups.isEmpty) {
      return null;
    }
    final activeDate = state.activeSetupDate.trim();
    if (activeDate.isNotEmpty) {
      for (final setup in state.setups) {
        if (setup.effectiveDate == activeDate) {
          return setup;
        }
      }
    }
    final targetDate = state.allowedEntryDate.trim();
    final candidates = state.setups
        .where(
          (setup) =>
              targetDate.isEmpty ||
              setup.effectiveDate.compareTo(targetDate) <= 0,
        )
        .toList();
    return candidates.isEmpty ? state.setups.last : candidates.last;
  }

  Future<void> _openSubmitDialog() async {
    final state = _daySetupState;
    final setup = _activeSetup();
    if (state == null || setup == null || !state.setupExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Day setup must be completed before price changes.'),
        ),
      );
      return;
    }

    final result = await showDialog<_FuelPriceRequestDraft>(
      context: context,
      builder: (context) => _FuelPriceRequestDialog(
        effectiveDate: state.allowedEntryDate.trim().isEmpty
            ? setup.effectiveDate
            : state.allowedEntryDate,
        currentPrices: setup.fuelPrices,
      ),
    );
    if (result == null) {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _inventoryService.createFuelPriceUpdateRequest(
        effectiveDate: result.effectiveDate,
        fuelPrices: result.fuelPrices,
        note: result.note,
      );
      if (!mounted) {
        return;
      }
      await _load(forceRefresh: true);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fuel price request sent for approval.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = userFacingErrorMessage(error);
      });
    }
  }

  Future<void> _approve(FuelPriceUpdateRequestModel request) async {
    final confirmed = await showClayConfirmDialog(
      context: context,
      title: 'Approve Price Update',
      message:
          'Approve fuel price changes for ${formatDateLabel(request.effectiveDate)}? The active Day Setup prices and sales calculations will be updated.',
      confirmLabel: 'Approve',
      icon: Icons.check_circle_outline_rounded,
    );
    if (!confirmed) {
      return;
    }
    await _reviewRequest(
      request,
      approve: true,
      successMessage: 'Fuel price request approved.',
    );
  }

  Future<void> _reject(FuelPriceUpdateRequestModel request) async {
    final confirmed = await showClayConfirmDialog(
      context: context,
      title: 'Reject Price Update',
      message:
          'Reject the fuel price request for ${formatDateLabel(request.effectiveDate)}?',
      confirmLabel: 'Reject',
      icon: Icons.cancel_outlined,
      destructive: true,
    );
    if (!confirmed) {
      return;
    }
    await _reviewRequest(
      request,
      approve: false,
      successMessage: 'Fuel price request rejected.',
    );
  }

  Future<void> _reviewRequest(
    FuelPriceUpdateRequestModel request, {
    required bool approve,
    required String successMessage,
  }) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (approve) {
        await _inventoryService.approveFuelPriceUpdateRequest(request.id);
      } else {
        await _inventoryService.rejectFuelPriceUpdateRequest(request.id);
      }
      if (!mounted) {
        return;
      }
      await _load(forceRefresh: true);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = userFacingErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _daySetupState;
    final setup = _activeSetup();
    final pendingCount = _requests.where((request) => request.isPending).length;

    if (_busy && state == null) {
      return const Scaffold(
        backgroundColor: kClayBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final body = RefreshIndicator(
      onRefresh: () => _load(forceRefresh: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
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
                    const Expanded(
                      child: Text(
                        'Fuel Price Requests',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    if (_canSubmit)
                      _FuelPriceHeroActionPill(
                        onPressed: _busy || state?.setupExists != true
                            ? null
                            : _openSubmitDialog,
                        icon: const Icon(Icons.sell_outlined),
                        label: 'Request',
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _HeroInfoChip(
                        label: 'Day setup',
                        value: state?.setupExists == true
                            ? 'Ready'
                            : 'Required',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HeroInfoChip(
                        label: 'Effective date',
                        value: state?.allowedEntryDate.trim().isNotEmpty == true
                            ? formatDateLabel(state!.allowedEntryDate)
                            : 'Not available',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HeroInfoChip(
                        label: 'Pending',
                        value: '$pendingCount',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (setup != null) ...[
            const SizedBox(height: 14),
            _CurrentPricesCard(setup: setup),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFFB42318),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (_requests.isEmpty)
            const ClayCard(
              child: Text(
                'No fuel price requests yet.',
                style: TextStyle(color: kClaySub, fontWeight: FontWeight.w700),
              ),
            )
          else
            ..._requests.map(
              (request) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _FuelPriceRequestCard(
                  request: request,
                  canReview: widget.canReview && request.isPending,
                  onApprove: () => _approve(request),
                  onReject: () => _reject(request),
                ),
              ),
            ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: kClayBg,
      appBar: widget.embedded
          ? null
          : AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: kClayBg,
              title: const Text('Fuel Price Requests'),
            ),
      body: body,
    );
  }
}

class _FuelPriceRequestDraft {
  const _FuelPriceRequestDraft({
    required this.effectiveDate,
    required this.fuelPrices,
    required this.note,
  });

  final String effectiveDate;
  final Map<String, Map<String, double>> fuelPrices;
  final String note;
}

class _FuelPriceRequestDialog extends StatefulWidget {
  const _FuelPriceRequestDialog({
    required this.effectiveDate,
    required this.currentPrices,
  });

  final String effectiveDate;
  final Map<String, Map<String, double>> currentPrices;

  @override
  State<_FuelPriceRequestDialog> createState() =>
      _FuelPriceRequestDialogState();
}

class _FuelPriceRequestDialogState extends State<_FuelPriceRequestDialog> {
  late final TextEditingController _dateController;
  late final TextEditingController _petrolController;
  late final TextEditingController _dieselController;
  late final TextEditingController _twoTController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(text: widget.effectiveDate);
    _petrolController = TextEditingController(
      text: '${widget.currentPrices['petrol']?['sellingPrice'] ?? 0}',
    );
    _dieselController = TextEditingController(
      text: '${widget.currentPrices['diesel']?['sellingPrice'] ?? 0}',
    );
    _twoTController = TextEditingController(
      text: '${widget.currentPrices['two_t_oil']?['sellingPrice'] ?? 0}',
    );
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _dateController.dispose();
    _petrolController.dispose();
    _dieselController.dispose();
    _twoTController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double _valueOf(TextEditingController controller) {
    return double.tryParse(controller.text.trim()) ?? 0;
  }

  Map<String, Map<String, double>> _requestedPrices() {
    return {
      'petrol': {
        'costPrice': widget.currentPrices['petrol']?['costPrice'] ?? 0,
        'sellingPrice': _valueOf(_petrolController),
      },
      'diesel': {
        'costPrice': widget.currentPrices['diesel']?['costPrice'] ?? 0,
        'sellingPrice': _valueOf(_dieselController),
      },
      'two_t_oil': {
        'costPrice': widget.currentPrices['two_t_oil']?['costPrice'] ?? 0,
        'sellingPrice': _valueOf(_twoTController),
      },
    };
  }

  Widget _priceField({
    required String label,
    required TextEditingController controller,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      style: const TextStyle(color: kClayPrimary, fontWeight: FontWeight.w800),
      decoration: clayDialogInputDecoration(
        label: label,
        prefixIcon: const Icon(Icons.currency_rupee_rounded, color: kClaySub),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClayDialogShell(
      title: 'Fuel Price Request',
      subtitle: 'Enter the new selling prices for superadmin approval.',
      icon: Icons.sell_outlined,
      actions: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: kClayPrimary,
              side: BorderSide(color: kClayPrimary.withValues(alpha: 0.16)),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(
              _FuelPriceRequestDraft(
                effectiveDate: _dateController.text.trim(),
                fuelPrices: _requestedPrices(),
                note: _noteController.text.trim(),
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4D66A9),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Send'),
          ),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClayDialogSection(
            title: 'Effective date',
            child: TextField(
              controller: _dateController,
              readOnly: true,
              decoration: clayDialogInputDecoration(
                label: 'Sales date',
                prefixIcon: const Icon(Icons.event_rounded, color: kClaySub),
              ),
            ),
          ),
          const SizedBox(height: 14),
          ClayDialogSection(
            title: 'Requested selling prices',
            subtitle: 'Cost prices stay unchanged from the active Day Setup.',
            child: Column(
              children: [
                _priceField(
                  label: 'Petrol selling',
                  controller: _petrolController,
                ),
                const SizedBox(height: 10),
                _priceField(
                  label: 'Diesel selling',
                  controller: _dieselController,
                ),
                const SizedBox(height: 10),
                _priceField(
                  label: '2T oil selling',
                  controller: _twoTController,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ClayDialogSection(
            title: 'Reason',
            child: TextField(
              controller: _noteController,
              minLines: 2,
              maxLines: 4,
              decoration: clayDialogInputDecoration(
                label: 'Reason / note',
                hintText: 'Example: Price changed at station board',
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 22),
                  child: Icon(Icons.notes_rounded, color: kClaySub),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentPricesCard extends StatelessWidget {
  const _CurrentPricesCard({required this.setup});

  final StationDaySetupModel setup;

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Active setup prices (${formatDateLabel(setup.effectiveDate)})',
            style: const TextStyle(
              color: kClayPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PriceChip(
                  label: 'Petrol',
                  prices: setup.fuelPrices['petrol'],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PriceChip(
                  label: 'Diesel',
                  prices: setup.fuelPrices['diesel'],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PriceChip(
                  label: '2T Oil',
                  prices: setup.fuelPrices['two_t_oil'],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FuelPriceRequestCard extends StatelessWidget {
  const _FuelPriceRequestCard({
    required this.request,
    required this.canReview,
    required this.onApprove,
    required this.onReject,
  });

  final FuelPriceUpdateRequestModel request;
  final bool canReview;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final statusColor = request.isApproved
        ? const Color(0xFF2AA878)
        : request.isRejected
        ? const Color(0xFFB42318)
        : const Color(0xFFCE8A28);

    return ClayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  formatDateLabel(request.effectiveDate),
                  style: const TextStyle(
                    color: kClayPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  request.status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            request.requestedByName.trim().isEmpty
                ? 'Requested by sales'
                : 'Requested by ${request.requestedByName}',
            style: const TextStyle(
              color: kClaySub,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _PriceChangeRows(request: request),
          if (request.note.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              request.note,
              style: const TextStyle(
                color: kClayPrimary,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ],
          if (canReview) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PriceChangeRows extends StatelessWidget {
  const _PriceChangeRows({required this.request});

  final FuelPriceUpdateRequestModel request;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PriceChangeRow(
          label: 'Petrol',
          current: request.currentPrices['petrol']?['sellingPrice'] ?? 0,
          requested: request.requestedPrices['petrol']?['sellingPrice'] ?? 0,
        ),
        const SizedBox(height: 8),
        _PriceChangeRow(
          label: 'Diesel',
          current: request.currentPrices['diesel']?['sellingPrice'] ?? 0,
          requested: request.requestedPrices['diesel']?['sellingPrice'] ?? 0,
        ),
        const SizedBox(height: 8),
        _PriceChangeRow(
          label: '2T Oil',
          current: request.currentPrices['two_t_oil']?['sellingPrice'] ?? 0,
          requested: request.requestedPrices['two_t_oil']?['sellingPrice'] ?? 0,
        ),
      ],
    );
  }
}

class _PriceChangeRow extends StatelessWidget {
  const _PriceChangeRow({
    required this.label,
    required this.current,
    required this.requested,
  });

  final String label;
  final double current;
  final double requested;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FD),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: kClayPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            '${formatCurrency(current)} -> ${formatCurrency(requested)}',
            style: const TextStyle(
              color: kClayPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _FuelPriceHeroActionPill extends StatelessWidget {
  const _FuelPriceHeroActionPill({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  final Widget icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return GestureDetector(
      onTap: onPressed,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconTheme(
                data: const IconThemeData(color: Colors.white, size: 16),
                child: icon,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroInfoChip extends StatelessWidget {
  const _HeroInfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          OneLineScaleText(
            value,
            textAlign: TextAlign.center,
            alignment: Alignment.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceChip extends StatelessWidget {
  const _PriceChip({required this.label, required this.prices});

  final String label;
  final Map<String, double>? prices;

  @override
  Widget build(BuildContext context) {
    final selling = prices?['sellingPrice'] ?? 0;
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FD),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: kClaySub,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          OneLineScaleText(
            '${formatCurrency(selling)}/L',
            textAlign: TextAlign.center,
            alignment: Alignment.center,
            style: const TextStyle(
              color: kClayPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
