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

  Map<String, dynamic> toJson() {
    return {
      'academic_year_id': academicYearId,
      'levels': levels.map((item) => item.toJson()).toList(),
      'classes': classes.map((item) => item.toJson()).toList(),
      'periods': periods.map((item) => item.toJson()).toList(),
      'periods_per_day': periodsPerDay,
    };
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'level_id': levelId,
    };
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

  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'label': label,
    };
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

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'academic_year_id': academicYearId,
      'date': date,
      'day_label': dayLabel,
      'period_number': periodNumber,
      'subject': subject?.toJson(),
      'teacher': teacher?.toJson(),
      'school_class': schoolClass?.toJson(),
      'students': students.map((item) => item.toJson()).toList(),
    };
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'name': name,
      'roll_number': rollNumber,
      'status': status,
      'remarks': remarks,
    };
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

class SubjectAttendanceDraftState {
  const SubjectAttendanceDraftState({
    required this.status,
    required this.remarks,
  });

  final String status;
  final String remarks;

  factory SubjectAttendanceDraftState.fromJson(Map<String, dynamic> json) {
    return SubjectAttendanceDraftState(
      status: '${json['status'] ?? 'present'}'.trim(),
      remarks: '${json['remarks'] ?? ''}'.trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'remarks': remarks,
    };
  }
}

class SubjectAttendanceOfflineSnapshot {
  const SubjectAttendanceOfflineSnapshot({
    required this.filters,
    required this.selectedLevelId,
    required this.selectedClassId,
    required this.selectedPeriodNumber,
    required this.selectedDate,
    required this.session,
    required this.drafts,
  });

  final SubjectAttendanceFilters? filters;
  final int? selectedLevelId;
  final int? selectedClassId;
  final int? selectedPeriodNumber;
  final String selectedDate;
  final SubjectAttendanceSessionData? session;
  final Map<int, SubjectAttendanceDraftState> drafts;

  factory SubjectAttendanceOfflineSnapshot.fromJson(
    Map<String, dynamic> json,
  ) {
    final draftsJson = json['drafts'] as Map<String, dynamic>? ?? const {};

    return SubjectAttendanceOfflineSnapshot(
      filters: json['filters'] is Map<String, dynamic>
          ? SubjectAttendanceFilters.fromJson(
              json['filters'] as Map<String, dynamic>,
            )
          : null,
      selectedLevelId: _toNullableInt(json['selected_level_id']),
      selectedClassId: _toNullableInt(json['selected_class_id']),
      selectedPeriodNumber: _toNullableInt(json['selected_period_number']),
      selectedDate: '${json['selected_date'] ?? ''}',
      session: json['session'] is Map<String, dynamic>
          ? SubjectAttendanceSessionData.fromJson(
              json['session'] as Map<String, dynamic>,
            )
          : null,
      drafts: {
        for (final entry in draftsJson.entries)
          _toInt(entry.key): SubjectAttendanceDraftState.fromJson(
            entry.value as Map<String, dynamic>? ?? const {},
          ),
      },
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'filters': filters?.toJson(),
      'selected_level_id': selectedLevelId,
      'selected_class_id': selectedClassId,
      'selected_period_number': selectedPeriodNumber,
      'selected_date': selectedDate,
      'session': session?.toJson(),
      'drafts': {
        for (final entry in drafts.entries) '${entry.key}': entry.value.toJson(),
      },
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
