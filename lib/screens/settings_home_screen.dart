import 'package:flutter/material.dart';

import '../models/auth_models.dart';
import 'flag_threshold_settings_screen.dart';
import 'fuel_price_settings_screen.dart';
import 'fuel_type_manager_screen.dart';
import 'inventory_planning_settings_screen.dart';
import 'opening_stock_settings_screen.dart';
import 'station_settings_screen.dart';
import 'user_management_screen.dart';

class SettingsHomeScreen extends StatefulWidget {
  const SettingsHomeScreen({super.key, required this.user});

  final AuthUser user;

  @override
  State<SettingsHomeScreen> createState() => SettingsHomeScreenState();

  /// Call this to navigate back to the settings home panel from outside.
  static void resetToHome(GlobalKey<SettingsHomeScreenState> key) {
    key.currentState?._showHome();
  }
}

class SettingsHomeScreenState extends State<SettingsHomeScreen> {
  bool get _isSuperAdmin => widget.user.role == 'superadmin';
  bool get _canEditFuelTypes =>
      widget.user.role == 'admin' || widget.user.role == 'superadmin';
  bool get _canEditPrices =>
      widget.user.role == 'admin' || widget.user.role == 'superadmin';
  bool get _canEditStationSettings =>
      widget.user.role == 'admin' || widget.user.role == 'superadmin';
  bool get _canEditOpeningStock =>
      widget.user.role == 'admin' || widget.user.role == 'superadmin';
  bool get _canEditInventoryPlanning =>
      widget.user.role == 'admin' || widget.user.role == 'superadmin';

  _SettingsPanel _panel = _SettingsPanel.home;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _panel == _SettingsPanel.home,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _panel == _SettingsPanel.home) {
          return;
        }
        setState(() {
          _panel = _SettingsPanel.home;
        });
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
      case _SettingsPanel.openingStockSettings:
        return OpeningStockSettingsScreen(
          canEdit: _canEditOpeningStock,
          embedded: true,
          onBack: _showHome,
        );
      case _SettingsPanel.inventoryPlanning:
        return InventoryPlanningSettingsScreen(
          canEdit: _canEditInventoryPlanning,
          embedded: true,
          onBack: _showHome,
        );
      case _SettingsPanel.fuelPriceSettings:
        return FuelPriceSettingsScreen(
          canEdit: _canEditPrices,
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
        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            _SettingsTile(
              title: 'Station Profile & Pumps',
              subtitle: 'Station details, code, city, and pump names',
              icon: Icons.settings_suggest_outlined,
              onTap: () {
                setState(() {
                  _panel = _SettingsPanel.stationSettings;
                });
              },
            ),
            const SizedBox(height: 12),
            _SettingsTile(
              title: 'Pump Opening Readings',
              subtitle: 'Starting meter readings for each pump',
              icon: Icons.speed_outlined,
              onTap: () {
                setState(() {
                  _panel = _SettingsPanel.openingStockSettings;
                });
              },
            ),
            const SizedBox(height: 12),
            _SettingsTile(
              title: 'Tank Stock & Reorder Planning',
              subtitle: 'Tank stock baseline and reorder rules',
              icon: Icons.inventory_2_outlined,
              onTap: () {
                setState(() {
                  _panel = _SettingsPanel.inventoryPlanning;
                });
              },
            ),
            const SizedBox(height: 12),
            _SettingsTile(
              title: 'Fuel Prices',
              subtitle: 'Selling and cost prices for each fuel',
              icon: Icons.payments_outlined,
              onTap: () {
                setState(() {
                  _panel = _SettingsPanel.fuelPriceSettings;
                });
              },
            ),
            const SizedBox(height: 12),
            _SettingsTile(
              title: 'Fuel Types',
              subtitle: 'Fuel categories and labels used in the app',
              icon: Icons.category_outlined,
              onTap: () {
                setState(() {
                  _panel = _SettingsPanel.fuelTypeManager;
                });
              },
            ),
            const SizedBox(height: 12),
            _SettingsTile(
              title: 'Variance Rules',
              subtitle: 'Difference limit that flags an entry',
              icon: Icons.flag_outlined,
              onTap: () {
                setState(() {
                  _panel = _SettingsPanel.flagThreshold;
                });
              },
            ),
            if (_isSuperAdmin) ...[
              const SizedBox(height: 12),
              _SettingsTile(
                title: 'Users & Roles',
                subtitle: 'Manage admin and station access',
                icon: Icons.manage_accounts_outlined,
                onTap: () {
                  setState(() {
                    _panel = _SettingsPanel.userManagement;
                  });
                },
              ),
            ],
          ],
        );
    }
  }

  void _showHome() {
    setState(() {
      _panel = _SettingsPanel.home;
    });
  }
}

enum _SettingsPanel {
  home,
  stationSettings,
  openingStockSettings,
  inventoryPlanning,
  fuelPriceSettings,
  fuelTypeManager,
  flagThreshold,
  userManagement,
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFE9EEF7),
                child: Icon(icon, color: const Color(0xFF1E5CBA)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF293340),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF55606E),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
