class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    required this.stationId,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final String status;
  final String stationId;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'sales',
      status: json['status']?.toString() ?? 'pending',
      stationId: json['stationId']?.toString() ?? 'station-hq-01',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'status': status,
      'stationId': stationId,
    };
  }
}

class AuthResponse {
  const AuthResponse({required this.user, required this.token});

  final AuthUser user;
  final String token;

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      user: AuthUser.fromJson((json['user'] as Map<String, dynamic>? ?? {})),
      token: json['token']?.toString() ?? '',
    );
  }
}
