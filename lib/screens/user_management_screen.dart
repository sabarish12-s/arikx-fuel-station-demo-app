import 'package:flutter/material.dart';

import '../models/access_request.dart';
import '../services/user_management_service.dart';
import '../utils/formatters.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final UserManagementService _service = UserManagementService();
  late Future<List<AccessRequest>> _future;
  final Map<String, String> _selectedRoles = {};

  @override
  void initState() {
    super.initState();
    _future = _service.fetchRequests();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _service.fetchRequests();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Management')),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<AccessRequest>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(children: [Center(child: Text('${snapshot.error}'))]);
            }
            final requests = snapshot.data ?? [];
            if (requests.isEmpty) {
              return ListView(
                children: const [SizedBox(height: 120), Center(child: Text('No pending requests right now.'))],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final request = requests[index];
                final selectedRole =
                    _selectedRoles[request.id] ?? request.roleRequested;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.name,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
                      ),
                      const SizedBox(height: 6),
                      Text(request.email),
                      Text('Requested on ${formatDateLabel(request.createdAt.toIso8601String())}'),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: selectedRole,
                        items: const [
                          DropdownMenuItem(value: 'sales', child: Text('Sales')),
                          DropdownMenuItem(value: 'admin', child: Text('Admin')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _selectedRoles[request.id] = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          FilledButton(
                            onPressed: () async {
                              await _service.approveRequest(request.id, selectedRole);
                              await _reload();
                            },
                            child: const Text('Approve'),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton(
                            onPressed: () async {
                              await _service.rejectRequest(request.id);
                              await _reload();
                            },
                            child: const Text('Reject'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
