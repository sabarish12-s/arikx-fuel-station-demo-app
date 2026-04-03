import 'package:flutter/material.dart';

class InventoryHubScreen extends StatelessWidget {
  const InventoryHubScreen({
    super.key,
    required this.canManage,
    this.onOpenFuelTypes,
    this.onOpenPrices,
    this.onOpenSettings,
  });

  final bool canManage;
  final VoidCallback? onOpenFuelTypes;
  final VoidCallback? onOpenPrices;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _InventoryTile(
          title: 'Fuel Type Manager',
          subtitle: canManage
              ? 'Create and maintain the active fuel catalog'
              : 'View the active fuel catalog',
          icon: Icons.category_outlined,
          onTap: onOpenFuelTypes,
        ),
        const SizedBox(height: 12),
        _InventoryTile(
          title: 'Fuel Price Settings',
          subtitle: canManage
              ? 'Update cost and selling prices'
              : 'View current cost and selling prices',
          icon: Icons.payments_outlined,
          onTap: onOpenPrices,
        ),
        const SizedBox(height: 12),
        _InventoryTile(
          title: 'Station Settings',
          subtitle: 'Review station layout, pumps, and shift configuration',
          icon: Icons.settings_suggest_outlined,
          onTap: onOpenSettings,
        ),
      ],
    );
  }
}

class _InventoryTile extends StatelessWidget {
  const _InventoryTile({
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
                    Text(subtitle, style: const TextStyle(color: Color(0xFF55606E))),
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
