import 'package:flutter/material.dart';

import '../models/auth_models.dart';
import '../services/auth_service.dart';
import '../widgets/app_logo.dart';
import 'fuel_price_settings_screen.dart';
import 'fuel_type_manager_screen.dart';
import 'inventory_hub_screen.dart';
import 'management_dashboard_screen.dart';
import 'entry_management_screen.dart';
import 'login_screen.dart';
import 'monthly_report_screen.dart';
import 'settings_home_screen.dart';
import 'user_management_screen.dart';

class ManagementShell extends StatefulWidget {
  const ManagementShell({super.key, required this.user});

  final AuthUser user;

  @override
  State<ManagementShell> createState() => _ManagementShellState();
}

class _ManagementShellState extends State<ManagementShell> {
  int _index = 0;

  bool get _isSuperAdmin => widget.user.role == 'superadmin';

  Future<void> _logout() async {
    await AuthService().signOut();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      ManagementDashboardScreen(
        user: widget.user,
        onOpenEntries: () => setState(() => _index = 1),
        onOpenReports: () => setState(() => _index = 2),
        onOpenInventory: () => setState(() => _index = 3),
        onOpenUsers: () => setState(() => _index = 4),
        onOpenSettings: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SettingsHomeScreen()),
          );
        },
      ),
      const EntryManagementScreen(),
      const MonthlyReportScreen(),
      InventoryHubScreen(
        canManage: _isSuperAdmin,
        onOpenFuelTypes: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => FuelTypeManagerScreen(canEdit: _isSuperAdmin),
            ),
          );
        },
        onOpenPrices: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => FuelPriceSettingsScreen(canEdit: _isSuperAdmin),
            ),
          );
        },
        onOpenSettings: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SettingsHomeScreen()),
          );
        },
      ),
      _isSuperAdmin ? const UserManagementScreen() : const SettingsHomeScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.9),
        elevation: 0,
        title: Row(
          children: [
            const AppLogo(size: 28),
            const SizedBox(width: 8),
            Text(
              _titleForIndex(_index),
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: Color(0xFF293340),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.edit_note_rounded),
            label: 'Entries',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_rounded),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_gas_station_outlined),
            label: 'Inventory',
          ),
          NavigationDestination(
            icon: Icon(Icons.manage_accounts_outlined),
            label: 'Access',
          ),
        ],
      ),
    );
  }

  String _titleForIndex(int index) {
    switch (index) {
      case 1:
        return 'Entry Management';
      case 2:
        return 'Monthly Report';
      case 3:
        return 'Inventory';
      case 4:
        return _isSuperAdmin ? 'Users & Settings' : 'Station Settings';
      default:
        return 'RK Fuels Admin';
    }
  }
}
