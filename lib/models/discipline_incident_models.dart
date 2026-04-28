class DisciplineIncidentPage {
  const DisciplineIncidentPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.from,
    required this.to,
    required this.hasPreviousPage,
    required this.hasNextPage,
  });

  final List<DisciplineIncidentItem> items;
  final int currentPage;
  final int lastPage;
  final int total;
  final int? from;
  final int? to;
  final bool hasPreviousPage;
  final bool hasNextPage;

  factory DisciplineIncidentPage.fromJson(Map<String, dynamic> json) {
    final items = (json['data'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(DisciplineIncidentItem.fromJson)
        .toList();

    return DisciplineIncidentPage(
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

class DisciplineIncidentItem {
  const DisciplineIncidentItem({
    required this.id,
    required this.studentId,
    required this.reportedBy,
    required this.whatHappened,
    required this.happenedAt,
    required this.actionTaken,
    required this.createdAt,
    required this.student,
  });

  final int id;
  final int studentId;
  final String? reportedBy;
  final String whatHappened;
  final String? happenedAt;
  final String? actionTaken;
  final String? createdAt;
  final DisciplineIncidentStudentSummary? student;

  factory DisciplineIncidentItem.fromJson(Map<String, dynamic> json) {
    return DisciplineIncidentItem(
      id: _toInt(json['id']),
      studentId: _toInt(json['student_id']),
      reportedBy: _toNullableString(json['reported_by']),
      whatHappened: '${json['what_happened'] ?? ''}'.trim(),
      happenedAt: _toNullableString(json['happened_at']),
      actionTaken: _toNullableString(json['action_taken']),
      createdAt: _toNullableString(json['created_at']),
      student: DisciplineIncidentStudentSummary.fromDynamic(json['student']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'reported_by': reportedBy,
      'what_happened': whatHappened,
      'happened_at': happenedAt,
      'action_taken': actionTaken,
      'created_at': createdAt,
      'student': student?.toJson(),
    };
  }
}

class DisciplineIncidentStudentSummary {
  const DisciplineIncidentStudentSummary({
    required this.id,
    required this.name,
    required this.phone,
    required this.levelId,
    required this.classId,
    required this.levelName,
    required this.className,
    required this.rollNumber,
  });

  final int id;
  final String name;
  final String? phone;
  final int? levelId;
  final int? classId;
  final String? levelName;
  final String? className;
  final String? rollNumber;

  static DisciplineIncidentStudentSummary? fromDynamic(dynamic value) {
    if (value is! Map<String, dynamic>) {
      return null;
    }

    final currentYear = value['current_year'];
    final level = currentYear is Map<String, dynamic> ? currentYear['level'] : null;
    final schoolClass =
        currentYear is Map<String, dynamic> ? currentYear['school_class'] : null;

    return DisciplineIncidentStudentSummary(
      id: _toInt(value['id']),
      name: '${value['name'] ?? ''}'.trim(),
      phone: _toNullableString(value['phone']),
      levelId: currentYear is Map<String, dynamic>
        ? _toNullableInt(currentYear['level_id'])
        : null,
      classId: currentYear is Map<String, dynamic>
        ? _toNullableInt(currentYear['school_class_id'])
        : null,
      levelName:
          level is Map<String, dynamic> ? _toNullableString(level['name']) : null,
      className: schoolClass is Map<String, dynamic>
          ? _toNullableString(schoolClass['name'])
          : null,
      rollNumber: currentYear is Map<String, dynamic>
          ? _toNullableString(currentYear['roll_number'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'current_year': {
        'level_id': levelId,
        'school_class_id': classId,
        'roll_number': rollNumber,
        'level': levelName == null ? null : {'name': levelName},
        'school_class': className == null ? null : {'name': className},
      },
    };
  }
}

class DisciplineIncidentsOfflineSnapshot {
  const DisciplineIncidentsOfflineSnapshot({
    required this.levels,
    required this.classes,
    required this.page,
    required this.selectedLevelId,
    required this.selectedClassId,
    required this.search,
  });

  final List<dynamic> levels;
  final List<dynamic> classes;
  final DisciplineIncidentPage? page;
  final int? selectedLevelId;
  final int? selectedClassId;
  final String search;

  factory DisciplineIncidentsOfflineSnapshot.fromJson(
    Map<String, dynamic> json,
  ) {
    return DisciplineIncidentsOfflineSnapshot(
      levels: (json['levels'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(),
      classes: (json['classes'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(),
      page: json['page'] is Map<String, dynamic>
          ? DisciplineIncidentPage.fromJson(json['page'] as Map<String, dynamic>)
          : null,
      selectedLevelId: _toNullableInt(json['selected_level_id']),
      selectedClassId: _toNullableInt(json['selected_class_id']),
      search: '${json['search'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson({
    required List<Map<String, dynamic>> levels,
    required List<Map<String, dynamic>> classes,
  }) {
    return {
      'levels': levels,
      'classes': classes,
      'page': page?.toJson(),
      'selected_level_id': selectedLevelId,
      'selected_class_id': selectedClassId,
      'search': search,
    };
  }
}

class StudentIncidentReport {
  const StudentIncidentReport({
    required this.generatedAt,
    required this.student,
    required this.incidents,
  });

  final String? generatedAt;
  final StudentIncidentReportStudent student;
  final List<DisciplineIncidentItem> incidents;

  factory StudentIncidentReport.fromJson(Map<String, dynamic> json) {
    return StudentIncidentReport(
      generatedAt: _toNullableString(json['generated_at']),
      student: StudentIncidentReportStudent.fromJson(
        json['student'] as Map<String, dynamic>? ?? const {},
      ),
      incidents: (json['incidents'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(DisciplineIncidentItem.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'generated_at': generatedAt,
      'student': student.toJson(),
      'incidents': incidents.map((item) => item.toJson()).toList(),
    };
  }
}

class StudentIncidentReportStudent {
  const StudentIncidentReportStudent({
    required this.id,
    required this.name,
    required this.rollNumber,
    required this.levelName,
    required this.className,
  });

  final int id;
  final String name;
  final String? rollNumber;
  final String? levelName;
  final String? className;

  factory StudentIncidentReportStudent.fromJson(Map<String, dynamic> json) {
    return StudentIncidentReportStudent(
      id: _toInt(json['id']),
      name: '${json['name'] ?? ''}'.trim(),
      rollNumber: _toNullableString(json['roll_number']),
      levelName: _toNullableString(json['level_name']),
      className: _toNullableString(json['class_name']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'roll_number': rollNumber,
      'level_name': levelName,
      'class_name': className,
    };
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
