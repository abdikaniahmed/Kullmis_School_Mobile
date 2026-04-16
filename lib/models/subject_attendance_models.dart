class SubjectAttendanceFilters {
  const SubjectAttendanceFilters({
    required this.academicYearId,
    required this.levels,
    required this.classes,
    required this.periods,
    required this.periodsPerDay,
  });

  final int academicYearId;
  final List<AttendanceLevel> levels;
  final List<AttendanceClass> classes;
  final List<AttendancePeriod> periods;
  final int periodsPerDay;

  factory SubjectAttendanceFilters.fromJson(Map<String, dynamic> json) {
    final levels = (json['levels'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(AttendanceLevel.fromJson)
        .toList();
    final classes = (json['classes'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(AttendanceClass.fromJson)
        .toList();
    final periods = (json['periods'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(AttendancePeriod.fromJson)
        .toList();

    return SubjectAttendanceFilters(
      academicYearId: _toInt(json['academic_year_id']),
      levels: levels,
      classes: classes,
      periods: periods,
      periodsPerDay: _toInt(json['periods_per_day']),
    );
  }
}

class AttendanceLevel {
  const AttendanceLevel({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  factory AttendanceLevel.fromJson(Map<String, dynamic> json) {
    return AttendanceLevel(
      id: _toInt(json['id']),
      name: '${json['name'] ?? ''}'.trim(),
    );
  }
}

class AttendanceClass {
  const AttendanceClass({
    required this.id,
    required this.name,
    required this.levelId,
  });

  final int id;
  final String name;
  final int levelId;

  factory AttendanceClass.fromJson(Map<String, dynamic> json) {
    return AttendanceClass(
      id: _toInt(json['id']),
      name: '${json['name'] ?? ''}'.trim(),
      levelId: _toInt(json['level_id']),
    );
  }
}

class AttendancePeriod {
  const AttendancePeriod({
    required this.value,
    required this.label,
  });

  final int value;
  final String label;

  factory AttendancePeriod.fromJson(Map<String, dynamic> json) {
    return AttendancePeriod(
      value: _toInt(json['value']),
      label: '${json['label'] ?? ''}'.trim(),
    );
  }
}

class SubjectAttendanceSessionData {
  const SubjectAttendanceSessionData({
    required this.sessionId,
    required this.academicYearId,
    required this.date,
    required this.dayLabel,
    required this.periodNumber,
    required this.subject,
    required this.teacher,
    required this.schoolClass,
    required this.students,
  });

  final int? sessionId;
  final int academicYearId;
  final String date;
  final String dayLabel;
  final int periodNumber;
  final AttendanceNamedEntity? subject;
  final AttendanceNamedEntity? teacher;
  final AttendanceNamedEntity? schoolClass;
  final List<SubjectAttendanceStudent> students;

  factory SubjectAttendanceSessionData.fromJson(Map<String, dynamic> json) {
    return SubjectAttendanceSessionData(
      sessionId: _toNullableInt(json['session_id']),
      academicYearId: _toInt(json['academic_year_id']),
      date: '${json['date'] ?? ''}'.trim(),
      dayLabel: '${json['day_label'] ?? ''}'.trim(),
      periodNumber: _toInt(json['period_number']),
      subject: AttendanceNamedEntity.fromDynamic(json['subject']),
      teacher: AttendanceNamedEntity.fromDynamic(json['teacher']),
      schoolClass: AttendanceNamedEntity.fromDynamic(json['school_class']),
      students: (json['students'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SubjectAttendanceStudent.fromJson)
          .toList(),
    );
  }
}

class AttendanceNamedEntity {
  const AttendanceNamedEntity({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  static AttendanceNamedEntity? fromDynamic(dynamic value) {
    if (value is! Map<String, dynamic>) {
      return null;
    }

    final id = _toNullableInt(value['id']);
    final name = '${value['name'] ?? ''}'.trim();

    if (id == null && name.isEmpty) {
      return null;
    }

    return AttendanceNamedEntity(
      id: id ?? 0,
      name: name,
    );
  }
}

class SubjectAttendanceStudent {
  const SubjectAttendanceStudent({
    required this.id,
    required this.studentId,
    required this.name,
    required this.rollNumber,
    required this.status,
    required this.remarks,
  });

  final int id;
  final int studentId;
  final String name;
  final String? rollNumber;
  final String status;
  final String remarks;

  factory SubjectAttendanceStudent.fromJson(Map<String, dynamic> json) {
    return SubjectAttendanceStudent(
      id: _toInt(json['id']),
      studentId: _toInt(json['student_id']),
      name: '${json['name'] ?? ''}'.trim(),
      rollNumber: _toNullableString(json['roll_number']),
      status: '${json['status'] ?? 'present'}'.trim(),
      remarks: '${json['remarks'] ?? ''}'.trim(),
    );
  }
}

class SubjectAttendanceRecordDraft {
  const SubjectAttendanceRecordDraft({
    required this.studentId,
    required this.status,
    required this.remarks,
  });

  final int studentId;
  final String status;
  final String remarks;

  Map<String, dynamic> toJson() {
    return {
      'student_id': studentId,
      'status': status,
      'remarks': remarks,
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

  final parsed = int.tryParse('$value');
  return parsed;
}

String? _toNullableString(dynamic value) {
  final normalized = '${value ?? ''}'.trim();
  if (normalized.isEmpty) {
    return null;
  }

  return normalized;
}
