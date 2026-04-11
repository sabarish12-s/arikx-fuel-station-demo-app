import 'package:flutter/material.dart';

import '../models/access_request.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../utils/formatters.dart';
import '../utils/user_facing_errors.dart';
import '../widgets/app_logo.dart';
import '../widgets/clay_widgets.dart';
import 'login_screen.dart';

class SuperAdminRequestsScreen extends StatefulWidget {
  const SuperAdminRequestsScreen({super.key});

  @override
  State<SuperAdminRequestsScreen> createState() =>
      _SuperAdminRequestsScreenState();
}

class _SuperAdminRequestsScreenState extends State<SuperAdminRequestsScreen> {
  final AdminService _adminService = AdminService();
  late Future<List<AccessRequest>> _requestsFuture;

  String _errorText(Object? error) {
    return userFacingErrorMessage(error);
  }

  @override
  void initState() {
    super.initState();
    _requestsFuture = _adminService.fetchPendingRequests();
  }

  Future<void> _refresh() async {
    setState(() {
      _requestsFuture = _adminService.fetchPendingRequests();
    });
  }

  Future<void> _approve(String requestId) async {
    await _adminService.approveRequest(requestId);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kClayBg,
      appBar: AppBar(
        backgroundColor: kClayBg,
        iconTheme: const IconThemeData(color: kClayPrimary),
        title: const Row(
          children: [
            AppLogo(size: 26),
            SizedBox(width: 8),
            Text('Superadmin Requests'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () async {
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
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<AccessRequest>>(
          future: _requestsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const ColoredBox(
                color: kClayBg,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ClayCard(
                    margin: const EdgeInsets.only(top: 80),
                    child: Text(
                      'Failed to load requests:\n${_errorText(snapshot.error)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: kClayPrimary,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              );
            }
            final requests = snapshot.data ?? [];
            return ListView(
              padding: const EdgeInsets.all(16),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PENDING REQUESTS',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${requests.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Review station staff access requests and approve verified accounts.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (requests.isEmpty)
                  const ClayCard(
                    child: Text(
                      'No pending requests right now.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: kClayPrimary,
                      ),
                    ),
                  )
                else
                  ...requests.map((request) {
                    return ClayCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      request.name.isEmpty
                                          ? 'Unnamed Request'
                                          : request.name,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: kClayPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      request.email,
                                      style: const TextStyle(
                                        color: kClaySub,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  request.roleRequested.toUpperCase(),
                                  style: const TextStyle(
                                    color: kClayHeroStart,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _RequestInfoRow(
                            label: 'Requested On',
                            value: formatDateLabel(
                              request.createdAt.toIso8601String(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _RequestInfoRow(
                            label: 'Station',
                            value: request.stationId,
                          ),
                          const SizedBox(height: 14),
                          FilledButton(
                            onPressed: () => _approve(request.id),
                            style: FilledButton.styleFrom(
                              backgroundColor: kClayHeroStart,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text('Approve'),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RequestInfoRow extends StatelessWidget {
  const _RequestInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(color: kClaySub, fontWeight: FontWeight.w700),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: kClayPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
