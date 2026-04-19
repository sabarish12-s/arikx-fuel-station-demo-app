import 'package:flutter/material.dart';

import '../models/auth_models.dart';
import '../services/auth_service.dart';
import '../widgets/app_bottom_nav_bar.dart';
import '../widgets/app_logo.dart';
import '../widgets/clay_widgets.dart';
import 'inventory_hub_screen.dart';
import 'management_dashboard_screen.dart';
import 'entry_management_screen.dart';
import 'login_screen.dart';
import 'monthly_report_screen.dart';
import 'settings_home_screen.dart';

class ManagementShell extends StatefulWidget {
  const ManagementShell({super.key, required this.user});

  final AuthUser user;

  @override
  State<ManagementShell> createState() => _ManagementShellState();
}

class _ManagementShellState extends State<ManagementShell> {
  int _index = 0;
  int _entryRefreshToken = 0;
  final _settingsKey = GlobalKey<SettingsHomeScreenState>();
  final Set<int> _loadedScreens = {0};
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      ManagementDashboardScreen(user: widget.user),
      EntryManagementScreen(key: ValueKey(_entryRefreshToken)),
      const MonthlyReportScreen(),
      const InventoryHubScreen(
        canManagePlanning: true,
        showStockManagement: false,
      ),
      SettingsHomeScreen(key: _settingsKey, user: widget.user),
    ];
  }

  void _selectIndex(int value) {
    setState(() {
      if (value == 1 && _index != value) {
        _entryRefreshToken += 1;
        _screens[1] = EntryManagementScreen(key: ValueKey(_entryRefreshToken));
      }
      _index = value;
      _loadedScreens.add(value);
    });
  }

  Future<void> _logout() async {
    final shouldLogout = await showClayConfirmDialog(
      context: context,
      title: 'Logout',
      message: 'Are you sure you want to logout?',
      confirmLabel: 'Logout',
      icon: Icons.logout_rounded,
    );
    if (!shouldLogout) {
      return;
    }
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
    return Scaffold(
      backgroundColor: kClayBg,
      appBar: AppBar(
        backgroundColor: kClayBg,
        scrolledUnderElevation: 0,
        elevation: 0,
        iconTheme: const IconThemeData(color: kClayPrimary),
        title: Row(
          children: [
            const AppLogo(size: 28),
            const SizedBox(width: 8),
            Text(
              _titleForIndex(_index),
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: kClayPrimary,
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
      body: IndexedStack(
        index: _index,
        children: List.generate(
          _screens.length,
          (index) =>
              _loadedScreens.contains(index)
                  ? _screens[index]
                  : const SizedBox.shrink(),
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        selectedIndex: _index,
        onSelected: (value) {
          if (value == 4 && _index == 4) {
            SettingsHomeScreen.resetToHome(_settingsKey);
          } else {
            _selectIndex(value);
          }
        },
        items: const [
          AppBottomNavItem(icon: Icons.grid_view_rounded, label: 'Dashboard'),
          AppBottomNavItem(icon: Icons.edit_note_rounded, label: 'Entries'),
          AppBottomNavItem(icon: Icons.bar_chart_rounded, label: 'Reports'),
          AppBottomNavItem(
            icon: Icons.local_gas_station_outlined,
            label: 'Inventory',
          ),
          AppBottomNavItem(
            icon: Icons.manage_accounts_outlined,
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  String _titleForIndex(int index) {
    switch (index) {
      case 1:
        return 'Entries';
      case 2:
        return 'Reports';
      case 3:
        return 'Inventory';
      case 4:
        return 'Settings';
      default:
        return 'Dashboard';
    }
  }
}
