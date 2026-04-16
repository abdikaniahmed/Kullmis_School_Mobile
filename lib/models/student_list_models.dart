class StudentListPage {
  const StudentListPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.from,
    required this.to,
    required this.hasPreviousPage,
    required this.hasNextPage,
  });

  final List<StudentListItem> items;
  final int currentPage;
  final int lastPage;
  final int total;
  final int? from;
  final int? to;
  final bool hasPreviousPage;
  final bool hasNextPage;

  factory StudentListPage.fromJson(Map<String, dynamic> json) {
    final items = (json['data'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(StudentListItem.fromJson)
        .toList();

    return StudentListPage(
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

class StudentListItem {
  const StudentListItem({
    required this.id,
    required this.name,
    required this.phone,
    required this.currentYear,
  });

  final int id;
  final String name;
  final String? phone;
  final StudentCurrentYear? currentYear;

  factory StudentListItem.fromJson(Map<String, dynamic> json) {
    return StudentListItem(
      id: _toInt(json['id']),
      name: '${json['name'] ?? ''}'.trim(),
      phone: _toNullableString(json['phone']),
      currentYear: StudentCurrentYear.fromDynamic(json['current_year']),
    );
  }
}

class StudentCurrentYear {
  const StudentCurrentYear({
    required this.levelId,
    required this.classId,
    required this.rollNumber,
    required this.levelName,
    required this.className,
  });

  final int? levelId;
  final int? classId;
  final String? rollNumber;
  final String? levelName;
  final String? className;

  static StudentCurrentYear? fromDynamic(dynamic value) {
    if (value is! Map<String, dynamic>) {
      return null;
    }

    final level = value['level'];
    final schoolClass = value['school_class'];

    final levelName =
        level is Map<String, dynamic> ? _toNullableString(level['name']) : null;
    final className = schoolClass is Map<String, dynamic>
        ? _toNullableString(schoolClass['name'])
        : null;

    if (levelName == null && className == null) {
      return null;
    }

    return StudentCurrentYear(
      levelId: _toNullableInt(value['level_id']),
      classId: _toNullableInt(value['school_class_id']),
      rollNumber: _toNullableString(value['roll_number']),
      levelName: levelName,
      className: className,
    );
  }
}

extension DisciplineStudentMapper on StudentListItem {
  StudentListItem copyWith({
    int? id,
    String? name,
    String? phone,
    StudentCurrentYear? currentYear,
  }) {
    return StudentListItem(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      currentYear: currentYear ?? this.currentYear,
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
