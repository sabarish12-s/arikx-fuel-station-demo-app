import 'package:flutter/material.dart';

import '../models/auth_models.dart';
import '../widgets/app_logo.dart';
import '../widgets/clay_widgets.dart';
import 'account_screen.dart';
import 'closing_stock_entry_screen.dart';
import 'daily_summary_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    final screens = [
      SalesDashboardScreen(
        onOpenClosingStock: () => setState(() => _index = 1),
        onOpenEntryHistory: () => setState(() => _index = 3),
        onOpenDailySummary: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const DailySummaryScreen()),
          );
        },
      ),
      const ClosingStockEntryScreen(),
      const InventoryHubScreen(),
      const EntryHistoryScreen(),
      AccountScreen(user: widget.user),
    ];

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
      body: IndexedStack(index: _index, children: screens),
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
            onDestinationSelected: (value) => setState(() => _index = value),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.grid_view_rounded),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined),
                label: 'Sales',
              ),
              NavigationDestination(
                icon: Icon(Icons.local_gas_station_outlined),
                label: 'Inventory',
              ),
              NavigationDestination(
                icon: Icon(Icons.local_shipping_outlined),
                label: 'History',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                label: 'Account',
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
