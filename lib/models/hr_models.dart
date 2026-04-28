class StaffListPage {
  const StaffListPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.from,
    required this.to,
    required this.hasPreviousPage,
    required this.hasNextPage,
  });

  final List<StaffMember> items;
  final int currentPage;
  final int lastPage;
  final int total;
  final int? from;
  final int? to;
  final bool hasPreviousPage;
  final bool hasNextPage;

  factory StaffListPage.fromJson(Map<String, dynamic> json) {
    final items = (json['data'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(StaffMember.fromJson)
        .toList();

    return StaffListPage(
      items: items,
      currentPage: _toInt(json['current_page']),
      lastPage: _toInt(json['last_page']),
      total: _toInt(json['total']),
      from: _toNullableInt(json['from']),
      to: _toNullableInt(json['to']),
      hasPreviousPage: json['prev_page_url'] != null,
      hasNextPage: json['next_page_url'] != null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'data': items.map((item) => item.toJson()).toList(),
      'current_page': currentPage,
      'last_page': lastPage,
      'total': total,
      'from': from,
      'to': to,
      'prev_page_url': hasPreviousPage ? 'cached' : null,
      'next_page_url': hasNextPage ? 'cached' : null,
    };
  }
}

class StaffMember {
  const StaffMember({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.position,
    required this.type,
    required this.address,
    required this.dateOfBirth,
    required this.gender,
    required this.user,
  });

  final int id;
  final String name;
  final String? phone;
  final String? email;
  final String? position;
  final String type;
  final String? address;
  final String? dateOfBirth;
  final String? gender;
  final UserSummary? user;

  factory StaffMember.fromJson(Map<String, dynamic> json) {
    return StaffMember(
      id: _toInt(json['id']),
      name: '${json['name'] ?? ''}'.trim(),
      phone: _toNullableString(json['phone']),
      email: _toNullableString(json['email']),
      position: _toNullableString(json['position']),
      type: '${json['type'] ?? ''}'.trim(),
      address: _toNullableString(json['address']),
      dateOfBirth: _toNullableString(json['date_of_birth']),
      gender: _toNullableString(json['gender']),
      user: UserSummary.fromDynamic(json['user']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'position': position,
      'type': type,
      'address': address,
      'date_of_birth': dateOfBirth,
      'gender': gender,
      'user': user?.toJson(),
    };
  }
}

class TeacherListPage {
  const TeacherListPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.from,
    required this.to,
    required this.hasPreviousPage,
    required this.hasNextPage,
  });

  final List<TeacherSummary> items;
  final int currentPage;
  final int lastPage;
  final int total;
  final int? from;
  final int? to;
  final bool hasPreviousPage;
  final bool hasNextPage;

  factory TeacherListPage.fromJson(Map<String, dynamic> json) {
    final items = (json['data'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(TeacherSummary.fromJson)
        .toList();

    return TeacherListPage(
      items: items,
      currentPage: _toInt(json['current_page']),
      lastPage: _toInt(json['last_page']),
      total: _toInt(json['total']),
      from: _toNullableInt(json['from']),
      to: _toNullableInt(json['to']),
      hasPreviousPage: json['prev_page_url'] != null,
      hasNextPage: json['next_page_url'] != null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'data': items.map((item) => item.toJson()).toList(),
      'current_page': currentPage,
      'last_page': lastPage,
      'total': total,
      'from': from,
      'to': to,
      'prev_page_url': hasPreviousPage ? 'cached' : null,
      'next_page_url': hasNextPage ? 'cached' : null,
    };
  }
}

class TeacherSummary {
  const TeacherSummary({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.position,
    required this.classAssignmentsCount,
    required this.subjectAssignmentsCount,
  });

  final int id;
  final String name;
  final String? email;
  final String? phone;
  final String? position;
  final int classAssignmentsCount;
  final int subjectAssignmentsCount;

  factory TeacherSummary.fromJson(Map<String, dynamic> json) {
    return TeacherSummary(
      id: _toInt(json['id']),
      name: '${json['name'] ?? ''}'.trim(),
      email: _toNullableString(json['email']),
      phone: _toNullableString(json['phone']),
      position: _toNullableString(json['position']),
      classAssignmentsCount: _toInt(json['class_assignments_count']),
      subjectAssignmentsCount: _toInt(json['subject_assignments_count']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'position': position,
      'class_assignments_count': classAssignmentsCount,
      'subject_assignments_count': subjectAssignmentsCount,
    };
  }
}

class TeacherProfile {
  const TeacherProfile({
    required this.employeeNumber,
    required this.qualification,
    required this.specialization,
    required this.joiningDate,
    required this.experienceYears,
    required this.status,
    required this.bio,
  });

  final String? employeeNumber;
  final String? qualification;
  final String? specialization;
  final String? joiningDate;
  final int? experienceYears;
  final String? status;
  final String? bio;

  factory TeacherProfile.fromDynamic(dynamic value) {
    if (value is! Map<String, dynamic>) {
      return const TeacherProfile(
        employeeNumber: null,
        qualification: null,
        specialization: null,
        joiningDate: null,
        experienceYears: null,
        status: null,
        bio: null,
      );
    }

    return TeacherProfile(
      employeeNumber: _toNullableString(value['employee_number']),
      qualification: _toNullableString(value['qualification']),
      specialization: _toNullableString(value['specialization']),
      joiningDate: _toNullableString(value['joining_date']),
      experienceYears: _toNullableInt(value['experience_years']),
      status: _toNullableString(value['status']),
      bio: _toNullableString(value['bio']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employee_number': employeeNumber,
      'qualification': qualification,
      'specialization': specialization,
      'joining_date': joiningDate,
      'experience_years': experienceYears,
      'status': status,
      'bio': bio,
    };
  }
}

class TeacherDetail {
  const TeacherDetail({
    required this.teacher,
    required this.profile,
  });

  final StaffMember teacher;
  final TeacherProfile profile;

  factory TeacherDetail.fromJson(Map<String, dynamic> json) {
    final teacher = json['teacher'];
    return TeacherDetail(
      teacher: teacher is Map<String, dynamic>
          ? StaffMember.fromJson(teacher)
          : StaffMember.fromJson(json),
      profile: TeacherProfile.fromDynamic(
        teacher is Map<String, dynamic> ? teacher['teacher_profile'] : null,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'teacher': teacher.toJson(),
      'teacher_profile': profile.toJson(),
    };
  }
}

class DocumentPage {
  const DocumentPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.from,
    required this.to,
    required this.hasPreviousPage,
    required this.hasNextPage,
  });

  final List<DocumentItem> items;
  final int currentPage;
  final int lastPage;
  final int total;
  final int? from;
  final int? to;
  final bool hasPreviousPage;
  final bool hasNextPage;

  factory DocumentPage.fromJson(Map<String, dynamic> json) {
    final items = (json['data'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(DocumentItem.fromJson)
        .toList();

    return DocumentPage(
      items: items,
      currentPage: _toInt(json['current_page']),
      lastPage: _toInt(json['last_page']),
      total: _toInt(json['total']),
      from: _toNullableInt(json['from']),
      to: _toNullableInt(json['to']),
      hasPreviousPage: json['prev_page_url'] != null,
      hasNextPage: json['next_page_url'] != null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'data': items.map((item) => item.toJson()).toList(),
      'current_page': currentPage,
      'last_page': lastPage,
      'total': total,
      'from': from,
      'to': to,
      'prev_page_url': hasPreviousPage ? 'cached' : null,
      'next_page_url': hasNextPage ? 'cached' : null,
    };
  }
}

class DocumentItem {
  const DocumentItem({
    required this.id,
    required this.scope,
    required this.staffId,
    required this.category,
    required this.title,
    required this.description,
    required this.status,
    required this.issuedAt,
    required this.expiresAt,
    required this.fileName,
    required this.mimeType,
    required this.fileSize,
    required this.viewUrl,
    required this.downloadUrl,
    required this.staff,
    required this.uploadedBy,
  });

  final int id;
  final String scope;
  final int? staffId;
  final String category;
  final String title;
  final String? description;
  final String status;
  final String? issuedAt;
  final String? expiresAt;
  final String fileName;
  final String mimeType;
  final int fileSize;
  final String? viewUrl;
  final String? downloadUrl;
  final StaffSummary? staff;
  final UserSummary? uploadedBy;

  factory DocumentItem.fromJson(Map<String, dynamic> json) {
    return DocumentItem(
      id: _toInt(json['id']),
      scope: '${json['scope'] ?? ''}'.trim(),
      staffId: _toNullableInt(json['staff_id']),
      category: '${json['category'] ?? ''}'.trim(),
      title: '${json['title'] ?? ''}'.trim(),
      description: _toNullableString(json['description']),
      status: '${json['status'] ?? ''}'.trim(),
      issuedAt: _toNullableString(json['issued_at']),
      expiresAt: _toNullableString(json['expires_at']),
      fileName: '${json['file_name'] ?? ''}'.trim(),
      mimeType: '${json['mime_type'] ?? ''}'.trim(),
      fileSize: _toInt(json['file_size']),
      viewUrl: _toNullableString(json['view_url']),
      downloadUrl: _toNullableString(json['download_url']),
      staff: StaffSummary.fromDynamic(json['staff']),
      uploadedBy: UserSummary.fromDynamic(json['uploaded_by']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'scope': scope,
      'staff_id': staffId,
      'category': category,
      'title': title,
      'description': description,
      'status': status,
      'issued_at': issuedAt,
      'expires_at': expiresAt,
      'file_name': fileName,
      'mime_type': mimeType,
      'file_size': fileSize,
      'view_url': viewUrl,
      'download_url': downloadUrl,
      'staff': staff?.toJson(),
      'uploaded_by': uploadedBy?.toJson(),
    };
  }
}

class DocumentCategoryOptions {
  const DocumentCategoryOptions({
    required this.categories,
    required this.statuses,
  });

  final List<String> categories;
  final List<String> statuses;

  factory DocumentCategoryOptions.fromJson(Map<String, dynamic> json) {
    final categories = (json['categories'] as List<dynamic>? ?? const [])
        .map((value) => '$value'.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    final statuses = (json['statuses'] as List<dynamic>? ?? const [])
        .map((value) => '$value'.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    return DocumentCategoryOptions(
      categories: categories,
      statuses: statuses,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'categories': categories,
      'statuses': statuses,
    };
  }
}

class StaffSummary {
  const StaffSummary({
    required this.id,
    required this.name,
    required this.type,
    required this.position,
  });

  final int id;
  final String name;
  final String? type;
  final String? position;

  static StaffSummary? fromDynamic(dynamic value) {
    if (value is! Map<String, dynamic>) {
      return null;
    }

    return StaffSummary(
      id: _toInt(value['id']),
      name: '${value['name'] ?? ''}'.trim(),
      type: _toNullableString(value['type']),
      position: _toNullableString(value['position']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'position': position,
    };
  }
}

class UserListPage {
  const UserListPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.from,
    required this.to,
    required this.hasPreviousPage,
    required this.hasNextPage,
  });

  final List<UserDetail> items;
  final int currentPage;
  final int lastPage;
  final int total;
  final int? from;
  final int? to;
  final bool hasPreviousPage;
  final bool hasNextPage;

  factory UserListPage.fromJson(Map<String, dynamic> json) {
    final items = (json['data'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(UserDetail.fromJson)
        .toList();

    return UserListPage(
      items: items,
      currentPage: _toInt(json['current_page']),
      lastPage: _toInt(json['last_page']),
      total: _toInt(json['total']),
      from: _toNullableInt(json['from']),
      to: _toNullableInt(json['to']),
      hasPreviousPage: json['prev_page_url'] != null,
      hasNextPage: json['next_page_url'] != null,
    );
  }
}

class UserDetail {
  const UserDetail({
    required this.id,
    required this.name,
    required this.email,
    required this.roles,
    required this.staff,
  });

  final int id;
  final String name;
  final String email;
  final List<RoleSummary> roles;
  final StaffSummary? staff;

  factory UserDetail.fromJson(Map<String, dynamic> json) {
    final roles = (json['roles'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(RoleSummary.fromJson)
        .toList();

    return UserDetail(
      id: _toInt(json['id']),
      name: '${json['name'] ?? ''}'.trim(),
      email: '${json['email'] ?? ''}'.trim(),
      roles: roles,
      staff: StaffSummary.fromDynamic(json['staff']),
    );
  }
}

class StaffOption {
  const StaffOption({
    required this.id,
    required this.name,
    required this.position,
  });

  final int id;
  final String name;
  final String? position;

  factory StaffOption.fromJson(Map<String, dynamic> json) {
    return StaffOption(
      id: _toInt(json['id']),
      name: '${json['name'] ?? ''}'.trim(),
      position: _toNullableString(json['position']),
    );
  }
}

class UserCreateMeta {
  const UserCreateMeta({
    required this.staffs,
    required this.roles,
  });

  final List<StaffOption> staffs;
  final List<RoleSummary> roles;

  factory UserCreateMeta.fromJson(Map<String, dynamic> json) {
    final staffs = (json['staffs'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(StaffOption.fromJson)
        .toList();

    final roles = (json['roles'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(RoleSummary.fromJson)
        .toList();

    return UserCreateMeta(staffs: staffs, roles: roles);
  }
}

class UserEditMeta {
  const UserEditMeta({
    required this.user,
    required this.roles,
  });

  final UserDetail user;
  final List<RoleSummary> roles;

  factory UserEditMeta.fromJson(Map<String, dynamic> json) {
    final roles = (json['roles'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(RoleSummary.fromJson)
        .toList();

    return UserEditMeta(
      user: UserDetail.fromJson(
        (json['user'] as Map<String, dynamic>? ?? const {}),
      ),
      roles: roles,
    );
  }
}

class UserSummary {
  const UserSummary({
    required this.id,
    required this.name,
    required this.email,
  });

  final int id;
  final String name;
  final String? email;

  static UserSummary? fromDynamic(dynamic value) {
    if (value is! Map<String, dynamic>) {
      return null;
    }

    return UserSummary(
      id: _toInt(value['id']),
      name: '${value['name'] ?? ''}'.trim(),
      email: _toNullableString(value['email']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
    };
  }
}

class StaffOfflineSnapshot {
  const StaffOfflineSnapshot({
    required this.page,
    required this.search,
    required this.typeFilter,
  });

  final StaffListPage? page;
  final String search;
  final String typeFilter;

  factory StaffOfflineSnapshot.fromJson(Map<String, dynamic> json) {
    return StaffOfflineSnapshot(
      page: json['page'] is Map<String, dynamic>
          ? StaffListPage.fromJson(json['page'] as Map<String, dynamic>)
          : null,
      search: '${json['search'] ?? ''}',
      typeFilter: '${json['type_filter'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'page': page?.toJson(),
      'search': search,
      'type_filter': typeFilter,
    };
  }
}

class DocumentsOfflineSnapshot {
  const DocumentsOfflineSnapshot({
    required this.options,
    required this.page,
    required this.search,
    required this.staffId,
    required this.scopeFilter,
    required this.categoryFilter,
    required this.statusFilter,
  });

  final DocumentCategoryOptions? options;
  final DocumentPage? page;
  final String search;
  final String staffId;
  final String scopeFilter;
  final String categoryFilter;
  final String statusFilter;

  factory DocumentsOfflineSnapshot.fromJson(Map<String, dynamic> json) {
    return DocumentsOfflineSnapshot(
      options: json['options'] is Map<String, dynamic>
          ? DocumentCategoryOptions.fromJson(
              json['options'] as Map<String, dynamic>,
            )
          : null,
      page: json['page'] is Map<String, dynamic>
          ? DocumentPage.fromJson(json['page'] as Map<String, dynamic>)
          : null,
      search: '${json['search'] ?? ''}',
      staffId: '${json['staff_id'] ?? ''}',
      scopeFilter: '${json['scope_filter'] ?? ''}',
      categoryFilter: '${json['category_filter'] ?? ''}',
      statusFilter: '${json['status_filter'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'options': options?.toJson(),
      'page': page?.toJson(),
      'search': search,
      'staff_id': staffId,
      'scope_filter': scopeFilter,
      'category_filter': categoryFilter,
      'status_filter': statusFilter,
    };
  }
}

class TeachersOfflineSnapshot {
  const TeachersOfflineSnapshot({
    required this.page,
    required this.search,
  });

  final TeacherListPage? page;
  final String search;

  factory TeachersOfflineSnapshot.fromJson(Map<String, dynamic> json) {
    return TeachersOfflineSnapshot(
      page: json['page'] is Map<String, dynamic>
          ? TeacherListPage.fromJson(json['page'] as Map<String, dynamic>)
          : null,
      search: '${json['search'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'page': page?.toJson(),
      'search': search,
    };
  }
}

class TeacherDetailOfflineSnapshot {
  const TeacherDetailOfflineSnapshot({
    required this.detail,
  });

  final TeacherDetail detail;

  factory TeacherDetailOfflineSnapshot.fromJson(Map<String, dynamic> json) {
    return TeacherDetailOfflineSnapshot(
      detail: TeacherDetail.fromJson(
        json['detail'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'detail': detail.toJson(),
    };
  }
}

class RoleSummary {
  const RoleSummary({
    required this.id,
    required this.name,
    required this.permissions,
  });

  final int id;
  final String name;
  final List<PermissionSummary> permissions;

  factory RoleSummary.fromJson(Map<String, dynamic> json) {
    final permissions = (json['permissions'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PermissionSummary.fromJson)
        .toList();

    return RoleSummary(
      id: _toInt(json['id']),
      name: '${json['name'] ?? ''}'.trim(),
      permissions: permissions,
    );
  }
}

class PermissionSummary {
  const PermissionSummary({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  factory PermissionSummary.fromJson(Map<String, dynamic> json) {
    return PermissionSummary(
      id: _toInt(json['id']),
      name: '${json['name'] ?? ''}'.trim(),
    );
  }
}

class PermissionGroup {
  const PermissionGroup({
    required this.name,
    required this.permissions,
  });

  final String name;
  final List<PermissionSummary> permissions;

  factory PermissionGroup.fromJson(String name, List<dynamic> values) {
    final permissions = values
        .whereType<Map<String, dynamic>>()
        .map(PermissionSummary.fromJson)
        .toList();

    return PermissionGroup(name: name, permissions: permissions);
  }
}

class RoleIndexPayload {
  const RoleIndexPayload({
    required this.roles,
    required this.permissionGroups,
  });

  final List<RoleSummary> roles;
  final List<PermissionGroup> permissionGroups;

  factory RoleIndexPayload.fromJson(Map<String, dynamic> json) {
    final roles = (json['roles'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(RoleSummary.fromJson)
        .toList();

    final permissions = json['permissions'];
    final groups = <PermissionGroup>[];

    if (permissions is Map<String, dynamic>) {
      permissions.forEach((key, value) {
        if (value is List) {
          groups.add(PermissionGroup.fromJson(key, value));
        }
      });
    }

    return RoleIndexPayload(roles: roles, permissionGroups: groups);
  }
}

class AuditLogPage {
  const AuditLogPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.from,
    required this.to,
    required this.hasPreviousPage,
    required this.hasNextPage,
  });

  final List<AuditLogItem> items;
  final int currentPage;
  final int lastPage;
  final int total;
  final int? from;
  final int? to;
  final bool hasPreviousPage;
  final bool hasNextPage;

  factory AuditLogPage.fromJson(Map<String, dynamic> json) {
    final items = (json['data'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(AuditLogItem.fromJson)
        .toList();

    return AuditLogPage(
      items: items,
      currentPage: _toInt(json['current_page']),
      lastPage: _toInt(json['last_page']),
      total: _toInt(json['total']),
      from: _toNullableInt(json['from']),
      to: _toNullableInt(json['to']),
      hasPreviousPage: json['prev_page_url'] != null,
      hasNextPage: json['next_page_url'] != null,
    );
  }
}

class AuditLogItem {
  const AuditLogItem({
    required this.id,
    required this.description,
    required this.event,
    required this.logName,
    required this.subjectType,
    required this.subjectId,
    required this.causer,
    required this.createdAt,
  });

  final int id;
  final String? description;
  final String? event;
  final String? logName;
  final String? subjectType;
  final int? subjectId;
  final UserSummary? causer;
  final String? createdAt;

  factory AuditLogItem.fromJson(Map<String, dynamic> json) {
    return AuditLogItem(
      id: _toInt(json['id']),
      description: _toNullableString(json['description']),
      event: _toNullableString(json['event']),
      logName: _toNullableString(json['log_name']),
      subjectType: _toNullableString(json['subject_type']),
      subjectId: _toNullableInt(json['subject_id']),
      causer: UserSummary.fromDynamic(json['causer']),
      createdAt: _toNullableString(json['created_at']),
    );
  }
}

class AuditFilterOptions {
  const AuditFilterOptions({
    required this.users,
    required this.actions,
    required this.models,
  });

  final List<UserSummary> users;
  final List<String> actions;
  final List<AuditModelOption> models;

  factory AuditFilterOptions.fromJson(Map<String, dynamic> json) {
    final users = (json['users'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(UserSummary.fromDynamic)
        .whereType<UserSummary>()
        .toList();

    final actions = (json['actions'] as List<dynamic>? ?? const [])
        .map((value) => '$value'.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    final models = (json['models'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(AuditModelOption.fromJson)
        .toList();

    return AuditFilterOptions(users: users, actions: actions, models: models);
  }
}

class AuditModelOption {
  const AuditModelOption({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  factory AuditModelOption.fromJson(Map<String, dynamic> json) {
    return AuditModelOption(
      value: '${json['value'] ?? ''}'.trim(),
      label: '${json['label'] ?? ''}'.trim(),
    );
  }
}

int _toInt(dynamic value) {
  if (value is int) {
    return value;
  }

  if (value is double) {
    return value.round();
  }

  return int.tryParse('$value') ?? 0;
}

int? _toNullableInt(dynamic value) {
  if (value == null) {
    return null;
  }

  return int.tryParse('$value');
}

String? _toNullableString(dynamic value) {
  final normalized = '${value ?? ''}'.trim();
  if (normalized.isEmpty) {
    return null;
  }

  return normalized;
}
