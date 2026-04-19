import 'package:flutter/material.dart';

import '../models/auth_models.dart';
import '../widgets/app_bottom_nav_bar.dart';
import '../widgets/app_logo.dart';
import '../widgets/clay_widgets.dart';
import 'account_screen.dart';
import 'closing_stock_entry_screen.dart';
import 'entry_history_screen.dart';
import 'inventory_hub_screen.dart';
import 'sales_dashboard_screen.dart';

class SalesShell extends StatefulWidget {
  const SalesShell({super.key, required this.user});

  final AuthUser user;

  @override
  State<SalesShell> createState() => _SalesShellState();
}

class _SalesShellState extends State<SalesShell> {
  int _index = 0;
  int _salesRefreshToken = 0;
  final Set<int> _loadedScreens = {0};
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      SalesDashboardScreen(onOpenSalesEntry: () => _selectIndex(1)),
      ClosingStockEntryScreen(key: ValueKey(_salesRefreshToken)),
      const InventoryHubScreen(),
      const EntryHistoryScreen(),
      AccountScreen(user: widget.user),
    ];
  }

  Future<void> _selectIndex(int value) async {
    if (_index == value) {
      return;
    }
    setState(() {
      if (value == 1) {
        _salesRefreshToken += 1;
        _screens[1] = ClosingStockEntryScreen(
          key: ValueKey(_salesRefreshToken),
        );
      }
      _index = value;
      _loadedScreens.add(value);
    });
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
        onSelected: _selectIndex,
        items: const [
          AppBottomNavItem(icon: Icons.grid_view_rounded, label: 'Dashboard'),
          AppBottomNavItem(icon: Icons.inventory_2_outlined, label: 'Sales'),
          AppBottomNavItem(
            icon: Icons.local_gas_station_outlined,
            label: 'Inventory',
          ),
          AppBottomNavItem(
            icon: Icons.local_shipping_outlined,
            label: 'History',
          ),
          AppBottomNavItem(
            icon: Icons.person_outline_rounded,
            label: 'Account',
          ),
        ],
      ),
    );
  }

  String _titleForIndex(int index) {
    switch (index) {
      case 1:
        return 'Sales';
      case 2:
        return 'Inventory';
      case 3:
        return 'History';
      case 4:
        return 'Account';
      default:
        return 'Dashboard';
    }
  }
}
