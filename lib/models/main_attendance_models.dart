class ActiveAcademicYear {
  const ActiveAcademicYear({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  factory ActiveAcademicYear.fromJson(Map<String, dynamic> json) {
    return ActiveAcademicYear(
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

class MainAttendanceLevel {
  const MainAttendanceLevel({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  factory MainAttendanceLevel.fromJson(Map<String, dynamic> json) {
    return MainAttendanceLevel(
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

class MainAttendanceClass {
  const MainAttendanceClass({
    required this.id,
    required this.name,
    required this.levelId,
  });

  final int id;
  final String name;
  final int levelId;

  factory MainAttendanceClass.fromJson(Map<String, dynamic> json) {
    return MainAttendanceClass(
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

class MainAttendanceSessionData {
  const MainAttendanceSessionData({
    required this.date,
    required this.shift,
    required this.students,
  });

  final String date;
  final String shift;
  final List<MainAttendanceStudent> students;

  factory MainAttendanceSessionData.fromJson(Map<String, dynamic> json) {
    return MainAttendanceSessionData(
      date: '${json['date'] ?? ''}'.trim(),
      shift: '${json['shift'] ?? ''}'.trim(),
      students: (json['students'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MainAttendanceStudent.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'shift': shift,
      'students': students.map((student) => student.toJson()).toList(),
    };
  }
}

class MainAttendanceStudent {
  const MainAttendanceStudent({
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

  factory MainAttendanceStudent.fromJson(Map<String, dynamic> json) {
    return MainAttendanceStudent(
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

class MainAttendanceRecordDraft {
  const MainAttendanceRecordDraft({
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

class MainAttendanceDraftState {
  const MainAttendanceDraftState({
    required this.status,
    required this.remarks,
  });

  final String status;
  final String remarks;

  factory MainAttendanceDraftState.fromJson(Map<String, dynamic> json) {
    return MainAttendanceDraftState(
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

class MainAttendanceCacheSnapshot {
  const MainAttendanceCacheSnapshot({
    required this.academicYear,
    required this.levels,
    required this.classes,
    required this.selectedLevelId,
    required this.selectedClassId,
    required this.selectedShift,
    required this.selectedDate,
    required this.session,
    required this.drafts,
  });

  final ActiveAcademicYear? academicYear;
  final List<MainAttendanceLevel> levels;
  final List<MainAttendanceClass> classes;
  final int? selectedLevelId;
  final int? selectedClassId;
  final String selectedShift;
  final String selectedDate;
  final MainAttendanceSessionData? session;
  final Map<int, MainAttendanceDraftState> drafts;

  factory MainAttendanceCacheSnapshot.fromJson(Map<String, dynamic> json) {
    final draftsJson = json['drafts'] as Map<String, dynamic>? ?? const {};

    return MainAttendanceCacheSnapshot(
      academicYear: json['academic_year'] is Map<String, dynamic>
          ? ActiveAcademicYear.fromJson(
              json['academic_year'] as Map<String, dynamic>,
            )
          : null,
      levels: (json['levels'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MainAttendanceLevel.fromJson)
          .toList(),
      classes: (json['classes'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MainAttendanceClass.fromJson)
          .toList(),
      selectedLevelId: _toNullableInt(json['selected_level_id']),
      selectedClassId: _toNullableInt(json['selected_class_id']),
      selectedShift: '${json['selected_shift'] ?? 'shift_1'}'.trim(),
      selectedDate: '${json['selected_date'] ?? ''}'.trim(),
      session: json['session'] is Map<String, dynamic>
          ? MainAttendanceSessionData.fromJson(
              json['session'] as Map<String, dynamic>,
            )
          : null,
      drafts: {
        for (final entry in draftsJson.entries)
          int.tryParse(entry.key) ?? 0: MainAttendanceDraftState.fromJson(
            entry.value as Map<String, dynamic>? ?? const {},
          ),
      }..remove(0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'academic_year': academicYear?.toJson(),
      'levels': levels.map((level) => level.toJson()).toList(),
      'classes': classes.map((schoolClass) => schoolClass.toJson()).toList(),
      'selected_level_id': selectedLevelId,
      'selected_class_id': selectedClassId,
      'selected_shift': selectedShift,
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

  return int.tryParse('$value');
}

String? _toNullableString(dynamic value) {
  final normalized = '${value ?? ''}'.trim();
  if (normalized.isEmpty) {
    return null;
  }

  return normalized;
}
