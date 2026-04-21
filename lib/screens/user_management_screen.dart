import 'package:flutter/material.dart';

import '../models/access_request.dart';
import '../models/auth_models.dart';
import '../models/user_management_models.dart';
import '../services/user_management_service.dart';
import '../utils/formatters.dart';
import '../utils/user_facing_errors.dart';
import '../widgets/clay_widgets.dart';
import '../widgets/responsive_text.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({
    super.key,
    required this.currentUser,
    this.embedded = false,
    this.onBack,
  });

  final AuthUser currentUser;
  final bool embedded;
  final VoidCallback? onBack;

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final UserManagementService _service = UserManagementService();
  late Future<UserManagementOverview> _future;
  final Map<String, String> _requestRoles = {};
  final Map<String, String> _staffRoles = {};
  final Set<String> _selectedRequestIds = <String>{};
  final Set<String> _editingUserIds = <String>{};

  @override
  void initState() {
    super.initState();
    _future = _service.fetchOverview();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _service.fetchOverview(forceRefresh: true);
      _selectedRequestIds.clear();
      _editingUserIds.clear();
    });
  }

  Future<void> _openAddStaffDialog(bool canManageSuperAdmins) async {
    final emailController = TextEditingController();
    final nameController = TextEditingController();
    String role = 'sales';

    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => ClayDialogShell(
          title: 'Add Staff Member',
          subtitle: 'Create a station user and assign the access role.',
          icon: Icons.person_add_alt_1_rounded,
          actions: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kClayPrimary,
                  side: BorderSide(color: kClayPrimary.withValues(alpha: 0.16)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4D66A9),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Save'),
              ),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClayDialogSection(
                title: 'Staff details',
                subtitle:
                    'This account will be available in Users & Roles once saved.',
                child: Column(
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: clayDialogInputDecoration(
                        label: 'Name',
                        hintText: 'Staff member name',
                        prefixIcon: const Icon(
                          Icons.badge_outlined,
                          color: kClaySub,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      decoration: clayDialogInputDecoration(
                        label: 'Email',
                        hintText: 'name@example.com',
                        prefixIcon: const Icon(
                          Icons.mail_outline_rounded,
                          color: kClaySub,
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ClayDialogSection(
                title: 'Role access',
                subtitle:
                    'Choose what this user can manage inside the station.',
                child: DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: clayDialogInputDecoration(
                    label: 'Role',
                    prefixIcon: const Icon(
                      Icons.admin_panel_settings_outlined,
                      color: kClaySub,
                    ),
                  ),
                  items: canManageSuperAdmins
                      ? const [
                          DropdownMenuItem(
                            value: 'sales',
                            child: Text('Sales'),
                          ),
                          DropdownMenuItem(
                            value: 'admin',
                            child: Text('Admin'),
                          ),
                          DropdownMenuItem(
                            value: 'superadmin',
                            child: Text('Superadmin'),
                          ),
                        ]
                      : const [
                          DropdownMenuItem(
                            value: 'sales',
                            child: Text('Sales'),
                          ),
                          DropdownMenuItem(
                            value: 'admin',
                            child: Text('Admin'),
                          ),
                        ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setDialogState(() => role = value);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (shouldSave != true) {
      return;
    }

    await _service.addStaff(
      email: emailController.text.trim(),
      name: nameController.text.trim(),
      role: role,
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Staff member saved.')));
    await _reload();
  }

  Future<void> _approveRequest(AccessRequest request, String role) async {
    await _service.approveRequest(request.id, role);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${request.email} approved as $role.')),
    );
    await _reload();
  }

  Future<void> _rejectRequest(AccessRequest request) async {
    await _service.rejectRequest(request.id);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${request.email} rejected.')));
    await _reload();
  }

  Future<void> _bulkApprove(List<AccessRequest> requests) async {
    final selected = requests
        .where((request) => _selectedRequestIds.contains(request.id))
        .map(
          (request) => {
            'requestId': request.id,
            'role': _requestRoles[request.id] ?? request.roleRequested,
          },
        )
        .toList();
    if (selected.isEmpty) {
      return;
    }
    await _service.bulkApproveRequests(selected);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${selected.length} requests approved.')),
    );
    await _reload();
  }

  Future<void> _bulkDelete() async {
    if (_selectedRequestIds.isEmpty) {
      return;
    }

    final shouldDelete = await showClayConfirmDialog(
      context: context,
      title: 'Delete Pending Requests',
      message:
          'Delete ${_selectedRequestIds.length} pending request(s) and remove those pending users?',
      confirmLabel: 'Delete',
      icon: Icons.delete_sweep_rounded,
      destructive: true,
    );

    if (!shouldDelete) {
      return;
    }

    await _service.bulkDeleteRequests(_selectedRequestIds.toList());
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_selectedRequestIds.length} requests deleted.'),
      ),
    );
    await _reload();
  }

  Future<void> _saveStaffRole(ManagedUser user, String role) async {
    await _service.updateStaffRole(userId: user.id, role: role);
    if (!mounted) {
      return;
    }
    setState(() {
      _editingUserIds.remove(user.id);
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${user.email} updated to $role.')));
    await _reload();
  }

  Future<void> _deleteStaff(ManagedUser user) async {
    final shouldDelete = await showClayConfirmDialog(
      context: context,
      title: 'Delete Staff Member',
      message: 'Remove ${user.email} from staff access?',
      confirmLabel: 'Delete',
      icon: Icons.person_remove_alt_1_rounded,
      destructive: true,
    );

    if (!shouldDelete) {
      return;
    }

    await _service.deleteStaff(user.id);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${user.email} deleted.')));
    await _reload();
  }

  void _toggleSelectAllRequests(List<AccessRequest> requests, bool select) {
    setState(() {
      if (select) {
        _selectedRequestIds
          ..clear()
          ..addAll(requests.map((request) => request.id));
      } else {
        _selectedRequestIds.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = FutureBuilder<UserManagementOverview>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ColoredBox(
            color: kClayBg,
            child: Center(child: Text(userFacingErrorMessage(snapshot.error))),
          );
        }

        final overview = snapshot.data!;
        final summary = overview.summary;
        final requests = overview.requests;
        final users = overview.users;
        final canManageSuperAdmins = overview.permissions.canManageSuperAdmins;
        final allSelected =
            requests.isNotEmpty &&
            _selectedRequestIds.length == requests.length;

        return ColoredBox(
          color: kClayBg,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _UsersOverviewCard(
                summary: summary,
                onBack: widget.embedded ? widget.onBack : null,
                onAddUser: () => _openAddStaffDialog(canManageSuperAdmins),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Pending Requests',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: kClayPrimary,
                      ),
                    ),
                  ),
                  if (requests.isNotEmpty)
                    TextButton(
                      onPressed: () =>
                          _toggleSelectAllRequests(requests, !allSelected),
                      child: Text(allSelected ? 'Clear All' : 'Select All'),
                    ),
                ],
              ),
              if (_selectedRequestIds.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilledButton(
                      onPressed: () => _bulkApprove(requests),
                      child: Text(
                        'Bulk Approve (${_selectedRequestIds.length})',
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: _bulkDelete,
                      child: Text(
                        'Bulk Delete (${_selectedRequestIds.length})',
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              if (requests.isEmpty)
                const _EmptyCard(
                  message: 'No pending access requests right now.',
                )
              else
                ...requests.map((request) {
                  final selectedRole =
                      _requestRoles[request.id] ?? request.roleRequested;
                  final isSelected = _selectedRequestIds.contains(request.id);
                  return _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: isSelected,
                              onChanged: (value) {
                                setState(() {
                                  if (value ?? false) {
                                    _selectedRequestIds.add(request.id);
                                  } else {
                                    _selectedRequestIds.remove(request.id);
                                  }
                                });
                              },
                            ),
                            Expanded(
                              child: Text(
                                request.name.isEmpty
                                    ? 'Unnamed Request'
                                    : request.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(request.email),
                        Text(
                          'Requested on ${formatDateLabel(request.createdAt.toIso8601String())}',
                          style: const TextStyle(color: Color(0xFF55606E)),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: selectedRole,
                          items: canManageSuperAdmins
                              ? const [
                                  DropdownMenuItem(
                                    value: 'sales',
                                    child: Text('Sales'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'admin',
                                    child: Text('Admin'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'superadmin',
                                    child: Text('Superadmin'),
                                  ),
                                ]
                              : const [
                                  DropdownMenuItem(
                                    value: 'sales',
                                    child: Text('Sales'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'admin',
                                    child: Text('Admin'),
                                  ),
                                ],
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _requestRoles[request.id] = value;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            FilledButton(
                              onPressed: () =>
                                  _approveRequest(request, selectedRole),
                              child: const Text('Approve'),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton(
                              onPressed: () => _rejectRequest(request),
                              child: const Text('Reject'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 12),
              const Text(
                'Current Users',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: kClayPrimary,
                ),
              ),
              const SizedBox(height: 8),
              ...users.map((user) {
                final selectedRole = _staffRoles[user.id] ?? user.role;
                final isEditing = _editingUserIds.contains(user.id);
                final isSelf =
                    user.email.toLowerCase() ==
                    widget.currentUser.email.toLowerCase();
                final canManage =
                    !isSelf &&
                    (user.role != 'superadmin' || canManageSuperAdmins);
                final roleItems =
                    user.role == 'superadmin' || canManageSuperAdmins
                    ? const [
                        DropdownMenuItem(value: 'sales', child: Text('Sales')),
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                        DropdownMenuItem(
                          value: 'superadmin',
                          child: Text('Superadmin'),
                        ),
                      ]
                    : const [
                        DropdownMenuItem(value: 'sales', child: Text('Sales')),
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      ];

                return _StaffUserCard(
                  user: user,
                  selectedRole: selectedRole,
                  roleItems: roleItems,
                  canManage: canManage,
                  isEditing: isEditing,
                  onRoleChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _staffRoles[user.id] = value;
                    });
                  },
                  onEdit: () {
                    setState(() {
                      _editingUserIds.add(user.id);
                    });
                  },
                  onSave: () => _saveStaffRole(user, selectedRole),
                  onDelete: () => _deleteStaff(user),
                  onCancel: () {
                    setState(() {
                      _editingUserIds.remove(user.id);
                      _staffRoles.remove(user.id);
                    });
                  },
                );
              }),
            ],
          ),
        );
      },
    );

    if (widget.embedded) {
      return RefreshIndicator(onRefresh: _reload, child: content);
    }

    return Scaffold(
      backgroundColor: kClayBg,
      body: RefreshIndicator(onRefresh: _reload, child: content),
    );
  }
}

class _UsersOverviewCard extends StatelessWidget {
  const _UsersOverviewCard({
    required this.summary,
    required this.onAddUser,
    this.onBack,
  });

  final UserManagementSummary summary;
  final VoidCallback onAddUser;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF1A3A7A), Color(0xFF0D2460)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D2460).withValues(alpha: 0.32),
            offset: const Offset(0, 10),
            blurRadius: 22,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: OneLineScaleText(
                  'Users & Roles',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _UsersHeroActionPill(
                icon: Icons.person_add_alt_1_rounded,
                label: 'Add User',
                onTap: onAddUser,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _OverviewStatTile(
                  title: 'Total',
                  value: '${summary.totalUsers}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OverviewStatTile(
                  title: 'Approved',
                  value: '${summary.approvedUsers}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OverviewStatTile(
                  title: 'Pending',
                  value: '${summary.pendingRequests}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OverviewStatTile(
                  title: 'Admins',
                  value: '${summary.adminCount}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UsersHeroActionPill extends StatelessWidget {
  const _UsersHeroActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 5),
            OneLineScaleText(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewStatTile extends StatelessWidget {
  const _OverviewStatTile({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OneLineScaleText(
            title,
            textAlign: TextAlign.center,
            alignment: Alignment.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          OneLineScaleText(
            value,
            textAlign: TextAlign.center,
            alignment: Alignment.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClayCard(margin: const EdgeInsets.only(bottom: 12), child: child);
  }
}

class _StaffUserCard extends StatelessWidget {
  const _StaffUserCard({
    required this.user,
    required this.selectedRole,
    required this.roleItems,
    required this.canManage,
    required this.isEditing,
    required this.onRoleChanged,
    required this.onEdit,
    required this.onSave,
    required this.onDelete,
    required this.onCancel,
  });

  final ManagedUser user;
  final String selectedRole;
  final List<DropdownMenuItem<String>> roleItems;
  final bool canManage;
  final bool isEditing;
  final ValueChanged<String?> onRoleChanged;
  final VoidCallback onEdit;
  final VoidCallback onSave;
  final VoidCallback onDelete;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final displayName = user.name.trim().isEmpty ? user.email : user.name;
    final initial = displayName.trim().isEmpty
        ? '?'
        : displayName.trim().characters.first.toUpperCase();
    final infoPills = <Widget>[
      _StaffInfoPill(
        icon: Icons.storefront_rounded,
        label: 'Station ${user.stationId}',
      ),
      _StaffInfoPill(
        icon: Icons.person_add_alt_1_rounded,
        label: 'Added ${formatDateLabel(user.createdAt.toIso8601String())}',
      ),
      if (user.requestCreatedAt != null)
        _StaffInfoPill(
          icon: Icons.schedule_rounded,
          label:
              'Requested ${formatDateLabel(user.requestCreatedAt!.toIso8601String())}',
        ),
      if (user.reviewedAt != null)
        _StaffInfoPill(
          icon: Icons.verified_rounded,
          label:
              'Reviewed ${formatDateLabel(user.reviewedAt!.toIso8601String())}',
        ),
    ];

    return ClayCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: kClayPrimary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: kClayPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: kClayPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF4B5563),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _StatusPill(status: user.status),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            itemCount: infoPills.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              mainAxisExtent: 34,
            ),
            itemBuilder: (context, index) => infoPills[index],
          ),
          const SizedBox(height: 12),
          if (isEditing && canManage)
            _RoleDropdown(
              value: selectedRole,
              items: roleItems,
              onChanged: onRoleChanged,
            )
          else
            _RoleDisplay(role: selectedRole),
          const SizedBox(height: 12),
          if (canManage && !isEditing)
            _StaffActionButton(
              icon: Icons.edit_rounded,
              label: 'Edit role',
              onTap: onEdit,
            )
          else if (canManage && isEditing)
            Row(
              children: [
                Expanded(
                  child: _StaffActionButton(
                    icon: Icons.save_outlined,
                    label: 'Save',
                    onTap: onSave,
                    filled: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StaffActionButton(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete',
                    onTap: onDelete,
                    destructive: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StaffActionButton(
                    icon: Icons.close_rounded,
                    label: 'Cancel',
                    onTap: onCancel,
                  ),
                ),
              ],
            )
          else
            const _ProtectedPill(),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final isApproved = normalized == 'approved';
    final color = isApproved
        ? const Color(0xFF2F7D64)
        : const Color(0xFF9A6A24);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isApproved ? const Color(0xFFF5FBF8) : const Color(0xFFFCF8F1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StaffInfoPill extends StatelessWidget {
  const _StaffInfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFECEFF8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: kClayPrimary),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF5D6685),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleDisplay extends StatelessWidget {
  const _RoleDisplay({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFECEFF8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE2F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.admin_panel_settings_rounded, color: kClayPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _roleLabel(role),
              style: const TextStyle(
                color: kClayPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleDropdown extends StatelessWidget {
  const _RoleDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: 'Role',
        prefixIcon: const Icon(Icons.admin_panel_settings_rounded),
        filled: true,
        fillColor: const Color(0xFFECEFF8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _StaffActionButton extends StatelessWidget {
  const _StaffActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? const Color(0xFFAD5162) : kClayPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: filled
              ? kClayPrimary
              : destructive
              ? const Color(0xFFFFFBFC)
              : const Color(0xFFF7F8FD),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: filled
                ? kClayPrimary
                : destructive
                ? const Color(0xFFE7C6CF)
                : const Color(0xFFDDE2F0),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: filled ? Colors.white : color, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: filled ? Colors.white : color,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProtectedPill extends StatelessWidget {
  const _ProtectedPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFECEFF8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_outline_rounded, color: Color(0xFF5D6685), size: 17),
          SizedBox(width: 8),
          Text(
            'Protected account',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF5D6685),
            ),
          ),
        ],
      ),
    );
  }
}

String _roleLabel(String role) {
  switch (role) {
    case 'superadmin':
      return 'Superadmin';
    case 'admin':
      return 'Admin';
    case 'sales':
      return 'Sales';
    default:
      return role;
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Text(
        message,
        style: const TextStyle(color: kClaySub, fontWeight: FontWeight.w600),
      ),
    );
  }
}
