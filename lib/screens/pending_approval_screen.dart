import 'package:flutter/material.dart';

import '../models/auth_models.dart';
import '../navigation/app_router.dart';
import '../services/auth_service.dart';
import '../widgets/app_logo.dart';
import '../widgets/clay_widgets.dart';

class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key, this.user});

  final AuthUser? user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kClayBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
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
              child: Column(
                children: [
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppLogo(size: 30),
                      SizedBox(width: 10),
                      Text(
                        'Arikx fuel station',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      user?.status == 'rejected'
                          ? Icons.block_outlined
                          : Icons.info_outline_rounded,
                      size: 34,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.status == 'rejected'
                        ? 'Access Request Rejected'
                        : 'Access Request Sent',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user?.status == 'rejected'
                        ? 'Your request was rejected by station management. Please contact the superadmin.'
                        : 'Your account is waiting for approval from the station administrator.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FutureBuilder<AuthUser?>(
              future: AuthService().readCurrentUser(),
              builder: (context, snapshot) {
                final String email =
                    user?.email ?? snapshot.data?.email ?? 'user@example.com';
                return ClayCard(
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: kClayHeroStart.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.person_outline_rounded,
                          color: kClayHeroStart,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ACCOUNT',
                              style: TextStyle(
                                color: kClaySub,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: kClayPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () async {
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
                if (!context.mounted) {
                  return;
                }
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute<void>(builder: (_) => screenForUser(null)),
                  (_) => false,
                );
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Sign Out'),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: kClayHeroStart,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Secure Fuel Logistics',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.5,
                  color: kClaySub,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
