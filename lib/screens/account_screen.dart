import 'package:flutter/material.dart';

import '../models/auth_models.dart';
import '../services/auth_service.dart';
import '../widgets/app_logo.dart';
import '../widgets/clay_widgets.dart';
import '../widgets/responsive_text.dart';
import 'fuel_price_settings_screen.dart';
import 'login_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key, required this.user});

  final AuthUser user;

  Future<bool> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
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
    final displayName =
        user.name.trim().isEmpty ? user.email : user.name.trim();
    final roleLabel = '${user.role[0].toUpperCase()}${user.role.substring(1)}';

    return Scaffold(
      backgroundColor: kClayBg,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [kClayHeroStart, kClayHeroEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: kClayHeroEnd.withValues(alpha: 0.45),
                  offset: const Offset(0, 10),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: AppLogo(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          roleLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _AccountSectionLabel(label: 'PROFILE'),
          const SizedBox(height: 10),
          ClayCard(
            child: Column(
              children: [
                _AccountInfoRow(label: 'Name', value: displayName),
                const Divider(color: kClayBg, height: 24),
                _AccountInfoRow(label: 'Email', value: user.email),
                const Divider(color: kClayBg, height: 24),
                _AccountInfoRow(label: 'Role', value: roleLabel),
                const Divider(color: kClayBg, height: 24),
                _AccountInfoRow(label: 'Station', value: user.stationId),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _AccountSectionLabel(label: 'SHORTCUTS'),
          const SizedBox(height: 10),
          ClayCard(
            child: _AccountActionTile(
              title: 'Fuel Prices',
              subtitle:
                  canEditFuelPrices
                      ? 'Review and update current selling prices'
                      : 'Fuel pricing access is limited for this role',
              icon: Icons.local_gas_station_rounded,
              iconColor: const Color(0xFF1298B8),
              enabled: canEditFuelPrices,
              onTap:
                  canEditFuelPrices
                      ? () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder:
                                (_) => const FuelPriceSettingsScreen(
                                  canEdit: true,
                                ),
                          ),
                        );
                      }
                      : null,
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
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
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign Out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFCE5828),
              side: const BorderSide(color: Color(0xFFCE5828)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountSectionLabel extends StatelessWidget {
  const _AccountSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: kClaySub,
        letterSpacing: 1.1,
      ),
    );
  }
}

class _AccountInfoRow extends StatelessWidget {
  const _AccountInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: kClaySub,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: OneLineScaleText(
            value,
            textAlign: TextAlign.right,
            alignment: Alignment.centerRight,
            style: const TextStyle(
              color: kClayPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

class _AccountActionTile extends StatelessWidget {
  const _AccountActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.enabled,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OneLineScaleText(
                  title,
                  style: TextStyle(
                    color: enabled ? kClayPrimary : kClaySub,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: kClaySub,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right_rounded,
            color: enabled ? kClaySub : kClaySub.withValues(alpha: 0.45),
          ),
        ],
      ),
    );
  }
}
