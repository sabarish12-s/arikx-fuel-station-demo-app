import 'package:flutter/material.dart';

import '../models/domain_models.dart';
import '../services/sales_service.dart';
import '../utils/formatters.dart';

class ClosingStockEntryScreen extends StatefulWidget {
  const ClosingStockEntryScreen({super.key});

  @override
  State<ClosingStockEntryScreen> createState() => _ClosingStockEntryScreenState();
}

class _ClosingStockEntryScreenState extends State<ClosingStockEntryScreen> {
  final SalesService _salesService = SalesService();
  final Map<String, TextEditingController> _controllers = {};
  SalesDashboardModel? _dashboard;
  String? _selectedShift;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final dashboard = await _salesService.fetchDashboard();
      if (!mounted) return;
      for (final controller in _controllers.values) {
        controller.dispose();
      }
      _controllers.clear();
      for (final entry in dashboard.nextOpeningReadings.entries) {
        _controllers['${entry.key}_petrol'] = TextEditingController(
          text: entry.value.petrol.toStringAsFixed(2),
        );
        _controllers['${entry.key}_diesel'] = TextEditingController(
          text: entry.value.diesel.toStringAsFixed(2),
        );
      }
      setState(() {
        _dashboard = dashboard;
        _selectedShift = dashboard.nextShift;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _submit() async {
    final dashboard = _dashboard;
    if (dashboard == null || _selectedShift == null) {
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final readings = <String, PumpReadings>{};
      for (final pump in dashboard.station.pumps) {
        readings[pump.id] = PumpReadings(
          petrol: double.tryParse(
                _controllers['${pump.id}_petrol']?.text ?? '',
              ) ??
              0,
          diesel: double.tryParse(
                _controllers['${pump.id}_diesel']?.text ?? '',
              ) ??
              0,
        );
      }

      await _salesService.submitEntry(
        date: dashboard.date,
        shift: _selectedShift!,
        closingReadings: readings,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shift entry submitted successfully.')),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = _dashboard;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(title: const Text('Closing Stock Entry')),
      body: dashboard == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Text(_error!, textAlign: TextAlign.center),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Today's Opening Stock",
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF55606E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${dashboard.station.name} - ${formatDateLabel(dashboard.date)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF293340),
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedShift,
                        decoration: const InputDecoration(
                          labelText: 'Shift',
                          filled: true,
                        ),
                        items: dashboard.station.shifts
                            .map(
                              (shift) => DropdownMenuItem(
                                value: shift,
                                child: Text(formatShiftLabel(shift)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedShift = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ...dashboard.station.pumps.map(
                  (pump) => Container(
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
                          pump.label,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF293340),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _ReadingField(
                          label:
                              'Petrol closing stock - opening ${formatLiters(dashboard.nextOpeningReadings[pump.id]?.petrol ?? 0)}',
                          controller: _controllers['${pump.id}_petrol']!,
                          accent: const Color(0xFF1E5CBA),
                        ),
                        const SizedBox(height: 12),
                        _ReadingField(
                          label:
                              'Diesel closing stock - opening ${formatLiters(dashboard.nextOpeningReadings[pump.id]?.diesel ?? 0)}',
                          controller: _controllers['${pump.id}_diesel']!,
                          accent: const Color(0xFF006C5C),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Color(0xFFB91C1C)),
                    ),
                  ),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    backgroundColor: const Color(0xFF1E5CBA),
                  ),
                  child: Text(_submitting ? 'Submitting...' : 'Submit Entry'),
                ),
              ],
            ),
    );
  }
}

class _ReadingField extends StatelessWidget {
  const _ReadingField({
    required this.label,
    required this.controller,
    required this.accent,
  });

  final String label;
  final TextEditingController controller;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
