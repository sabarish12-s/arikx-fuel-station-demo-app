import 'package:flutter/material.dart';

import '../models/auth_models.dart';
import '../navigation/app_router.dart';
import '../services/auth_service.dart';
import '../widgets/app_logo.dart';

class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key, this.user});

  final AuthUser? user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F6FF),
      body: Stack(
        children: [
          Positioned(
            top: -90,
            left: -90,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                color: const Color(0xFF88F6DD).withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: const Color(0xFF6799FB).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          ListView(
            padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
            children: [
              const Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppLogo(size: 34),
                    SizedBox(width: 8),
                    Text(
                      'RK Fuels',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF293340),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x10000000),
                      blurRadius: 32,
                      offset: Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 38,
                      backgroundColor: user?.status == 'rejected'
                          ? const Color(0x33FCA5A5)
                          : const Color(0x33E5CEFF),
                      child: Icon(
                        user?.status == 'rejected'
                            ? Icons.block_outlined
                            : Icons.info_outline_rounded,
                        size: 36,
                        color: user?.status == 'rejected'
                            ? const Color(0xFFB91C1C)
                            : const Color(0xFF695781),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      user?.status == 'rejected'
                          ? 'Access Request Rejected'
                          : 'Access Request Sent',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 29,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF293340),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      user?.status == 'rejected'
                          ? 'Your request was rejected by station management. Please contact the superadmin.'
                          : 'Your account is waiting for approval from the station administrator.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF55606E),
                        height: 1.35,
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
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF4FF),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.person, color: Color(0xFF1E5CBA)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            email,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () async {
                  await AuthService().signOut();
                  if (!context.mounted) {
                    return;
                  }
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute<void>(
                      builder: (_) => screenForUser(null),
                    ),
                    (_) => false,
                  );
                },
                icon: const Icon(Icons.logout),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Sign Out'),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E5CBA),
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
                    color: Color(0xFF717C8A),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
