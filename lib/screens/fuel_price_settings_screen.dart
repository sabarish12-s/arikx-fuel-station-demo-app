import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/inventory_service.dart';

class FuelPriceSettingsScreen extends StatefulWidget {
  const FuelPriceSettingsScreen({
    super.key,
    required this.canEdit,
  });

  final bool canEdit;

  @override
  State<FuelPriceSettingsScreen> createState() => _FuelPriceSettingsScreenState();
}

class _FuelPriceSettingsScreenState extends State<FuelPriceSettingsScreen> {
  final InventoryService _inventoryService = InventoryService();
  final Map<String, TextEditingController> _controllers = {};
  late Future<List<FuelPriceModel>> _future;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _future = _inventoryService.fetchPrices();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _seedControllers(List<FuelPriceModel> prices) {
    for (final price in prices) {
      _controllers.putIfAbsent(
        '${price.fuelTypeId}_cost',
        () => TextEditingController(text: price.costPrice.toStringAsFixed(2)),
      );
      _controllers.putIfAbsent(
        '${price.fuelTypeId}_sell',
        () => TextEditingController(text: price.sellingPrice.toStringAsFixed(2)),
      );
    }
  }

  void _resetControllers(List<FuelPriceModel> prices) {
    for (final price in prices) {
      _controllers['${price.fuelTypeId}_cost']?.text =
          price.costPrice.toStringAsFixed(2);
      _controllers['${price.fuelTypeId}_sell']?.text =
          price.sellingPrice.toStringAsFixed(2);
    }
  }

  Future<void> _save(List<FuelPriceModel> prices) async {
    final updated = prices
        .map(
          (price) => FuelPriceModel(
            fuelTypeId: price.fuelTypeId,
            costPrice:
                double.tryParse(_controllers['${price.fuelTypeId}_cost']?.text ?? '') ??
                price.costPrice,
            sellingPrice:
                double.tryParse(_controllers['${price.fuelTypeId}_sell']?.text ?? '') ??
                price.sellingPrice,
            updatedAt: price.updatedAt,
            updatedBy: price.updatedBy,
          ),
        )
        .toList();
    await _inventoryService.savePrices(updated);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fuel prices saved.')),
    );
    setState(() {
      _isEditing = false;
      _future = _inventoryService.fetchPrices();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fuel Price Settings'),
        actions: [
          if (widget.canEdit)
            FutureBuilder<List<FuelPriceModel>>(
              future: _future,
              builder: (context, snapshot) {
                final prices = snapshot.data ?? const <FuelPriceModel>[];
                return TextButton(
                  onPressed: prices.isEmpty
                      ? null
                      : () {
                          setState(() {
                            if (_isEditing) {
                              _isEditing = false;
                              _resetControllers(prices);
                            } else {
                              _isEditing = true;
                            }
                          });
                        },
                  child: Text(_isEditing ? 'Cancel' : 'Edit'),
                );
              },
            ),
        ],
      ),
      body: FutureBuilder<List<FuelPriceModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          final prices = snapshot.data ?? [];
          _seedControllers(prices);

          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fuel Pricing',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Prices open in view mode first. Tap Edit to unlock changes.',
                            style: TextStyle(color: Color(0xFF55606E)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _isEditing
                            ? const Color(0xFFE0E7FF)
                            : const Color(0xFFE5F7EE),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _isEditing ? 'Editing' : 'View only',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _isEditing
                              ? const Color(0xFF1E40AF)
                              : const Color(0xFF047857),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ...prices.map(
                (price) => Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        price.fuelTypeId.toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _controllers['${price.fuelTypeId}_cost'],
                        enabled: widget.canEdit && _isEditing,
                        decoration: const InputDecoration(labelText: 'Cost Price'),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _controllers['${price.fuelTypeId}_sell'],
                        enabled: widget.canEdit && _isEditing,
                        decoration: const InputDecoration(labelText: 'Selling Price'),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.canEdit && _isEditing)
                FilledButton(
                  onPressed: () => _save(prices),
                  child: const Text('Save All Price Settings'),
                ),
            ],
          );
        },
      ),
    );
  }
}
