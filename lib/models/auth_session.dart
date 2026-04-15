class AuthSession {
  const AuthSession({
    required this.token,
    required this.name,
    required this.email,
    required this.roles,
    this.schoolName,
  });

  final String token;
  final String name;
  final String email;
  final List<String> roles;
  final String? schoolName;

  factory AuthSession.fromUserResponse({
    required String token,
    required Map<String, dynamic> payload,
  }) {
    final school = payload['school'];
    final roles = payload['roles'];

    return AuthSession(
      token: token,
      name: '${payload['name'] ?? ''}'.trim(),
      email: '${payload['email'] ?? ''}'.trim(),
      roles: _roleNames(roles),
      schoolName: school is Map ? '${school['name'] ?? ''}'.trim() : null,
    );
  }

  static List<String> _roleNames(dynamic roles) {
    if (roles is! List) {
      return const [];
    }

    return roles
        .map((role) {
          if (role is Map) {
            return '${role['name'] ?? ''}'.trim();
          }

          return '$role'.trim();
        })
        .where((role) => role.isNotEmpty)
        .cast<String>()
        .toList();
  }
}
