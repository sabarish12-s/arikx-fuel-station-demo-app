import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/inventory_service.dart';

class FuelTypeManagerScreen extends StatefulWidget {
  const FuelTypeManagerScreen({super.key, required this.canEdit});

  final bool canEdit;

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
    final shortController = TextEditingController(text: existing?.shortName ?? '');
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
              TextField(controller: idController, decoration: const InputDecoration(labelText: 'Id')),
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: shortController, decoration: const InputDecoration(labelText: 'Short Name')),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save')),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Fuel Type Manager')),
      floatingActionButton: widget.canEdit
          ? FloatingActionButton.extended(
              onPressed: () => _openEditor(),
              label: const Text('Add Fuel Type'),
              icon: const Icon(Icons.add),
            )
          : null,
      body: FutureBuilder<List<FuelTypeModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          final fuelTypes = snapshot.data ?? [];
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: fuelTypes.length,
            itemBuilder: (context, index) {
              final fuelType = fuelTypes[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fuelType.name,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
                    ),
                    const SizedBox(height: 6),
                    Text(fuelType.description),
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
      ),
    );
  }
}
