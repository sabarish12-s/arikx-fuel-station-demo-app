import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/inventory_service.dart';
import '../utils/formatters.dart';

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
      _future = _inventoryService.fetchFuelTypes();
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
          return Center(
            child: Text(
              snapshot.error.toString().replaceFirst('Exception: ', ''),
            ),
          );
        }
        final fuelTypes = snapshot.data ?? [];
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: fuelTypes.length + (widget.embedded ? 1 : 0),
          itemBuilder: (context, index) {
            if (widget.embedded && index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const Expanded(
                      child: Text(
                        'Fuel Types',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF293340),
                        ),
                      ),
                    ),
                    if (widget.canEdit)
                      FilledButton.icon(
                        onPressed: () => _openEditor(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
                      ),
                  ],
                ),
              );
            }

            final fuelType = fuelTypes[widget.embedded ? index - 1 : index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fuelType.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(fuelType.description),
                  if (fuelType.createdAt.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Added on ${formatDateLabel(fuelType.createdAt)}',
                      style: const TextStyle(color: Color(0xFF55606E)),
                    ),
                  ],
                  const SizedBox(height: 10),
                  if (widget.canEdit)
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: () => _openEditor(existing: fuelType),
                          child: const Text('Edit'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () async {
                            await _inventoryService.deleteFuelType(fuelType.id);
                            _reload();
                          },
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                ],
              ),
            );
          },
        );
      },
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Fuel Types')),
      floatingActionButton: widget.canEdit
          ? FloatingActionButton.extended(
              onPressed: () => _openEditor(),
              label: const Text('Add Fuel Type'),
              icon: const Icon(Icons.add),
            )
          : null,
      body: content,
    );
  }
}
