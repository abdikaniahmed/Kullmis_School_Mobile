class AuthSession {
  const AuthSession({
    required this.token,
    required this.name,
    required this.email,
    required this.roles,
    required this.permissions,
    this.schoolName,
  });

  final String token;
  final String name;
  final String email;
  final List<String> roles;
  final List<String> permissions;
  final String? schoolName;

  bool hasPermission(String permission) {
    return permissions.any(
      (entry) => entry.toLowerCase() == permission.toLowerCase(),
    );
  }

  bool hasAnyPermission(Iterable<String> values) {
    for (final value in values) {
      if (hasPermission(value)) {
        return true;
      }
    }

    return false;
  }

  factory AuthSession.fromUserResponse({
    required String token,
    required Map<String, dynamic> payload,
  }) {
    final school = payload['school'];
    final roles = payload['roles'];
    final permissions = payload['permissions'];

    return AuthSession(
      token: token,
      name: '${payload['name'] ?? ''}'.trim(),
      email: '${payload['email'] ?? ''}'.trim(),
      roles: _roleNames(roles),
      permissions: _stringValues(permissions),
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

  static List<String> _stringValues(dynamic values) {
    if (values is! List) {
      return const [];
    }

    return values
        .map((value) => '$value'.trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }
}
