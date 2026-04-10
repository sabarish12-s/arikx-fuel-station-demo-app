import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/domain_models.dart';
import '../services/inventory_service.dart';
import '../utils/formatters.dart';
import '../widgets/clay_widgets.dart';

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
    _petrolController.addListener(_onQuantityChanged);
    _dieselController.addListener(_onQuantityChanged);
    _twoTController.addListener(_onQuantityChanged);
  }

  @override
  void dispose() {
    _petrolController.removeListener(_onQuantityChanged);
    _dieselController.removeListener(_onQuantityChanged);
    _twoTController.removeListener(_onQuantityChanged);
    _petrolController.dispose();
    _dieselController.dispose();
    _twoTController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onQuantityChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  String get _apiDate {
    final month = _selectedDate.month.toString().padLeft(2, '0');
    final day = _selectedDate.day.toString().padLeft(2, '0');
    return '${_selectedDate.year}-$month-$day';
  }

  double _parseQuantity(String raw) {
    return double.tryParse(raw.trim()) ?? 0;
  }

  double get _totalLiters =>
      _parseQuantity(_petrolController.text) +
      _parseQuantity(_dieselController.text) +
      _parseQuantity(_twoTController.text);

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

  Color _fuelColor(String id) {
    switch (id) {
      case 'diesel':
        return const Color(0xFF2AA878);
      case 'two_t_oil':
        return const Color(0xFF7048A8);
      default:
        return const Color(0xFF1298B8);
    }
  }

  String _fuelLabel(String id) {
    switch (id) {
      case 'diesel':
        return 'Diesel';
      case 'two_t_oil':
        return '2T Oil';
      default:
        return 'Petrol';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kClayBg,
      appBar: AppBar(
        backgroundColor: kClayBg,
        iconTheme: const IconThemeData(color: kClayPrimary),
        title: const Text('Delivery Receipt'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
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
                Text(
                  formatDateLabel(_apiDate),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Received Stock',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatLiters(_totalLiters)} total liters',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _ReceiptSectionLabel(label: 'DATE & DELIVERY'),
          const SizedBox(height: 10),
          ClayCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Record the normal tanker arrival with petrol and diesel together. Record 2T oil in a separate receipt when it arrives independently.',
                  style: TextStyle(
                    color: kClaySub,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: _saving ? null : _pickDate,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: kClayBg,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: kClayHeroStart.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.event_rounded,
                            color: kClayHeroStart,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'DELIVERY DATE',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                  color: kClaySub,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formatDateLabel(_apiDate),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: kClayPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: kClaySub,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _ReceiptSectionLabel(label: 'QUANTITIES'),
          const SizedBox(height: 10),
          ClayCard(
            child: Column(
              children: [
                _QuantityField(
                  label: _fuelLabel('petrol'),
                  color: _fuelColor('petrol'),
                  controller: _petrolController,
                  enabled: !_saving,
                ),
                const SizedBox(height: 12),
                _QuantityField(
                  label: _fuelLabel('diesel'),
                  color: _fuelColor('diesel'),
                  controller: _dieselController,
                  enabled: !_saving,
                ),
                const SizedBox(height: 12),
                _QuantityField(
                  label: _fuelLabel('two_t_oil'),
                  color: _fuelColor('two_t_oil'),
                  controller: _twoTController,
                  enabled: !_saving,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _ReceiptSectionLabel(label: 'NOTES'),
          const SizedBox(height: 10),
          ClayCard(
            child: TextField(
              controller: _noteController,
              enabled: !_saving,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Note (optional)',
                filled: true,
                fillColor: _saving ? const Color(0xFFE8EBF4) : kClayBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Saving...' : 'Record Delivery'),
            style: FilledButton.styleFrom(
              backgroundColor: kClayHeroStart,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptSectionLabel extends StatelessWidget {
  const _ReceiptSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: kClaySub,
        letterSpacing: 1.1,
      ),
    );
  }
}

class _QuantityField extends StatelessWidget {
  const _QuantityField({
    required this.label,
    required this.color,
    required this.controller,
    required this.enabled,
  });

  final String label;
  final Color color;
  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.local_gas_station_rounded, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(
              labelText: '$label delivered liters',
              filled: true,
              fillColor: enabled ? kClayBg : const Color(0xFFE8EBF4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
