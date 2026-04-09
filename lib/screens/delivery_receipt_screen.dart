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
  final TextEditingController _petrolController = TextEditingController();
  final TextEditingController _dieselController = TextEditingController();
  final TextEditingController _twoTController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  late DateTime _selectedDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  void dispose() {
    _petrolController.dispose();
    _dieselController.dispose();
    _twoTController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String get _apiDate {
    final month = _selectedDate.month.toString().padLeft(2, '0');
    final day = _selectedDate.day.toString().padLeft(2, '0');
    return '${_selectedDate.year}-$month-$day';
  }

  double _parseQuantity(String raw) {
    return double.tryParse(raw.trim()) ?? 0;
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
    final petrol = _parseQuantity(_petrolController.text);
    final diesel = _parseQuantity(_dieselController.text);
    final twoT = _parseQuantity(_twoTController.text);

    if (petrol < 0 || diesel < 0 || twoT < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFB91C1C),
          content: Text('Delivery quantities cannot be negative.'),
        ),
      );
      return;
    }
    final hasMainDelivery = petrol > 0 || diesel > 0;
    final hasTwoTDelivery = twoT > 0;
    if (!hasMainDelivery && !hasTwoTDelivery) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFB91C1C),
          content: Text(
            'Enter at least one delivery quantity greater than zero.',
          ),
        ),
      );
      return;
    }
    if (hasMainDelivery && hasTwoTDelivery) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFB91C1C),
          content: Text('Record 2T oil in a separate delivery receipt.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _inventoryService.createDeliveryReceipt(
        date: _apiDate,
        quantities: {'petrol': petrol, 'diesel': diesel, 'two_t_oil': twoT},
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
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
                  'Record the normal tanker arrival with petrol and diesel together. Record 2T oil in a separate receipt when it arrives independently.',
                  style: TextStyle(color: Color(0xFF55606E), height: 1.4),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _saving ? null : _pickDate,
                  borderRadius: BorderRadius.circular(20),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.event_rounded,
                          color: Color(0xFF1E5CBA),
                        ),
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
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Main tanker delivery',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF293340),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Enter petrol and diesel together for the same tanker arrival.',
                        style: TextStyle(color: Color(0xFF55606E), height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _petrolController,
                        enabled: !_saving,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Petrol delivered liters',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _dieselController,
                        enabled: !_saving,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Diesel delivered liters',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '2T oil delivery',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF293340),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Record 2T oil separately when it arrives on its own.',
                        style: TextStyle(color: Color(0xFF55606E), height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _twoTController,
                        enabled: !_saving,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        decoration: InputDecoration(
                          labelText: '2T oil delivered liters',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
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
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
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
                  label: Text(_saving ? 'Saving...' : 'Record Delivery'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
