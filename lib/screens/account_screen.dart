import 'package:flutter/material.dart';

import '../models/auth_models.dart';
import '../services/auth_service.dart';
import '../widgets/app_logo.dart';
import 'fuel_price_settings_screen.dart';
import 'login_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key, required this.user});

  final AuthUser user;

  Future<bool> _confirmLogout(BuildContext context) async {
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
    return shouldLogout == true;
  }

  @override
  Widget build(BuildContext context) {
    final canEditFuelPrices =
        user.role == 'sales' ||
        user.role == 'admin' ||
        user.role == 'superadmin';
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            children: [
              const AppLogo(size: 58),
              const SizedBox(height: 14),
              Text(
                user.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(user.email),
              const SizedBox(height: 6),
              Text('Role: ${user.role}'),
              Text('Station: ${user.stationId}'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed:
              canEditFuelPrices
                  ? () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder:
                            (_) => const FuelPriceSettingsScreen(canEdit: true),
                      ),
                    );
                  }
                  : null,
          icon: const Icon(Icons.local_gas_station_rounded),
          label: const Text('Fuel Prices'),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () async {
            final shouldLogout = await _confirmLogout(context);
            if (!shouldLogout) {
              return;
            }
            await AuthService().signOut();
            if (!context.mounted) return;
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
              (_) => false,
            );
          },
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
        ),
      ],
    );
  }
}
