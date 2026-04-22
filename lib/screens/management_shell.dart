import 'package:flutter/material.dart';

import '../models/auth_models.dart';
import '../services/auth_service.dart';
import '../services/inventory_service.dart';
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
  const ManagementShell({super.key, required this.user, this.initialIndex = 0});

  final AuthUser user;
  final int initialIndex;

  @override
  State<ManagementShell> createState() => _ManagementShellState();
}

class _ManagementShellState extends State<ManagementShell> {
  final InventoryService _inventoryService = InventoryService();
  int _index = 0;
  int _entryRefreshToken = 0;
  final GlobalKey _inventoryKey = GlobalKey();
  final _settingsKey = GlobalKey<SettingsHomeScreenState>();
  final Set<int> _loadedScreens = {};
  late final List<Widget> _screens;
  late String _stationTitle;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, 4);
    _loadedScreens.add(_index);
    _stationTitle = widget.user.stationId;
    _screens = [
      ManagementDashboardScreen(user: widget.user),
      InventoryHubScreen(
        key: _inventoryKey,
        canManagePlanning: true,
        showStockManagement: false,
      ),
      EntryManagementScreen(
        key: ValueKey(_entryRefreshToken),
        currentUser: widget.user,
      ),
      const MonthlyReportScreen(),
      SettingsHomeScreen(key: _settingsKey, user: widget.user),
    ];
    _loadStationTitle();
  }

  Future<void> _loadStationTitle() async {
    try {
      final station = await _inventoryService.fetchStationConfig();
      if (!mounted || station.name.trim().isEmpty) {
        return;
      }
      setState(() => _stationTitle = station.name.trim());
    } catch (_) {
      // Keep the existing fallback title if station lookup fails.
    }
  }

  void _selectIndex(int value) {
    setState(() {
      if (value == 2 && _index != value) {
        _entryRefreshToken += 1;
        _screens[2] = EntryManagementScreen(
          key: ValueKey(_entryRefreshToken),
          currentUser: widget.user,
        );
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
      destructive: true,
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
        automaticallyImplyLeading: false,
        backgroundColor: kClayBg,
        scrolledUnderElevation: 0,
        elevation: 0,
        iconTheme: const IconThemeData(color: kClayPrimary),
        title: Row(
          children: [
            const AppLogo(size: 28),
            const SizedBox(width: 8),
            Text(
              _stationTitle,
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
          (index) => _loadedScreens.contains(index)
              ? _screens[index]
              : const SizedBox.shrink(),
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        selectedIndex: _index,
        onSelected: (value) {
          if (value == 4 && _index == 4) {
            SettingsHomeScreen.resetToHome(_settingsKey);
          } else if (value == 1 && _index == 1) {
            InventoryHubScreen.resetToHome(_inventoryKey);
          } else {
            _selectIndex(value);
          }
        },
        items: const [
          AppBottomNavItem(icon: Icons.grid_view_rounded, label: 'Dashboard'),
          AppBottomNavItem(
            icon: Icons.local_gas_station_outlined,
            label: 'Inventory',
          ),
          AppBottomNavItem(icon: Icons.edit_note_rounded, label: 'Entry'),
          AppBottomNavItem(icon: Icons.bar_chart_rounded, label: 'Report'),
          AppBottomNavItem(
            icon: Icons.manage_accounts_outlined,
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
