import 'package:flutter/material.dart';

import '../models/access_request.dart';
import '../models/auth_models.dart';
import '../models/user_management_models.dart';
import '../services/user_management_service.dart';
import '../utils/formatters.dart';
import '../utils/user_facing_errors.dart';
import '../widgets/clay_widgets.dart';

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
      _future = _service.fetchOverview();
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
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('Add Staff Member'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(labelText: 'Name'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: emailController,
                          decoration: const InputDecoration(labelText: 'Email'),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: role,
                          items:
                              canManageSuperAdmins
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
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Save'),
                    ),
                  ],
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
    final selected =
        requests
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

    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Pending Requests'),
            content: Text(
              'Delete ${_selectedRequestIds.length} pending request(s) and remove those pending users?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (shouldDelete != true) {
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
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Staff Member'),
            content: Text('Remove ${user.email} from staff access?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (shouldDelete != true) {
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
            child: Center(
              child: Text(
                userFacingErrorMessage(snapshot.error),
              ),
            ),
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
            if (widget.embedded)
              ClaySubHeader(
                title: 'Users & Roles',
                onBack: widget.onBack,
                trailing: GestureDetector(
                  onTap: () => _openAddStaffDialog(canManageSuperAdmins),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFB8C0DC).withValues(alpha: 0.65),
                          offset: const Offset(4, 4),
                          blurRadius: 10,
                        ),
                        const BoxShadow(
                          color: Colors.white,
                          offset: Offset(-3, -3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_add_alt_1_rounded,
                            size: 15, color: kClayPrimary),
                        SizedBox(width: 5),
                        Text(
                          'Add User',
                          style: TextStyle(
                            color: kClayPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Manage staff, roles, and pending approvals.',
                  style: const TextStyle(color: kClaySub),
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SummaryCard(
                  title: 'Total Users',
                  value: '${summary.totalUsers}',
                ),
                _SummaryCard(
                  title: 'Approved',
                  value: '${summary.approvedUsers}',
                ),
                _SummaryCard(
                  title: 'Pending',
                  value: '${summary.pendingRequests}',
                ),
                _SummaryCard(title: 'Admins', value: '${summary.adminCount}'),
              ],
            ),
            const SizedBox(height: 12),
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
                    onPressed:
                        () => _toggleSelectAllRequests(requests, !allSelected),
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
                    child: Text('Bulk Approve (${_selectedRequestIds.length})'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: _bulkDelete,
                    child: Text('Bulk Delete (${_selectedRequestIds.length})'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            if (requests.isEmpty)
              const _EmptyCard(message: 'No pending access requests right now.')
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
                        items:
                            canManageSuperAdmins
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
                            onPressed:
                                () => _approveRequest(request, selectedRole),
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
              'Current Staff',
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

              return _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.name.isEmpty ? user.email : user.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Chip(label: Text(user.status)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(user.email),
                    Text(
                      'Station ${user.stationId}',
                      style: const TextStyle(color: Color(0xFF55606E)),
                    ),
                    Text(
                      'Added on ${formatDateLabel(user.createdAt.toIso8601String())}',
                      style: const TextStyle(color: Color(0xFF55606E)),
                    ),
                    if (user.requestCreatedAt != null)
                      Text(
                        'Requested on ${formatDateLabel(user.requestCreatedAt!.toIso8601String())}',
                        style: const TextStyle(color: Color(0xFF55606E)),
                      ),
                    if (user.reviewedAt != null)
                      Text(
                        'Reviewed on ${formatDateLabel(user.reviewedAt!.toIso8601String())}',
                        style: const TextStyle(color: Color(0xFF55606E)),
                      ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      items: roleItems,
                      onChanged:
                          isEditing && canManage
                              ? (value) {
                                if (value == null) {
                                  return;
                                }
                                setState(() {
                                  _staffRoles[user.id] = value;
                                });
                              }
                              : null,
                    ),
                    const SizedBox(height: 12),
                    if (canManage && !isEditing)
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _editingUserIds.add(user.id);
                          });
                        },
                        child: const Text('Edit'),
                      )
                    else if (canManage && isEditing)
                      Row(
                        children: [
                          FilledButton(
                            onPressed: () => _saveStaffRole(user, selectedRole),
                            child: const Text('Save Role'),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton(
                            onPressed: () => _deleteStaff(user),
                            child: const Text('Delete'),
                          ),
                          const SizedBox(width: 10),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _editingUserIds.remove(user.id);
                                _staffRoles.remove(user.id);
                              });
                            },
                            child: const Text('Cancel'),
                          ),
                        ],
                      )
                    else
                      const Text(
                        'Protected account',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF55606E),
                        ),
                      ),
                  ],
                ),
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
      floatingActionButton: FutureBuilder<UserManagementOverview>(
        future: _future,
        builder: (context, snapshot) {
          final canManageSuperAdmins =
              snapshot.data?.permissions.canManageSuperAdmins ?? false;
          return FloatingActionButton.extended(
            onPressed: () => _openAddStaffDialog(canManageSuperAdmins),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Add User'),
          );
        },
      ),
      body: RefreshIndicator(onRefresh: _reload, child: content),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 80),
      padding: const EdgeInsets.all(14),
      decoration: clayCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: kClaySub, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 20,
              color: kClayPrimary,
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
    return ClayCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: child,
    );
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
        style: const TextStyle(
          color: kClaySub,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
