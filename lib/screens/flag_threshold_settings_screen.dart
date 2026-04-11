import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/domain_models.dart';
import '../services/inventory_service.dart';
import '../utils/user_facing_errors.dart';
import '../widgets/responsive_text.dart';
import '../widgets/clay_widgets.dart';

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

  String _errorText(Object? error) {
    return userFacingErrorMessage(error);
  }

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
        inventoryPlanning: station.inventoryPlanning,
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
        const SnackBar(content: Text('Variance threshold saved.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFB91C1C),
          content: Text(userFacingErrorMessage(error)),
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
          return const ColoredBox(
            color: kClayBg,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return ColoredBox(
            color: kClayBg,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [Text('Failed to load: ${_errorText(snapshot.error)}')],
            ),
          );
        }

        final station = snapshot.data!;
        _seedController(station);

        return ColoredBox(
          color: kClayBg,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              if (widget.embedded && widget.onBack != null)
                ClaySubHeader(
                  title: 'Variance Rules',
                  onBack: widget.onBack,
                  trailing:
                      widget.canEdit && !_isEditing
                          ? _ClayEditButton(
                            onTap: () => setState(() => _isEditing = true),
                          )
                          : null,
                ),

              // ── Hero card ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
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
                    const Text(
                      'VARIANCE THRESHOLD',
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

              const SizedBox(height: 14),

              // ── Edit card ──────────────────────────────────────────
              ClayCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Variance Threshold',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: kClayPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Set the minimum difference (in ₹) between collected payment and computed revenue that triggers a flag.',
                      style: TextStyle(color: kClaySub, height: 1.4),
                    ),
                    const SizedBox(height: 16),
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
                          fillColor: kClayBg,
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
                                        _thresholdController.text = station
                                            .flagThreshold
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

              const SizedBox(height: 14),

              // ── How flagging works ─────────────────────────────────
              ClayCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'How flagging works',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: kClayPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _BulletRow(
                      icon: Icons.flag_rounded,
                      color: const Color(0xFFCE5828),
                      text:
                          'An entry is flagged when the difference between collected payment and computed revenue is ≥ the threshold.',
                    ),
                    const SizedBox(height: 8),
                    _BulletRow(
                      icon: Icons.check_circle_rounded,
                      color: const Color(0xFF2AA878),
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
          ),
        );
      },
    );
  }
}

// ─── Clay edit button pill ──────────────────────────────────────────────────
class _ClayEditButton extends StatelessWidget {
  const _ClayEditButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFB8C0DC).withValues(alpha: 0.65),
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
            Icon(Icons.edit_rounded, size: 15, color: kClayPrimary),
            SizedBox(width: 5),
            OneLineScaleText(
              'Edit',
              style: TextStyle(
                color: kClayPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Info row ───────────────────────────────────────────────────────────────
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
              color: kClaySub,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: kClayPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Bullet row ─────────────────────────────────────────────────────────────
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
          child: Text(
            text,
            style: const TextStyle(color: kClaySub, height: 1.4),
          ),
        ),
      ],
    );
  }
}
