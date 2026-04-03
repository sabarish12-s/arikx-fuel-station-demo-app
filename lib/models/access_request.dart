class AccessRequest {
  const AccessRequest({
    required this.id,
    required this.userId,
    required this.stationId,
    required this.name,
    required this.email,
    required this.roleRequested,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String stationId;
  final String name;
  final String email;
  final String roleRequested;
  final String status;
  final DateTime createdAt;

  factory AccessRequest.fromJson(Map<String, dynamic> json) {
    return AccessRequest(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      stationId: json['stationId']?.toString() ?? 'station-hq-01',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      roleRequested: json['roleRequested']?.toString() ?? 'sales',
      status: json['status']?.toString() ?? 'pending',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
