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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete fuel type?'),
        content: Text('Delete ${fuelType.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB91C1C),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
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

    final bool? save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Add Fuel Type' : 'Edit Fuel Type'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: idController,
                decoration: const InputDecoration(labelText: 'Id'),
              ),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: shortController,
                decoration: const InputDecoration(labelText: 'Short Name'),
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
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
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
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
      active: existing?.active ?? true,
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
        return ColoredBox(
          color: kClayBg,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: fuelTypes.length + (widget.embedded ? 1 : 0),
            itemBuilder: (context, index) {
              if (widget.embedded && index == 0) {
                return ClaySubHeader(
                  title: 'Fuel Types',
                  onBack: widget.onBack,
                  trailing: widget.canEdit
                      ? GestureDetector(
                          onTap: () => _openEditor(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFFB8C0DC,
                                  ).withValues(alpha: 0.65),
                                  offset: const Offset(4, 4),
                                  blurRadius: 10,
                                ),
                                const BoxShadow(
                                  color: Colors.white,
                                  offset: Offset(-3, -3),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add_rounded,
                                  size: 16,
                                  color: kClayPrimary,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Add',
                                  style: TextStyle(
                                    color: kClayPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : null,
                );
              }

              final fuelType = fuelTypes[widget.embedded ? index - 1 : index];
              return _FuelTypeCard(
                fuelType: fuelType,
                canEdit: widget.canEdit,
                onEdit: () => _openEditor(existing: fuelType),
                onDelete: () => _deleteFuelType(fuelType),
              );
            },
          ),
        );
      },
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: kClayBg,
      appBar: AppBar(backgroundColor: kClayBg, title: const Text('Fuel Types')),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: clayCardDecoration(radius: 22),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 6, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.local_gas_station_rounded,
                              color: color,
                              size: 21,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
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
                                const SizedBox(height: 5),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    _FuelTypePill(
                                      label: shortName,
                                      color: color,
                                      filled: true,
                                    ),
                                    if (createdAt.isNotEmpty)
                                      _FuelTypePill(
                                        label:
                                            'Added ${formatDateLabel(createdAt)}',
                                        color: const Color(0xFF5D6685),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 12),
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
                        const SizedBox(height: 12),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FuelTypePill extends StatelessWidget {
  const _FuelTypePill({
    required this.label,
    required this.color,
    this.filled = false,
  });

  final String label;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: filled ? Colors.white : color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
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
    final color = destructive ? const Color(0xFFB91C1C) : kClayPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: destructive
              ? const Color(0xFFFFEEF0)
              : const Color(0xFFECEFF8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: destructive
                ? const Color(0xFFF6C9CF)
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
