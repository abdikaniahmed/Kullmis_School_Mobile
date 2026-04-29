import 'subject_attendance_models.dart';

class ClassReportResponse {
  const ClassReportResponse({
    required this.academicYear,
    required this.className,
    required this.term,
    required this.subjects,
    required this.students,
    required this.count,
  });

  final String academicYear;
  final String className;
  final String term;
  final List<ClassReportSubject> subjects;
  final List<ClassReportStudent> students;
  final int count;

  factory ClassReportResponse.fromJson(Map<String, dynamic> json) {
    return ClassReportResponse(
      academicYear: '${json['academic_year'] ?? ''}'.trim(),
      className: '${json['class_name'] ?? ''}'.trim(),
      term: '${json['term'] ?? ''}'.trim(),
      subjects: (json['subjects'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ClassReportSubject.fromJson)
          .toList(),
      students: (json['students'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ClassReportStudent.fromJson)
          .toList(),
      count: _toInt(json['count']),
    );
  }
}

class ClassReportSubject {
  const ClassReportSubject({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  factory ClassReportSubject.fromJson(Map<String, dynamic> json) {
    return ClassReportSubject(
      id: _toInt(json['id']),
      name: '${json['name'] ?? ''}'.trim(),
    );
  }
}

class ClassReportStudent {
  const ClassReportStudent({
    required this.studentId,
    required this.studentName,
    required this.rollNumber,
    required this.subjects,
    required this.total,
    required this.rank,
  });

  final int studentId;
  final String studentName;
  final String? rollNumber;
  final Map<int, double> subjects;
  final double total;
  final int rank;

  factory ClassReportStudent.fromJson(Map<String, dynamic> json) {
    final subjectMap = <int, double>{};
    final rawSubjects = json['subjects'];

    if (rawSubjects is Map) {
      for (final entry in rawSubjects.entries) {
        final key = int.tryParse('${entry.key}');
        if (key != null) {
          subjectMap[key] = _toDouble(entry.value);
        }
      }
    }

    return ClassReportStudent(
      studentId: _toInt(json['student_id']),
      studentName: '${json['student_name'] ?? ''}'.trim(),
      rollNumber: _toNullableString(json['roll_number']),
      subjects: subjectMap,
      total: _toDouble(json['total']),
      rank: _toInt(json['rank']),
    );
  }
}

class SubjectAttendanceReportResponse {
  const SubjectAttendanceReportResponse({
    required this.academicYearId,
    required this.items,
  });

  final int academicYearId;
  final List<SubjectAttendanceReportItem> items;

  factory SubjectAttendanceReportResponse.fromJson(Map<String, dynamic> json) {
    return SubjectAttendanceReportResponse(
      academicYearId: _toInt(json['academic_year_id']),
      items: (json['report'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SubjectAttendanceReportItem.fromJson)
          .toList(),
    );
  }
}

class SubjectAttendanceReportItem {
  const SubjectAttendanceReportItem({
    required this.id,
    required this.date,
    required this.periodNumber,
    required this.className,
    required this.levelName,
    required this.subjectName,
    required this.teacherName,
    required this.present,
    required this.absent,
    required this.late,
    required this.excused,
    required this.total,
  });

  final int id;
  final String date;
  final int periodNumber;
  final String? className;
  final String? levelName;
  final String? subjectName;
  final String? teacherName;
  final int present;
  final int absent;
  final int late;
  final int excused;
  final int total;

  factory SubjectAttendanceReportItem.fromJson(Map<String, dynamic> json) {
    return SubjectAttendanceReportItem(
      id: _toInt(json['id']),
      date: '${json['date'] ?? ''}'.trim(),
      periodNumber: _toInt(json['period_number']),
      className: _toNullableString(json['class_name']),
      levelName: _toNullableString(json['level_name']),
      subjectName: _toNullableString(json['subject_name']),
      teacherName: _toNullableString(json['teacher_name']),
      present: _toInt(json['present']),
      absent: _toInt(json['absent']),
      late: _toInt(json['late']),
      excused: _toInt(json['excused']),
      total: _toInt(json['total']),
    );
  }
}

class AttendanceReportResponse {
  const AttendanceReportResponse({
    required this.reportType,
    required this.viewMode,
    required this.periodLabel,
    required this.shift,
    required this.schoolClassId,
    required this.items,
  });

  final String reportType;
  final String viewMode;
  final String periodLabel;
  final String? shift;
  final int? schoolClassId;
  final List<AttendanceReportRow> items;

  bool get isDailyView => viewMode == 'daily';

  factory AttendanceReportResponse.fromJson(Map<String, dynamic> json) {
    return AttendanceReportResponse(
      reportType: '${json['report_type'] ?? 'monthly'}'.trim(),
      viewMode: '${json['view_mode'] ?? 'summary'}'.trim(),
      periodLabel: '${json['period_label'] ?? ''}'.trim(),
      shift: _toNullableString(json['shift']),
      schoolClassId: _toNullableInt(json['class']),
      items: (json['report'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AttendanceReportRow.fromJson)
          .toList(),
    );
  }
}

class AttendanceReportRow {
  const AttendanceReportRow({
    required this.studentName,
    required this.className,
    required this.rollNumber,
    required this.date,
    required this.status,
    required this.remarks,
    required this.present,
    required this.absent,
    required this.late,
    required this.excused,
    required this.totalDays,
  });

  final String studentName;
  final String? className;
  final String? rollNumber;
  final String? date;
  final String? status;
  final String? remarks;
  final int present;
  final int absent;
  final int late;
  final int excused;
  final int totalDays;

  factory AttendanceReportRow.fromJson(Map<String, dynamic> json) {
    return AttendanceReportRow(
      studentName: '${json['student_name'] ?? ''}'.trim(),
      className: _toNullableString(json['class_name']),
      rollNumber: _toNullableString(json['roll_number']),
      date: _toNullableString(json['date']),
      status: _toNullableString(json['status']),
      remarks: _toNullableString(json['remarks']),
      present: _toInt(json['present']),
      absent: _toInt(json['absent']),
      late: _toInt(json['late']),
      excused: _toInt(json['excused']),
      totalDays: _toInt(json['total_days']),
    );
  }
}

class SubjectTimetableResponse {
  const SubjectTimetableResponse({
    required this.academicYearId,
    required this.dayOfWeek,
    required this.entries,
    required this.periodsPerDay,
    required this.periods,
  });

  final int academicYearId;
  final int dayOfWeek;
  final List<SubjectTimetableEntry> entries;
  final int periodsPerDay;
  final List<SubjectTimetablePeriod> periods;

  factory SubjectTimetableResponse.fromJson(Map<String, dynamic> json) {
    return SubjectTimetableResponse(
      academicYearId: _toInt(json['academic_year_id']),
      dayOfWeek: _toInt(json['day_of_week']),
      entries: (json['entries'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SubjectTimetableEntry.fromJson)
          .toList(),
      periodsPerDay: _toInt(json['periods_per_day']),
      periods: (json['periods'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SubjectTimetablePeriod.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'academic_year_id': academicYearId,
      'day_of_week': dayOfWeek,
      'entries': entries.map((item) => item.toJson()).toList(),
      'periods_per_day': periodsPerDay,
      'periods': periods.map((item) => item.toJson()).toList(),
    };
  }
}

class SubjectTimetableEntry {
  const SubjectTimetableEntry({
    required this.id,
    required this.periodNumber,
    required this.teacherSubjectAssignmentId,
    required this.subjectName,
    required this.teacherName,
    required this.assignmentLabel,
  });

  final int id;
  final int periodNumber;
  final int? teacherSubjectAssignmentId;
  final String? subjectName;
  final String? teacherName;
  final String assignmentLabel;

  factory SubjectTimetableEntry.fromJson(Map<String, dynamic> json) {
    return SubjectTimetableEntry(
      id: _toInt(json['id']),
      periodNumber: _toInt(json['period_number']),
      teacherSubjectAssignmentId:
          _toNullableInt(json['teacher_subject_assignment_id']),
      subjectName: _toNullableString(json['subject_name']),
      teacherName: _toNullableString(json['teacher_name']),
      assignmentLabel: '${json['assignment_label'] ?? ''}'.trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'period_number': periodNumber,
      'teacher_subject_assignment_id': teacherSubjectAssignmentId,
      'subject_name': subjectName,
      'teacher_name': teacherName,
      'assignment_label': assignmentLabel,
    };
  }
}

class SubjectTimetablePeriod {
  const SubjectTimetablePeriod({
    required this.value,
    required this.label,
  });

  final int value;
  final String label;

  factory SubjectTimetablePeriod.fromJson(Map<String, dynamic> json) {
    return SubjectTimetablePeriod(
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

class SubjectTimetableAssignmentResponse {
  const SubjectTimetableAssignmentResponse({
    required this.academicYearId,
    required this.assignments,
  });

  final int academicYearId;
  final List<SubjectTimetableAssignment> assignments;

  factory SubjectTimetableAssignmentResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    return SubjectTimetableAssignmentResponse(
      academicYearId: _toInt(json['academic_year_id']),
      assignments: (json['assignments'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SubjectTimetableAssignment.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'academic_year_id': academicYearId,
      'assignments': assignments.map((item) => item.toJson()).toList(),
    };
  }
}

class SubjectTimetableAssignment {
  const SubjectTimetableAssignment({
    required this.id,
    required this.subjectId,
    required this.teacherId,
    required this.label,
    required this.subjectName,
    required this.teacherName,
  });

  final int id;
  final int? subjectId;
  final int? teacherId;
  final String label;
  final String? subjectName;
  final String? teacherName;

  factory SubjectTimetableAssignment.fromJson(Map<String, dynamic> json) {
    return SubjectTimetableAssignment(
      id: _toInt(json['id']),
      subjectId: _toNullableInt(json['subject_id']),
      teacherId: _toNullableInt(json['teacher_id']),
      label: '${json['label'] ?? ''}'.trim(),
      subjectName: _toNullableString(json['subject_name']),
      teacherName: _toNullableString(json['teacher_name']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject_id': subjectId,
      'teacher_id': teacherId,
      'label': label,
      'subject_name': subjectName,
      'teacher_name': teacherName,
    };
  }
}

class SubjectTimetableSaveDraft {
  const SubjectTimetableSaveDraft({
    required this.periodNumber,
    required this.teacherSubjectAssignmentId,
  });

  final int periodNumber;
  final int? teacherSubjectAssignmentId;

  Map<String, dynamic> toJson() {
    return {
      'period_number': periodNumber,
      'teacher_subject_assignment_id': teacherSubjectAssignmentId,
    };
  }
}

class SubjectTimetableOfflineSnapshot {
  const SubjectTimetableOfflineSnapshot({
    required this.filters,
    required this.timetable,
    required this.assignments,
    required this.selectedClassId,
    required this.selectedDay,
    required this.selectedAssignments,
  });

  final SubjectAttendanceFilters? filters;
  final SubjectTimetableResponse? timetable;
  final SubjectTimetableAssignmentResponse? assignments;
  final int? selectedClassId;
  final int selectedDay;
  final Map<int, int?> selectedAssignments;

  factory SubjectTimetableOfflineSnapshot.fromJson(
    Map<String, dynamic> json,
  ) {
    final assignmentsJson =
        json['selected_assignments'] as Map<String, dynamic>? ?? const {};

    return SubjectTimetableOfflineSnapshot(
      filters: json['filters'] is Map<String, dynamic>
          ? SubjectAttendanceFilters.fromJson(
              json['filters'] as Map<String, dynamic>,
            )
          : null,
      timetable: json['timetable'] is Map<String, dynamic>
          ? SubjectTimetableResponse.fromJson(
              json['timetable'] as Map<String, dynamic>,
            )
          : null,
      assignments: json['assignments'] is Map<String, dynamic>
          ? SubjectTimetableAssignmentResponse.fromJson(
              json['assignments'] as Map<String, dynamic>,
            )
          : null,
      selectedClassId: _toNullableInt(json['selected_class_id']),
      selectedDay: _toInt(json['selected_day']),
      selectedAssignments: {
        for (final entry in assignmentsJson.entries)
          _toInt(entry.key): _toNullableInt(entry.value),
      },
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'filters': filters?.toJson(),
      'timetable': timetable?.toJson(),
      'assignments': assignments?.toJson(),
      'selected_class_id': selectedClassId,
      'selected_day': selectedDay,
      'selected_assignments': {
        for (final entry in selectedAssignments.entries)
          '${entry.key}': entry.value,
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

double _toDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse('$value') ?? 0;
}

String? _toNullableString(dynamic value) {
  final normalized = '${value ?? ''}'.trim();
  if (normalized.isEmpty) {
    return null;
  }

  return normalized;
}
