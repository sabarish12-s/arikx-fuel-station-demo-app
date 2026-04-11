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
      builder:
          (context) => AlertDialog(
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
                  trailing:
                      widget.canEdit
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
              final color = colorFromHex(fuelType.color);
              return ClayCard(
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.local_gas_station_rounded,
                            color: color,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            fuelType.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: kClayPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (fuelType.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        fuelType.description,
                        style: const TextStyle(color: kClaySub),
                      ),
                    ],
                    if (fuelType.createdAt.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Added on ${formatDateLabel(fuelType.createdAt)}',
                        style: const TextStyle(color: kClaySub, fontSize: 12),
                      ),
                    ],
                    if (widget.canEdit) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: () => _openEditor(existing: fuelType),
                            child: const Text('Edit'),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () async {
                              await _inventoryService.deleteFuelType(
                                fuelType.id,
                              );
                              _reload();
                            },
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
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
      floatingActionButton:
          widget.canEdit
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
