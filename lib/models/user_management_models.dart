import 'access_request.dart';

class ManagedUser {
  const ManagedUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.requestedRole,
    required this.status,
    required this.stationId,
    required this.createdAt,
    required this.requestCreatedAt,
    required this.reviewedAt,
    required this.rejectionReason,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final String requestedRole;
  final String status;
  final String stationId;
  final DateTime createdAt;
  final DateTime? requestCreatedAt;
  final DateTime? reviewedAt;
  final String rejectionReason;

  factory ManagedUser.fromJson(Map<String, dynamic> json) {
    return ManagedUser(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'sales',
      requestedRole: json['requestedRole']?.toString() ?? 'sales',
      status: json['status']?.toString() ?? 'pending',
      stationId: json['stationId']?.toString() ?? 'station-hq-01',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      requestCreatedAt: DateTime.tryParse(
        json['requestCreatedAt']?.toString() ?? '',
      ),
      reviewedAt: DateTime.tryParse(json['reviewedAt']?.toString() ?? ''),
      rejectionReason: json['rejectionReason']?.toString() ?? '',
    );
  }
}

class UserManagementSummary {
  const UserManagementSummary({
    required this.totalUsers,
    required this.approvedUsers,
    required this.pendingRequests,
    required this.adminCount,
    required this.salesCount,
    required this.superAdminCount,
  });

  final int totalUsers;
  final int approvedUsers;
  final int pendingRequests;
  final int adminCount;
  final int salesCount;
  final int superAdminCount;

  factory UserManagementSummary.fromJson(Map<String, dynamic> json) {
    return UserManagementSummary(
      totalUsers: (json['totalUsers'] as num?)?.toInt() ?? 0,
      approvedUsers: (json['approvedUsers'] as num?)?.toInt() ?? 0,
      pendingRequests: (json['pendingRequests'] as num?)?.toInt() ?? 0,
      adminCount: (json['adminCount'] as num?)?.toInt() ?? 0,
      salesCount: (json['salesCount'] as num?)?.toInt() ?? 0,
      superAdminCount: (json['superAdminCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class UserManagementOverview {
  const UserManagementOverview({
    required this.summary,
    required this.permissions,
    required this.users,
    required this.requests,
  });

  final UserManagementSummary summary;
  final UserManagementPermissions permissions;
  final List<ManagedUser> users;
  final List<AccessRequest> requests;

  factory UserManagementOverview.fromJson(Map<String, dynamic> json) {
    return UserManagementOverview(
      summary: UserManagementSummary.fromJson(
        json['summary'] as Map<String, dynamic>? ?? const {},
      ),
      permissions: UserManagementPermissions.fromJson(
        json['permissions'] as Map<String, dynamic>? ?? const {},
      ),
      users: (json['users'] as List<dynamic>? ?? const [])
          .map((item) => ManagedUser.fromJson(item as Map<String, dynamic>))
          .toList(),
      requests: (json['requests'] as List<dynamic>? ?? const [])
          .map((item) => AccessRequest.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class UserManagementPermissions {
  const UserManagementPermissions({required this.canManageSuperAdmins});

  final bool canManageSuperAdmins;

  factory UserManagementPermissions.fromJson(Map<String, dynamic> json) {
    return UserManagementPermissions(
      canManageSuperAdmins: json['canManageSuperAdmins'] as bool? ?? false,
    );
  }
}
