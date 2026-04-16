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

int _toInt(dynamic value) {
  if (value is int) {
    return value;
  }

  if (value is double) {
    return value.round();
  }

  return int.tryParse('$value') ?? 0;
}

String? _toNullableString(dynamic value) {
  final normalized = '${value ?? ''}'.trim();
  if (normalized.isEmpty) {
    return null;
  }

  return normalized;
}
