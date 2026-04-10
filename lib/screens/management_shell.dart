import 'package:flutter/material.dart';

import '../models/auth_models.dart';
import '../services/auth_service.dart';
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
  final _settingsKey = GlobalKey<SettingsHomeScreenState>();
  final Set<int> _loadedScreens = {0};
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      ManagementDashboardScreen(user: widget.user),
      const EntryManagementScreen(),
      const MonthlyReportScreen(),
      const InventoryHubScreen(canManagePlanning: true),
      SettingsHomeScreen(key: _settingsKey, user: widget.user),
    ];
  }

  void _selectIndex(int value) {
    setState(() {
      _index = value;
      _loadedScreens.add(value);
    });
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (shouldLogout != true) {
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
              _loadedScreens.contains(index) ? _screens[index] : const SizedBox.shrink(),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFB8C0DC).withValues(alpha: 0.3),
              offset: const Offset(0, -6),
              blurRadius: 18,
            ),
          ],
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: Colors.white,
            indicatorColor: kClayHeroStart.withValues(alpha: 0.12),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return IconThemeData(color: selected ? kClayHeroStart : kClaySub);
            }),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return TextStyle(
                color: selected ? kClayHeroStart : kClaySub,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
              );
            }),
          ),
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (value) {
              if (value == 4 && _index == 4) {
                SettingsHomeScreen.resetToHome(_settingsKey);
              } else {
                _selectIndex(value);
              }
            },
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
                label: 'Settings',
              ),
            ],
          ),
        ),
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
