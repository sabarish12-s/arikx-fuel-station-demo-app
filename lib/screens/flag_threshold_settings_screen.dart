import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/domain_models.dart';
import '../services/inventory_service.dart';

class FlagThresholdSettingsScreen extends StatefulWidget {
  const FlagThresholdSettingsScreen({
    super.key,
    required this.canEdit,
    this.embedded = false,
    this.onBack,
  });

  final bool canEdit;
  final bool embedded;
  final VoidCallback? onBack;

  @override
  State<FlagThresholdSettingsScreen> createState() =>
      _FlagThresholdSettingsScreenState();
}

class _FlagThresholdSettingsScreenState
    extends State<FlagThresholdSettingsScreen> {
  final InventoryService _inventoryService = InventoryService();
  late Future<StationConfigModel> _future;
  final TextEditingController _thresholdController = TextEditingController();
  bool _seeded = false;
  bool _isEditing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _inventoryService.fetchStationConfig();
  }

  @override
  void dispose() {
    _thresholdController.dispose();
    super.dispose();
  }

  void _seedController(StationConfigModel station) {
    if (_seeded) return;
    _thresholdController.text = station.flagThreshold.toStringAsFixed(2);
    _seeded = true;
  }

  Future<void> _save(StationConfigModel station) async {
    final value = double.tryParse(_thresholdController.text.trim());
    if (value == null || value < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFB91C1C),
          content: Text('Enter a valid amount (0 or greater).'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final updated = StationConfigModel(
        id: station.id,
        name: station.name,
        code: station.code,
        city: station.city,
        shifts: station.shifts,
        pumps: station.pumps,
        baseReadings: station.baseReadings,
        meterLimits: station.meterLimits,
        flagThreshold: value,
      );
      await _inventoryService.saveStationConfig(updated);
      if (!mounted) return;
      setState(() {
        _isEditing = false;
        _seeded = false;
        _future = _inventoryService.fetchStationConfig();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Flag threshold saved.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFB91C1C),
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StationConfigModel>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [Text('Failed to load: ${snapshot.error}')],
          );
        }

        final station = snapshot.data!;
        _seedController(station);

        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            if (widget.embedded && widget.onBack != null)
              TextButton.icon(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Back to Settings'),
              ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  colors: [Color(0xFF153A8A), Color(0xFF1E5CBA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'FLAG THRESHOLD',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹${station.flagThreshold.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Entries with a payment–revenue difference at or above this amount are flagged for review.',
                    style: TextStyle(color: Colors.white70, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Mismatch Threshold',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF293340),
                          ),
                        ),
                      ),
                      if (widget.canEdit && !_isEditing)
                        FilledButton.icon(
                          onPressed: () => setState(() => _isEditing = true),
                          icon: const Icon(Icons.edit_rounded),
                          label: const Text('Edit'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Set the minimum difference (in ₹) between collected payment and computed revenue that triggers a flag.',
                    style: TextStyle(color: Color(0xFF55606E), height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  if (_isEditing) ...[
                    TextFormField(
                      controller: _thresholdController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'),
                        ),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Threshold amount (₹)',
                        filled: true,
                        fillColor: const Color(0xFFF8F9FF),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        prefixText: '₹ ',
                        helperText:
                            'Set to 0 to flag every entry with any difference.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        TextButton(
                          onPressed:
                              _saving
                                  ? null
                                  : () {
                                    setState(() {
                                      _isEditing = false;
                                      _seeded = false;
                                      _thresholdController.text =
                                          station.flagThreshold
                                              .toStringAsFixed(2);
                                      _seeded = true;
                                    });
                                  },
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          onPressed: _saving ? null : () => _save(station),
                          icon: const Icon(Icons.save_rounded),
                          label: Text(_saving ? 'Saving…' : 'Save'),
                        ),
                      ],
                    ),
                  ] else ...[
                    _InfoRow(
                      label: 'Current threshold',
                      value: '₹${station.flagThreshold.toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      label: 'Effect',
                      value:
                          station.flagThreshold == 0
                              ? 'Every mismatch is flagged'
                              : 'Differences below ₹${station.flagThreshold.toStringAsFixed(2)} are ignored',
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
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
                    'How flagging works',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF293340),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _BulletRow(
                    icon: Icons.flag_rounded,
                    color: const Color(0xFFB91C1C),
                    text:
                        'An entry is flagged when the difference between collected payment and computed revenue is ≥ the threshold.',
                  ),
                  const SizedBox(height: 8),
                  _BulletRow(
                    icon: Icons.check_circle_rounded,
                    color: const Color(0xFF0F9D58),
                    text:
                        'Approving an entry clears its flag — approved entries are never shown as flagged.',
                  ),
                  const SizedBox(height: 8),
                  _BulletRow(
                    icon: Icons.warning_amber_rounded,
                    color: const Color(0xFFB45309),
                    text:
                        'Negative meter readings and limit breaches always flag an entry regardless of this threshold.',
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF55606E),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF293340),
            ),
          ),
        ),
      ],
    );
  }
}

class _BulletRow extends StatelessWidget {
  const _BulletRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(color: Color(0xFF55606E))),
        ),
      ],
    );
  }
}
