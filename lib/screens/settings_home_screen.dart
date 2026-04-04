import 'package:flutter/material.dart';

import '../models/auth_models.dart';
import 'fuel_price_settings_screen.dart';
import 'fuel_type_manager_screen.dart';
import 'station_settings_screen.dart';
import 'user_management_screen.dart';

class SettingsHomeScreen extends StatefulWidget {
  const SettingsHomeScreen({super.key, required this.user});

  final AuthUser user;

  @override
  State<SettingsHomeScreen> createState() => _SettingsHomeScreenState();
}

class _SettingsHomeScreenState extends State<SettingsHomeScreen> {
  bool get _isSuperAdmin => widget.user.role == 'superadmin';
  bool get _canEditFuelTypes =>
      widget.user.role == 'admin' || widget.user.role == 'superadmin';
  bool get _canEditPrices =>
      widget.user.role == 'admin' || widget.user.role == 'superadmin';
  bool get _canEditStationSettings =>
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
      case _SettingsPanel.home:
        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text(
              'Manage station setup, pricing, fuel catalog, and access controls.',
              style: TextStyle(color: Color(0xFF55606E)),
            ),
            const SizedBox(height: 16),
            _SettingsTile(
              title: 'Station Settings',
              subtitle:
                  _canEditStationSettings
                      ? 'View station setup first, then edit labels and shifts when needed'
                      : 'View station layout, shifts, and fixed pump configuration',
              icon: Icons.settings_suggest_outlined,
              onTap: () {
                setState(() {
                  _panel = _SettingsPanel.stationSettings;
                });
              },
            ),
            const SizedBox(height: 12),
            _SettingsTile(
              title: 'Fuel Price Settings',
              subtitle:
                  _canEditPrices
                      ? 'Update cost and selling prices'
                      : 'View current fuel prices',
              icon: Icons.payments_outlined,
              onTap: () {
                setState(() {
                  _panel = _SettingsPanel.fuelPriceSettings;
                });
              },
            ),
            const SizedBox(height: 12),
            _SettingsTile(
              title: 'Fuel Type Manager',
              subtitle:
                  _canEditFuelTypes
                      ? 'Maintain the active fuel catalog'
                      : 'View available fuel types',
              icon: Icons.category_outlined,
              onTap: () {
                setState(() {
                  _panel = _SettingsPanel.fuelTypeManager;
                });
              },
            ),
            if (_isSuperAdmin) ...[
              const SizedBox(height: 12),
              _SettingsTile(
                title: 'User Management',
                subtitle: 'Approve requests and manage staff access',
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
  fuelPriceSettings,
  fuelTypeManager,
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
                    Text(
                      subtitle,
                      style: const TextStyle(color: Color(0xFF55606E)),
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
