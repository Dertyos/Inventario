class TeamMemberModel {
  final String id;
  final String userId;
  final String email;
  final String firstName;
  final String lastName;
  final String role;
  final bool isActive;
  final DateTime joinedAt;

  const TeamMemberModel({
    required this.id,
    required this.userId,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.isActive = true,
    required this.joinedAt,
  });

  String get fullName => '$firstName $lastName'.trim();

  String get roleLabel {
    switch (role) {
      case 'owner':
        return 'Dueño';
      case 'admin':
        return 'Administrador';
      case 'manager':
        return 'Gerente';
      case 'staff':
        return 'Personal';
      default:
        return role;
    }
  }

  factory TeamMemberModel.fromJson(Map<String, dynamic> json) {
    // The API may nest user data inside a 'user' field
    final user = json['user'] as Map<String, dynamic>? ?? {};
    return TeamMemberModel(
      id: json['id'] as String,
      userId: json['userId'] as String? ?? user['id'] as String? ?? '',
      email: json['email'] as String? ?? user['email'] as String? ?? '',
      firstName:
          json['firstName'] as String? ?? user['firstName'] as String? ?? '',
      lastName:
          json['lastName'] as String? ?? user['lastName'] as String? ?? '',
      role: json['role'] as String? ?? 'staff',
      isActive: json['isActive'] as bool? ?? true,
      joinedAt: DateTime.parse(
        json['joinedAt'] as String? ??
            json['createdAt'] as String? ??
            DateTime.now().toIso8601String(),
      ),
    );
  }
}
