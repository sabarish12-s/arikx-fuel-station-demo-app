import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/domain_models.dart';
import '../services/inventory_service.dart';
import '../utils/formatters.dart';

class DeliveryReceiptScreen extends StatefulWidget {
  const DeliveryReceiptScreen({
    super.key,
    required this.fuels,
    this.initialFuelTypeId,
  });

  final List<FuelInventoryForecastModel> fuels;
  final String? initialFuelTypeId;

  @override
  State<DeliveryReceiptScreen> createState() => _DeliveryReceiptScreenState();
}

class _DeliveryReceiptScreenState extends State<DeliveryReceiptScreen> {
  final InventoryService _inventoryService = InventoryService();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  late String _selectedFuelTypeId;
  late DateTime _selectedDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedFuelTypeId =
        widget.initialFuelTypeId ??
        (widget.fuels.isNotEmpty ? widget.fuels.first.fuelTypeId : 'petrol');
    _selectedDate = DateTime.now();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String get _apiDate {
    final month = _selectedDate.month.toString().padLeft(2, '0');
    final day = _selectedDate.day.toString().padLeft(2, '0');
    return '${_selectedDate.year}-$month-$day';
  }

  String _fuelLabel(String fuelTypeId) {
    final match = widget.fuels.where((fuel) => fuel.fuelTypeId == fuelTypeId);
    if (match.isNotEmpty) {
      return match.first.label;
    }
    switch (fuelTypeId) {
      case 'petrol':
        return 'Petrol';
      case 'diesel':
        return 'Diesel';
      case 'two_t_oil':
        return '2T Oil';
      default:
        return fuelTypeId;
    }
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
      helpText: 'Select delivery date',
    );
    if (selected == null) {
      return;
    }
    setState(() {
      _selectedDate = selected;
    });
  }

  Future<void> _save() async {
    final quantity = double.tryParse(_quantityController.text.trim());
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFB91C1C),
          content: Text('Enter a delivery quantity greater than zero.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _inventoryService.createDeliveryReceipt(
        fuelTypeId: _selectedFuelTypeId,
        date: _apiDate,
        quantity: quantity,
        note: _noteController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery receipt recorded.')),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFB91C1C),
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Delivery Receipt'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Received Stock',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF293340),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Use this when stock physically arrives. The station tank stock forecast updates from this receipt.',
                  style: TextStyle(color: Color(0xFF55606E), height: 1.4),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  initialValue: _selectedFuelTypeId,
                  decoration: InputDecoration(
                    labelText: 'Fuel',
                    filled: true,
                    fillColor: const Color(0xFFF8F9FF),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items:
                      widget.fuels
                          .map(
                            (fuel) => DropdownMenuItem<String>(
                              value: fuel.fuelTypeId,
                              child: Text(fuel.label),
                            ),
                          )
                          .toList(),
                  onChanged:
                      _saving
                          ? null
                          : (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() => _selectedFuelTypeId = value);
                          },
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _saving ? null : _pickDate,
                  borderRadius: BorderRadius.circular(18),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FF),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_rounded, color: Color(0xFF1E5CBA)),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'DELIVERY DATE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.7,
                                color: Color(0xFF55606E),
                              ),
                            ),
                            Text(
                              formatDateLabel(_apiDate),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF293340),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _quantityController,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Delivered liters',
                    filled: true,
                    fillColor: const Color(0xFFF8F9FF),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteController,
                  enabled: !_saving,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Note (optional)',
                    filled: true,
                    fillColor: const Color(0xFFF8F9FF),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon:
                      _saving
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.save_outlined),
                  label: Text(
                    _saving
                        ? 'Saving...'
                        : 'Record ${_fuelLabel(_selectedFuelTypeId)} Delivery',
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
