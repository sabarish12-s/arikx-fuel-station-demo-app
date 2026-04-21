import 'package:flutter/material.dart';

import '../models/auth_models.dart';
import 'day_setup_screen.dart';
import '../widgets/responsive_text.dart';
import 'flag_threshold_settings_screen.dart';
import 'fuel_price_update_requests_screen.dart';
import 'fuel_type_manager_screen.dart';
import 'inventory_planning_settings_screen.dart';
import 'station_settings_screen.dart';
import 'user_management_screen.dart';

class SettingsHomeScreen extends StatefulWidget {
  const SettingsHomeScreen({super.key, required this.user});

  final AuthUser user;

  @override
  State<SettingsHomeScreen> createState() => SettingsHomeScreenState();

  static void resetToHome(GlobalKey<SettingsHomeScreenState> key) {
    key.currentState?._showHome();
  }
}

class SettingsHomeScreenState extends State<SettingsHomeScreen> {
  bool get _isSuperAdmin => widget.user.role == 'superadmin';
  bool get _canEditFuelTypes =>
      widget.user.role == 'admin' || widget.user.role == 'superadmin';
  bool get _canEditStationSettings =>
      widget.user.role == 'admin' || widget.user.role == 'superadmin';
  bool get _canEditInventoryPlanning =>
      widget.user.role == 'admin' || widget.user.role == 'superadmin';

  _SettingsPanel _panel = _SettingsPanel.home;

  void _showHome() => setState(() => _panel = _SettingsPanel.home);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _panel == _SettingsPanel.home,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _panel == _SettingsPanel.home) return;
        _showHome();
      },
      child: _buildCurrentPanel(),
    );
  }

  Widget _buildCurrentPanel() {
    switch (_panel) {
      case _SettingsPanel.stationSettings:
        return StationSettingsScreen(
          canEdit: _canEditStationSettings,
          embedded: true,
          onBack: _showHome,
        );
      case _SettingsPanel.daySetup:
        return DaySetupScreen(
          canEdit: _isSuperAdmin,
          embedded: true,
          onBack: _showHome,
        );
      case _SettingsPanel.fuelPriceRequests:
        return FuelPriceUpdateRequestsScreen(
          canReview: _isSuperAdmin,
          embedded: true,
          onBack: _showHome,
        );
      case _SettingsPanel.inventoryPlanning:
        return InventoryPlanningSettingsScreen(
          canEdit: _canEditInventoryPlanning,
          embedded: true,
          onBack: _showHome,
        );
      case _SettingsPanel.fuelTypeManager:
        return FuelTypeManagerScreen(
          canEdit: _canEditFuelTypes,
          embedded: true,
          onBack: _showHome,
        );
      case _SettingsPanel.userManagement:
        return UserManagementScreen(
          currentUser: widget.user,
          embedded: true,
          onBack: _showHome,
        );
      case _SettingsPanel.flagThreshold:
        return FlagThresholdSettingsScreen(
          canEdit: _canEditStationSettings,
          embedded: true,
          onBack: _showHome,
        );
      case _SettingsPanel.home:
        return _buildHome();
    }
  }

  Widget _buildHome() {
    final name = widget.user.name.trim();
    final initial = (name.isNotEmpty ? name[0] : widget.user.email[0])
        .toUpperCase();
    final roleLabel =
        widget.user.role[0].toUpperCase() + widget.user.role.substring(1);

    return ColoredBox(
      color: const Color(0xFFECEFF8),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // ── Hero header ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFF1A3A7A), Color(0xFF0D2460)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0D2460).withValues(alpha: 0.45),
                  offset: const Offset(0, 10),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isNotEmpty ? name : widget.user.email,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          roleLabel,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // ── Station ──────────────────────────────────────────────
          const _SectionLabel(label: 'STATION'),
          const SizedBox(height: 10),
          _SettingsTile(
            title: 'Station Profile & Pumps',
            subtitle: 'Station details, code, city, and pump names',
            icon: Icons.location_city_rounded,
            iconColor: const Color(0xFF1A3A7A),
            onTap: () =>
                setState(() => _panel = _SettingsPanel.stationSettings),
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            title: 'Day Setup',
            subtitle: 'Opening readings, stock, and fuel prices from one date',
            icon: Icons.event_note_rounded,
            iconColor: const Color(0xFF2AA878),
            onTap: () => setState(() => _panel = _SettingsPanel.daySetup),
          ),

          const SizedBox(height: 20),

          // ── Finance ──────────────────────────────────────────────
          const _SectionLabel(label: 'FINANCE'),
          const SizedBox(height: 10),
          _SettingsTile(
            title: 'Variance Rules',
            subtitle: 'Difference limit that flags an entry',
            icon: Icons.flag_rounded,
            iconColor: const Color(0xFFCE5828),
            onTap: () => setState(() => _panel = _SettingsPanel.flagThreshold),
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            title: 'Fuel Price Approvals',
            subtitle: 'Approve sales-submitted price changes',
            icon: Icons.fact_check_outlined,
            iconColor: const Color(0xFF2AA878),
            onTap: () =>
                setState(() => _panel = _SettingsPanel.fuelPriceRequests),
          ),

          const SizedBox(height: 20),

          // ── Inventory ────────────────────────────────────────────
          const _SectionLabel(label: 'INVENTORY'),
          const SizedBox(height: 10),
          _SettingsTile(
            title: 'Reorder Alert Rules',
            subtitle: 'Lead time and alert timing for inventory',
            icon: Icons.inventory_2_rounded,
            iconColor: const Color(0xFF4858C8),
            onTap: () =>
                setState(() => _panel = _SettingsPanel.inventoryPlanning),
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            title: 'Fuel Types',
            subtitle: 'Fuel categories and labels used in the app',
            icon: Icons.local_gas_station_rounded,
            iconColor: const Color(0xFF2AA878),
            onTap: () =>
                setState(() => _panel = _SettingsPanel.fuelTypeManager),
          ),

          if (_isSuperAdmin) ...[
            const SizedBox(height: 20),

            // ── Access ─────────────────────────────────────────────
            const _SectionLabel(label: 'ACCESS'),
            const SizedBox(height: 10),
            _SettingsTile(
              title: 'Users & Roles',
              subtitle: 'Manage admin and station access',
              icon: Icons.manage_accounts_rounded,
              iconColor: const Color(0xFF4858C8),
              onTap: () =>
                  setState(() => _panel = _SettingsPanel.userManagement),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Section label ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xFF8A93B8),
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

// ─── Settings tile ─────────────────────────────────────────────────────────────
class _SettingsTile extends StatefulWidget {
  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  State<_SettingsTile> createState() => _SettingsTileState();
}

class _SettingsTileState extends State<_SettingsTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: _pressed
              ? [
                  BoxShadow(
                    color: const Color(0xFFB8C0DC).withValues(alpha: 0.3),
                    offset: const Offset(2, 2),
                    blurRadius: 5,
                  ),
                ]
              : [
                  BoxShadow(
                    color: const Color(0xFFB8C0DC).withValues(alpha: 0.75),
                    offset: const Offset(6, 6),
                    blurRadius: 16,
                  ),
                  const BoxShadow(
                    color: Colors.white,
                    offset: Offset(-5, -5),
                    blurRadius: 12,
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: widget.iconColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(widget.icon, color: widget.iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OneLineScaleText(
                    widget.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Color(0xFF1A2561),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.subtitle,
                    style: const TextStyle(
                      color: Color(0xFF8A93B8),
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFB8C0DC),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

enum _SettingsPanel {
  home,
  stationSettings,
  daySetup,
  fuelPriceRequests,
  inventoryPlanning,
  fuelTypeManager,
  flagThreshold,
  userManagement,
}
