import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'login_screen.dart';

class SalesDashboardScreen extends StatelessWidget {
  const SalesDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.85),
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.local_gas_station, color: Color(0xFF1E5CBA)),
            const SizedBox(width: 8),
            Text(
              'FuelFlow',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: const Color(0xFF293340),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () async {
              await AuthService().signOut();
              if (!context.mounted) {
                return;
              }
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 110),
        children: [
          const Text(
            'Good Evening',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: Color(0xFF55606E),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Sales Dashboard',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: Color(0xFF293340),
            ),
          ),
          const SizedBox(height: 16),
          _summaryCard(),
          const SizedBox(height: 18),
          _actionCard(
            title: 'Enter Closing Stock',
            subtitle: 'Daily pump meter recording',
            icon: Icons.propane_tank_outlined,
            iconBg: const Color(0xFF88F6DD),
            onTap: () {},
          ),
          const SizedBox(height: 12),
          _actionCard(
            title: 'Entry History',
            subtitle: 'Review past submissions',
            icon: Icons.list_alt_rounded,
            iconBg: const Color(0xFFD8E3F4),
            onTap: () {},
          ),
          const SizedBox(height: 12),
          _actionCard(
            title: "Today's Summary",
            subtitle: 'Sales and inventory analytics',
            icon: Icons.analytics_outlined,
            iconBg: const Color(0xFFE5CEFF),
            onTap: () {},
          ),
          const SizedBox(height: 18),
          const Text(
            'Sales Snapshot',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF293340),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(
                child: _FuelCard(
                  label: 'Petrol (95)',
                  volume: '4,120 L',
                  color: Color(0xFF1E5CBA),
                  progress: 0.65,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _FuelCard(
                  label: 'Diesel',
                  volume: '4,300 L',
                  color: Color(0xFF006C5C),
                  progress: 0.78,
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x15000000),
              blurRadius: 28,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _NavItem(
              icon: Icons.grid_view_rounded,
              label: 'Dashboard',
              active: true,
            ),
            _NavItem(icon: Icons.inventory_2_outlined, label: 'Inventory'),
            _NavItem(icon: Icons.local_shipping_outlined, label: 'Logistics'),
            _NavItem(icon: Icons.person_outline_rounded, label: 'Account'),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6799FB), Color(0xFF1E5CBA)],
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'REVENUE TODAY',
            style: TextStyle(
              color: Color(0xCCFFFFFF),
              fontSize: 11,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '\$12,450.00',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricMini(label: 'Opening Stock', value: '45,200 L'),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _MetricMini(label: 'Est. Sales', value: '8,420 L'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconBg,
    required VoidCallback onTap,
  }) {
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
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: const Color(0xFF293340)),
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
                        fontSize: 18,
                        color: Color(0xFF293340),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF55606E),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricMini extends StatelessWidget {
  const _MetricMini({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xCCFFFFFF),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _FuelCard extends StatelessWidget {
  const _FuelCard({
    required this.label,
    required this.volume,
    required this.color,
    required this.progress,
  });

  final String label;
  final String volume;
  final Color color;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border(bottom: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF55606E),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            volume,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
              color: Color(0xFF293340),
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              color: color,
              backgroundColor: const Color(0xFFD8E3F4),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final Color activeColor = const Color(0xFF1E5CBA);
    final Color idleColor = const Color(0xFF717C8A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? const Color(0x1A1E5CBA) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: active ? activeColor : idleColor),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: active ? activeColor : idleColor,
            ),
          ),
        ],
      ),
    );
  }
}
