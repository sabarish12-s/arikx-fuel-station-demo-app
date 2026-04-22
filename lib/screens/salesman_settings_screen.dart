import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/inventory_service.dart';
import '../utils/user_facing_errors.dart';
import '../widgets/clay_widgets.dart';
import '../widgets/responsive_text.dart';

class SalesmanSettingsScreen extends StatefulWidget {
  const SalesmanSettingsScreen({
    super.key,
    required this.canEdit,
    this.embedded = false,
    this.onBack,
  });

  final bool canEdit;
  final bool embedded;
  final VoidCallback? onBack;

  @override
  State<SalesmanSettingsScreen> createState() => _SalesmanSettingsScreenState();
}

class _SalesmanSettingsScreenState extends State<SalesmanSettingsScreen> {
  final InventoryService _inventoryService = InventoryService();
  late Future<StationConfigModel> _future;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _inventoryService.fetchStationConfig();
  }

  Future<void> _reload({bool forceRefresh = true}) async {
    setState(() {
      _future = _inventoryService.fetchStationConfig(forceRefresh: forceRefresh);
    });
    await _future;
  }

  Future<void> _saveSalesmen(List<StationSalesmanModel> salesmen) async {
    setState(() => _saving = true);
    try {
      await _inventoryService.saveSalesmen(salesmen);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Salesman settings saved.')),
      );
      await _reload();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFB91C1C),
          content: Text(userFacingErrorMessage(error)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _toggleActive(
    StationConfigModel station,
    StationSalesmanModel salesman,
  ) async {
    final nextSalesmen = station.salesmen
        .map(
          (item) => item.id == salesman.id
              ? item.copyWith(active: !item.active)
              : item,
        )
        .toList();
    await _saveSalesmen(nextSalesmen);
  }

  Future<void> _openEditor(
    StationConfigModel station, {
    StationSalesmanModel? existing,
  }) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final codeController = TextEditingController(text: existing?.code ?? '');
    var active = existing?.active ?? true;
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<StationSalesmanModel>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add Salesman' : 'Edit Salesman'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Salesman name',
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Enter salesman name.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Unique code',
                    helperText: 'Duplicate names are allowed. Code must be unique.',
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Enter salesman code.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: active,
                  title: const Text('Active'),
                  subtitle: const Text('Inactive salesmen stay in history but are hidden for new selection.'),
                  onChanged: (value) => setDialogState(() => active = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) {
                  return;
                }
                Navigator.of(dialogContext).pop(
                  StationSalesmanModel(
                    id: existing?.id ?? '',
                    name: nameController.text.trim(),
                    code: codeController.text.trim().toUpperCase(),
                    active: active,
                    createdAt: existing?.createdAt ?? '',
                    updatedAt: existing?.updatedAt ?? '',
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    codeController.dispose();

    if (saved == null) {
      return;
    }

    final nextSalesmen = [
      for (final salesman in station.salesmen)
        if (existing == null || salesman.id != existing.id) salesman,
      saved,
    ]..sort((left, right) => left.displayLabel.compareTo(right.displayLabel));
    await _saveSalesmen(nextSalesmen);
  }

  @override
  Widget build(BuildContext context) {
    final body = FutureBuilder<StationConfigModel>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done &&
            !snapshot.hasData) {
          return const ColoredBox(
            color: kClayBg,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError && !snapshot.hasData) {
          return ColoredBox(
            color: kClayBg,
            child: Center(child: Text(userFacingErrorMessage(snapshot.error))),
          );
        }

        final station = snapshot.data!;
        final activeSalesmen = station.salesmen.where((item) => item.active).toList()
          ..sort((left, right) => left.displayLabel.compareTo(right.displayLabel));
        final inactiveSalesmen = station.salesmen.where((item) => !item.active).toList()
          ..sort((left, right) => left.displayLabel.compareTo(right.displayLabel));

        return RefreshIndicator(
          onRefresh: _reload,
          child: ColoredBox(
            color: kClayBg,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                if (widget.embedded) ...[
                  _SalesmanHeroCard(
                    canEdit: widget.canEdit,
                    onBack: widget.onBack,
                  ),
                  const SizedBox(height: 14),
                ],
                ClayCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Active Salesmen',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: kClayPrimary,
                              ),
                            ),
                          ),
                          if (widget.canEdit)
                            FilledButton.icon(
                              onPressed:
                                  _saving ? null : () => _openEditor(station),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Add'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        activeSalesmen.isEmpty
                            ? 'No active salesmen configured. Add them here before daily sales entry.'
                            : 'These records are available in daily sales entry and account settings.',
                        style: const TextStyle(
                          color: kClaySub,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_saving) ...[
                        const SizedBox(height: 12),
                        const LinearProgressIndicator(minHeight: 2),
                      ],
                      const SizedBox(height: 14),
                      if (activeSalesmen.isEmpty)
                        const Text(
                          'No active salesmen.',
                          style: TextStyle(
                            color: kClaySub,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      else
                        ...activeSalesmen.map(
                          (salesman) => _SalesmanTile(
                            salesman: salesman,
                            canEdit: widget.canEdit,
                            onEdit: _saving
                                ? null
                                : () => _openEditor(station, existing: salesman),
                            onToggle: _saving
                                ? null
                                : () => _toggleActive(station, salesman),
                          ),
                        ),
                    ],
                  ),
                ),
                if (inactiveSalesmen.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  ClayCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Inactive Salesmen',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: kClayPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Inactive records remain available for historical entries and can be reactivated later.',
                          style: TextStyle(
                            color: kClaySub,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ...inactiveSalesmen.map(
                          (salesman) => _SalesmanTile(
                            salesman: salesman,
                            canEdit: widget.canEdit,
                            onEdit: _saving
                                ? null
                                : () => _openEditor(station, existing: salesman),
                            onToggle: _saving
                                ? null
                                : () => _toggleActive(station, salesman),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      backgroundColor: kClayBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: kClayBg,
        title: const Text('Salesmen'),
      ),
      body: body,
    );
  }
}

class _SalesmanHeroCard extends StatelessWidget {
  const _SalesmanHeroCard({
    required this.canEdit,
    this.onBack,
  });

  final bool canEdit;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'SETTINGS',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                SizedBox(height: 8),
                OneLineScaleText(
                  'Salesman List',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SalesmanTile extends StatelessWidget {
  const _SalesmanTile({
    required this.salesman,
    required this.canEdit,
    this.onEdit,
    this.onToggle,
  });

  final StationSalesmanModel salesman;
  final bool canEdit;
  final VoidCallback? onEdit;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kClayBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  salesman.displayLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: kClayPrimary,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: salesman.active
                      ? const Color(0xFFDFF7EC)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  salesman.active ? 'Active' : 'Inactive',
                  style: TextStyle(
                    color: salesman.active
                        ? const Color(0xFF0F8A73)
                        : const Color(0xFF6B7280),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Name: ${salesman.name}\nCode: ${salesman.code}',
            style: const TextStyle(
              color: kClaySub,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (canEdit) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onToggle,
                    icon: Icon(
                      salesman.active
                          ? Icons.visibility_off_outlined
                          : Icons.check_circle_outline,
                    ),
                    label: Text(salesman.active ? 'Deactivate' : 'Activate'),
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
