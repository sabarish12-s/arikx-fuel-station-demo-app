import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/inventory_service.dart';
import '../utils/user_facing_errors.dart';
import '../utils/formatters.dart';
import '../widgets/clay_widgets.dart';

class FuelTypeManagerScreen extends StatefulWidget {
  const FuelTypeManagerScreen({
    super.key,
    required this.canEdit,
    this.embedded = false,
    this.onBack,
  });

  final bool canEdit;
  final bool embedded;
  final VoidCallback? onBack;

  @override
  State<FuelTypeManagerScreen> createState() => _FuelTypeManagerScreenState();
}

class _FuelTypeManagerScreenState extends State<FuelTypeManagerScreen> {
  final InventoryService _inventoryService = InventoryService();
  late Future<List<FuelTypeModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _inventoryService.fetchFuelTypes();
  }

  void _reload() {
    setState(() {
      _future = _inventoryService.fetchFuelTypes(forceRefresh: true);
    });
  }

  Future<void> _deleteFuelType(FuelTypeModel fuelType) async {
    final confirmed = await showClayConfirmDialog(
      context: context,
      title: 'Delete Fuel Type',
      message: 'Delete ${fuelType.name}? This cannot be undone.',
      confirmLabel: 'Delete',
      icon: Icons.delete_outline_rounded,
      destructive: true,
    );
    if (!confirmed) return;
    await _inventoryService.deleteFuelType(fuelType.id);
    _reload();
  }

  Future<void> _openEditor({FuelTypeModel? existing}) async {
    final idController = TextEditingController(text: existing?.id ?? '');
    final nameController = TextEditingController(text: existing?.name ?? '');
    final shortController = TextEditingController(
      text: existing?.shortName ?? '',
    );
    final descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    bool isActive = existing?.active ?? true;

    final bool? save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => ClayDialogShell(
          title: existing == null ? 'Add Fuel Type' : 'Edit Fuel Type',
          subtitle:
              'Set the fuel id, name, short name, and display description.',
          icon: Icons.local_gas_station_rounded,
          accentColor: kClayPrimary,
          actions: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kClayPrimary,
                  side: BorderSide(color: kClayPrimary.withValues(alpha: 0.16)),
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
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4D66A9),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Save'),
              ),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClayDialogSection(
                title: 'Fuel details',
                subtitle:
                    'These values are used across stock, entries, and reports.',
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final split = constraints.maxWidth >= 420;
                    if (split) {
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: idController,
                                  decoration: clayDialogInputDecoration(
                                    label: 'Id',
                                    hintText: 'two_t_oil',
                                    prefixIcon: const Icon(
                                      Icons.tag_rounded,
                                      color: kClaySub,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: shortController,
                                  decoration: clayDialogInputDecoration(
                                    label: 'Short name',
                                    hintText: '2T',
                                    prefixIcon: const Icon(
                                      Icons.short_text_rounded,
                                      color: kClaySub,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: nameController,
                            decoration: clayDialogInputDecoration(
                              label: 'Name',
                              hintText: '2T Oil',
                              prefixIcon: const Icon(
                                Icons.local_offer_outlined,
                                color: kClaySub,
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        TextField(
                          controller: idController,
                          decoration: clayDialogInputDecoration(
                            label: 'Id',
                            hintText: 'two_t_oil',
                            prefixIcon: const Icon(
                              Icons.tag_rounded,
                              color: kClaySub,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: nameController,
                          decoration: clayDialogInputDecoration(
                            label: 'Name',
                            hintText: '2T Oil',
                            prefixIcon: const Icon(
                              Icons.local_offer_outlined,
                              color: kClaySub,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: shortController,
                          decoration: clayDialogInputDecoration(
                            label: 'Short name',
                            hintText: '2T',
                            prefixIcon: const Icon(
                              Icons.short_text_rounded,
                              color: kClaySub,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              ClayDialogSection(
                title: 'Status',
                subtitle: 'Choose whether this fuel type is active or inactive.',
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('Active'),
                      icon: Icon(Icons.check_circle_outline_rounded),
                    ),
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('Inactive'),
                      icon: Icon(Icons.pause_circle_outline_rounded),
                    ),
                  ],
                  selected: {isActive},
                  onSelectionChanged: (selection) {
                    setDialogState(() {
                      isActive = selection.first;
                    });
                  },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    textStyle: WidgetStatePropertyAll(
                      Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: kClayPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ClayDialogSection(
                title: 'Description',
                subtitle: 'Shown in settings and selection screens.',
                child: TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  minLines: 3,
                  decoration: clayDialogInputDecoration(
                    label: 'Description',
                    hintText: 'Describe where and how this fuel is used.',
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 38),
                      child: Icon(Icons.notes_rounded, color: kClaySub),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (save != true) return;

    final model = FuelTypeModel(
      id: idController.text.trim(),
      name: nameController.text.trim(),
      shortName: shortController.text.trim(),
      description: descriptionController.text.trim(),
      color: existing?.color ?? '#1E5CBA',
      icon: existing?.icon ?? 'local_gas_station',
      active: isActive,
      createdAt: existing?.createdAt ?? '',
    );

    if (existing == null) {
      await _inventoryService.createFuelType(model);
    } else {
      await _inventoryService.updateFuelType(model);
    }
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final content = FutureBuilder<List<FuelTypeModel>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(userFacingErrorMessage(snapshot.error)));
        }
        final fuelTypes = snapshot.data ?? [];
        final activeCount = fuelTypes.where((item) => item.active).length;
        final inactiveCount = fuelTypes.length - activeCount;
        return ColoredBox(
          color: kClayBg,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              if (widget.embedded) ...[
                _FuelTypeOverviewCard(
                  totalCount: fuelTypes.length,
                  activeCount: activeCount,
                  inactiveCount: inactiveCount,
                  canEdit: widget.canEdit,
                  onBack: widget.onBack,
                  onAdd: () => _openEditor(),
                ),
                const SizedBox(height: 14),
              ],
              ...fuelTypes.map(
                (fuelType) => _FuelTypeCard(
                  fuelType: fuelType,
                  canEdit: widget.canEdit,
                  onEdit: () => _openEditor(existing: fuelType),
                  onDelete: () => _deleteFuelType(fuelType),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: kClayBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: kClayBg,
        title: const Text('Fuel Types'),
      ),
      floatingActionButton: widget.canEdit
          ? FloatingActionButton.extended(
              onPressed: () => _openEditor(),
              label: const Text('Add Fuel Type'),
              icon: const Icon(Icons.add),
            )
          : null,
      body: RefreshIndicator(onRefresh: () async => _reload(), child: content),
    );
  }
}

class _FuelTypeCard extends StatelessWidget {
  const _FuelTypeCard({
    required this.fuelType,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  final FuelTypeModel fuelType;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = colorFromHex(fuelType.color);
    final createdAt = fuelType.createdAt.trim();
    final description = fuelType.description.trim();
    final shortName = fuelType.shortName.trim().isEmpty
        ? fuelType.id.toUpperCase()
        : fuelType.shortName.trim();

    return ClayCard(
      margin: const EdgeInsets.only(bottom: 12),
      radius: 22,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fuelType.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 17,
              color: kClayPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _FuelTypePill(label: shortName, accentColor: color),
              if (createdAt.isNotEmpty)
                _FuelTypePill(label: 'Added ${formatDateLabel(createdAt)}'),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: kClaySub,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
          if (canEdit) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _FuelTypeAction(
                    icon: Icons.edit_rounded,
                    label: 'Edit',
                    onTap: onEdit,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _FuelTypeAction(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete',
                    onTap: onDelete,
                    destructive: true,
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

class _FuelTypeOverviewCard extends StatelessWidget {
  const _FuelTypeOverviewCard({
    required this.totalCount,
    required this.activeCount,
    required this.inactiveCount,
    required this.canEdit,
    this.onBack,
    required this.onAdd,
  });

  final int totalCount;
  final int activeCount;
  final int inactiveCount;
  final bool canEdit;
  final VoidCallback? onBack;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF1A3A7A), Color(0xFF0D2460)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D2460).withValues(alpha: 0.32),
            offset: const Offset(0, 10),
            blurRadius: 22,
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
                  'Fuel Types',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              if (canEdit)
                _FuelTypeHeaderButton(
                  icon: Icons.add_rounded,
                  label: 'Add',
                  onTap: onAdd,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _FuelTypeStatTile(
                  title: 'Total Types',
                  value: '$totalCount',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FuelTypeStatTile(title: 'Active', value: '$activeCount'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FuelTypeStatTile(
                  title: 'Inactive',
                  value: '$inactiveCount',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FuelTypeHeaderButton extends StatelessWidget {
  const _FuelTypeHeaderButton({
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
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
    );
  }
}

class _FuelTypeStatTile extends StatelessWidget {
  const _FuelTypeStatTile({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _FuelTypePill extends StatelessWidget {
  const _FuelTypePill({required this.label, this.accentColor});

  final String label;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        accentColor?.withValues(alpha: 0.22) ?? const Color(0xFFDDE2F0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FD),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (accentColor != null) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF5D6685),
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _FuelTypeAction extends StatelessWidget {
  const _FuelTypeAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? const Color(0xFFAD5162) : kClayPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: destructive
              ? const Color(0xFFFFFBFC)
              : const Color(0xFFF7F8FD),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: destructive
                ? const Color(0xFFE7C6CF)
                : const Color(0xFFDDE2F0),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
