import 'package:flutter/material.dart';

import '../models/auth_models.dart';
import '../models/domain_models.dart';
import '../services/management_service.dart';
import '../utils/formatters.dart';

class ManagementDashboardScreen extends StatefulWidget {
  const ManagementDashboardScreen({
    super.key,
    required this.user,
    this.onOpenEntries,
    this.onOpenReports,
    this.onOpenInventory,
    this.onOpenUsers,
    this.onOpenSettings,
  });

  final AuthUser user;
  final VoidCallback? onOpenEntries;
  final VoidCallback? onOpenReports;
  final VoidCallback? onOpenInventory;
  final VoidCallback? onOpenUsers;
  final VoidCallback? onOpenSettings;

  @override
  State<ManagementDashboardScreen> createState() =>
      _ManagementDashboardScreenState();
}

class _ManagementDashboardScreenState extends State<ManagementDashboardScreen> {
  final ManagementService _managementService = ManagementService();
  late Future<ManagementDashboardModel> _future;

  @override
  void initState() {
    super.initState();
    _future = _managementService.fetchDashboard();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _managementService.fetchDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<ManagementDashboardModel>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [Text('Failed to load dashboard\n${snapshot.error}')],
            );
          }
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 120),
            children: [
              Text(
                data.station.name,
                style: const TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF55606E),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Management Dashboard',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF293340),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _StatCard(
                    title: 'Revenue',
                    value: formatCurrency(data.revenue),
                    accent: const Color(0xFF1E5CBA),
                  ),
                  _StatCard(
                    title: 'Profit',
                    value: formatCurrency(data.profit),
                    accent: const Color(0xFF006C5C),
                  ),
                  _StatCard(
                    title: 'Flagged',
                    value: '${data.flaggedCount}',
                    accent: const Color(0xFFB91C1C),
                  ),
                  _StatCard(
                    title: 'Pending Users',
                    value: '${data.pendingRequests}',
                    accent: const Color(0xFF695781),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _DashboardAction(
                title: 'Entry Management',
                subtitle: 'Review, edit, and approve shift submissions',
                icon: Icons.edit_note_rounded,
                onTap: widget.onOpenEntries,
              ),
              const SizedBox(height: 10),
              _DashboardAction(
                title: 'Monthly Reports',
                subtitle: 'Track trend lines and monthly totals',
                icon: Icons.bar_chart_rounded,
                onTap: widget.onOpenReports,
              ),
              const SizedBox(height: 10),
              _DashboardAction(
                title: 'Inventory & Pricing',
                subtitle: widget.user.role == 'superadmin'
                    ? 'Manage fuel types, pricing, and station config'
                    : 'View fuel types, prices, and station inventory',
                icon: Icons.local_gas_station_rounded,
                onTap: widget.onOpenInventory,
              ),
              const SizedBox(height: 10),
              _DashboardAction(
                title: widget.user.role == 'superadmin'
                    ? 'Users & Settings'
                    : 'Station Settings',
                subtitle: widget.user.role == 'superadmin'
                    ? 'Approve staff requests and manage access'
                    : 'View station settings and assigned configuration',
                icon: Icons.manage_accounts_outlined,
                onTap: widget.user.role == 'superadmin'
                    ? widget.onOpenUsers
                    : widget.onOpenSettings,
              ),
              const SizedBox(height: 18),
              const Text(
                'Recent Entries',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              ...data.recentEntries.map(
                (entry) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${formatDateLabel(entry.date)} - ${formatShiftLabel(entry.shift)}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Revenue ${formatCurrency(entry.revenue)} - Profit ${formatCurrency(entry.profit)}',
                      ),
                      Text(
                        entry.flagged ? entry.varianceNote : entry.status,
                        style: TextStyle(
                          color: entry.flagged
                              ? const Color(0xFFB91C1C)
                              : const Color(0xFF55606E),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.accent,
  });

  final String title;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border(bottom: BorderSide(color: accent, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF55606E))),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
        ],
      ),
    );
  }
}

class _DashboardAction extends StatelessWidget {
  const _DashboardAction({
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
                    Text(
                      subtitle,
                      style: const TextStyle(color: Color(0xFF55606E)),
                    ),
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
