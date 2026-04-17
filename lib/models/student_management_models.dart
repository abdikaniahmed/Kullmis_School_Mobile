class StudentProfile {
  const StudentProfile({
    required this.id,
    required this.name,
    required this.phone,
    required this.secondPhone,
    required this.gender,
    required this.studentType,
    required this.feeType,
    required this.address,
    required this.busAssign,
    required this.bloodType,
    required this.disabledAt,
    required this.disableReason,
    required this.currentYear,
  });

  final int id;
  final String name;
  final String? phone;
  final String? secondPhone;
  final String? gender;
  final String? studentType;
  final String? feeType;
  final String? address;
  final String? busAssign;
  final String? bloodType;
  final String? disabledAt;
  final String? disableReason;
  final StudentAcademicAssignment? currentYear;

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    return StudentProfile(
      id: _toInt(json['id']),
      name: '${json['name'] ?? ''}'.trim(),
      phone: _toNullableString(json['phone']),
      secondPhone: _toNullableString(json['second_phone']),
      gender: _toNullableString(json['gender']),
      studentType: _toNullableString(json['student_type']),
      feeType: _toNullableString(json['fee_type']),
      address: _toNullableString(json['address']),
      busAssign: _toNullableString(json['bus_assign']),
      bloodType: _toNullableString(json['blood_type']),
      disabledAt: _toNullableString(json['disabled_at']),
      disableReason: _toNullableString(json['disable_reason']),
      currentYear: StudentAcademicAssignment.fromDynamic(json['current_year']),
    );
  }
}

class StudentAcademicAssignment {
  const StudentAcademicAssignment({
    required this.id,
    required this.academicYearId,
    required this.levelId,
    required this.classId,
    required this.rollNumber,
    required this.status,
    required this.levelName,
    required this.className,
  });

  final int id;
  final int? academicYearId;
  final int? levelId;
  final int? classId;
  final String? rollNumber;
  final String? status;
  final String? levelName;
  final String? className;

  static StudentAcademicAssignment? fromDynamic(dynamic value) {
    if (value is! Map<String, dynamic>) {
      return null;
    }

    final level = value['level'];
    final schoolClass = value['school_class'];

    return StudentAcademicAssignment(
      id: _toInt(value['id']),
      academicYearId: _toNullableInt(value['academic_year_id']),
      levelId: _toNullableInt(value['level_id']),
      classId: _toNullableInt(value['school_class_id']),
      rollNumber: _toNullableString(value['roll_number']),
      status: _toNullableString(value['status']),
      levelName: level is Map<String, dynamic>
          ? _toNullableString(level['name'])
          : null,
      className: schoolClass is Map<String, dynamic>
          ? _toNullableString(schoolClass['name'])
          : null,
    );
  }
}

class StudentOptionalFee {
  const StudentOptionalFee({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  factory StudentOptionalFee.fromJson(Map<String, dynamic> json) {
    return StudentOptionalFee(
      id: _toInt(json['id']),
      name: '${json['name'] ?? ''}'.trim(),
    );
  }
}

class SchoolClassOption {
  const SchoolClassOption({
    required this.id,
    required this.name,
    required this.levelId,
    required this.section,
  });

  final int id;
  final String name;
  final int levelId;
  final String? section;

  factory SchoolClassOption.fromJson(Map<String, dynamic> json) {
    return SchoolClassOption(
      id: _toInt(json['id']),
      name: '${json['name'] ?? ''}'.trim(),
      levelId: _toInt(json['level_id']),
      section: _toNullableString(json['section']),
    );
  }
}

class StudentOptionalFeesResponse {
  const StudentOptionalFeesResponse({
    required this.fees,
    required this.assignedFeeIds,
  });

  final List<StudentOptionalFee> fees;
  final List<int> assignedFeeIds;

  factory StudentOptionalFeesResponse.fromJson(Map<String, dynamic> json) {
    final fees = (json['fees'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(StudentOptionalFee.fromJson)
        .toList();

    final ids = (json['assigned_fee_ids'] as List<dynamic>? ?? const [])
        .map((value) => _toInt(value))
        .where((value) => value > 0)
        .toList();

    return StudentOptionalFeesResponse(
      fees: fees,
      assignedFeeIds: ids,
    );
  }
}

class StudentCreateResult {
  const StudentCreateResult({
    required this.student,
    required this.generatedPassword,
  });

  final StudentProfile student;
  final String? generatedPassword;

  factory StudentCreateResult.fromJson(Map<String, dynamic> json) {
    final student = json['student'] as Map<String, dynamic>? ?? const {};

    return StudentCreateResult(
      student: StudentProfile.fromJson(student),
      generatedPassword: _toNullableString(json['generated_password']),
    );
  }
}

class DisabledStudentPage {
  const DisabledStudentPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.from,
    required this.to,
    required this.hasPreviousPage,
    required this.hasNextPage,
  });

  final List<DisabledStudentItem> items;
  final int currentPage;
  final int lastPage;
  final int total;
  final int? from;
  final int? to;
  final bool hasPreviousPage;
  final bool hasNextPage;

  factory DisabledStudentPage.fromJson(Map<String, dynamic> json) {
    final items = (json['data'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(DisabledStudentItem.fromJson)
        .toList();

    return DisabledStudentPage(
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

class DisabledStudentItem {
  const DisabledStudentItem({
    required this.id,
    required this.name,
    required this.phone,
    required this.disableReason,
    required this.disabledAt,
    required this.currentYear,
  });

  final int id;
  final String name;
  final String? phone;
  final String? disableReason;
  final String? disabledAt;
  final StudentAcademicAssignment? currentYear;

  factory DisabledStudentItem.fromJson(Map<String, dynamic> json) {
    return DisabledStudentItem(
      id: _toInt(json['id']),
      name: '${json['name'] ?? ''}'.trim(),
      phone: _toNullableString(json['phone']),
      disableReason: _toNullableString(json['disable_reason']),
      disabledAt: _toNullableString(json['disabled_at']),
      currentYear: StudentAcademicAssignment.fromDynamic(json['current_year']),
    );
  }
}

class GraduatesPage {
  const GraduatesPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.from,
    required this.to,
    required this.hasPreviousPage,
    required this.hasNextPage,
  });

  final List<GraduateItem> items;
  final int currentPage;
  final int lastPage;
  final int total;
  final int? from;
  final int? to;
  final bool hasPreviousPage;
  final bool hasNextPage;

  factory GraduatesPage.fromJson(Map<String, dynamic> json) {
    final items = (json['data'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(GraduateItem.fromJson)
        .toList();

    return GraduatesPage(
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

class GraduateItem {
  const GraduateItem({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.phone,
    required this.academicYearId,
    required this.academicYearName,
    required this.levelId,
    required this.levelName,
    required this.classId,
    required this.className,
  });

  final int id;
  final int studentId;
  final String studentName;
  final String? phone;
  final int? academicYearId;
  final String? academicYearName;
  final int? levelId;
  final String? levelName;
  final int? classId;
  final String? className;

  factory GraduateItem.fromJson(Map<String, dynamic> json) {
    final student = json['student'] as Map<String, dynamic>?;
    final level = json['level'] as Map<String, dynamic>?;
    final schoolClass = json['school_class'] as Map<String, dynamic>?;
    final academicYear = json['academic_year'] as Map<String, dynamic>?;

    return GraduateItem(
      id: _toInt(json['id']),
      studentId: _toInt(json['student_id']),
      studentName: '${student?['name'] ?? ''}'.trim(),
      phone: _toNullableString(student?['phone']),
      academicYearId: _toNullableInt(json['academic_year_id']),
      academicYearName: _toNullableString(academicYear?['name']),
      levelId: _toNullableInt(json['level_id']),
      levelName: _toNullableString(level?['name']),
      classId: _toNullableInt(json['school_class_id']),
      className: _toNullableString(schoolClass?['name']),
    );
  }
}

class StudentListReport {
  const StudentListReport({
    required this.filterLabel,
    required this.generatedAt,
    required this.count,
    required this.students,
  });

  final String? filterLabel;
  final String? generatedAt;
  final int count;
  final List<StudentReportRow> students;

  factory StudentListReport.fromJson(Map<String, dynamic> json) {
    return StudentListReport(
      filterLabel: _toNullableString(json['filter_label']),
      generatedAt: _toNullableString(json['generated_at']),
      count: _toInt(json['count']),
      students: (json['students'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(StudentReportRow.fromJson)
          .toList(),
    );
  }
}

class StudentReportRow {
  const StudentReportRow({
    required this.id,
    required this.name,
    required this.rollNumber,
    required this.gender,
    required this.levelName,
    required this.className,
    required this.section,
    required this.phone,
  });

  final int id;
  final String name;
  final String? rollNumber;
  final String? gender;
  final String? levelName;
  final String? className;
  final String? section;
  final String? phone;

  factory StudentReportRow.fromJson(Map<String, dynamic> json) {
    return StudentReportRow(
      id: _toInt(json['id']),
      name: '${json['name'] ?? ''}'.trim(),
      rollNumber: _toNullableString(json['roll_number']),
      gender: _toNullableString(json['gender']),
      levelName: _toNullableString(json['level_name']),
      className: _toNullableString(json['class_name']),
      section: _toNullableString(json['section']),
      phone: _toNullableString(json['phone']),
    );
  }
}

class WeeklyIncidentReport {
  const WeeklyIncidentReport({
    required this.generatedAt,
    required this.periodStart,
    required this.periodEnd,
    required this.filterLabel,
    required this.summary,
    required this.repeatedStudents,
    required this.incidents,
  });

  final String? generatedAt;
  final String? periodStart;
  final String? periodEnd;
  final String? filterLabel;
  final WeeklyIncidentSummary summary;
  final List<WeeklyRepeatedStudent> repeatedStudents;
  final List<WeeklyIncidentItem> incidents;

  factory WeeklyIncidentReport.fromJson(Map<String, dynamic> json) {
    return WeeklyIncidentReport(
      generatedAt: _toNullableString(json['generated_at']),
      periodStart: _toNullableString(json['period_start']),
      periodEnd: _toNullableString(json['period_end']),
      filterLabel: _toNullableString(json['filter_label']),
      summary: WeeklyIncidentSummary.fromJson(
        json['summary'] as Map<String, dynamic>? ?? const {},
      ),
      repeatedStudents:
          (json['repeated_students'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(WeeklyRepeatedStudent.fromJson)
              .toList(),
      incidents: (json['incidents'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(WeeklyIncidentItem.fromJson)
          .toList(),
    );
  }
}

class WeeklyIncidentSummary {
  const WeeklyIncidentSummary({
    required this.totalIncidents,
    required this.totalStudents,
    required this.repeatedStudentsCount,
  });

  final int totalIncidents;
  final int totalStudents;
  final int repeatedStudentsCount;

  factory WeeklyIncidentSummary.fromJson(Map<String, dynamic> json) {
    return WeeklyIncidentSummary(
      totalIncidents: _toInt(json['total_incidents']),
      totalStudents: _toInt(json['total_students']),
      repeatedStudentsCount: _toInt(json['repeated_students_count']),
    );
  }
}

class WeeklyRepeatedStudent {
  const WeeklyRepeatedStudent({
    required this.studentId,
    required this.studentName,
    required this.rollNumber,
    required this.levelName,
    required this.className,
    required this.incidentCount,
    required this.latestHappenedAt,
  });

  final int studentId;
  final String? studentName;
  final String? rollNumber;
  final String? levelName;
  final String? className;
  final int incidentCount;
  final String? latestHappenedAt;

  factory WeeklyRepeatedStudent.fromJson(Map<String, dynamic> json) {
    return WeeklyRepeatedStudent(
      studentId: _toInt(json['student_id']),
      studentName: _toNullableString(json['student_name']),
      rollNumber: _toNullableString(json['roll_number']),
      levelName: _toNullableString(json['level_name']),
      className: _toNullableString(json['class_name']),
      incidentCount: _toInt(json['incident_count']),
      latestHappenedAt: _toNullableString(json['latest_happened_at']),
    );
  }
}

class WeeklyIncidentItem {
  const WeeklyIncidentItem({
    required this.id,
    required this.studentName,
    required this.whatHappened,
    required this.actionTaken,
    required this.reportedBy,
    required this.happenedAt,
    required this.repeatCount,
    required this.isRepeatedStudent,
  });

  final int id;
  final String? studentName;
  final String? whatHappened;
  final String? actionTaken;
  final String? reportedBy;
  final String? happenedAt;
  final int repeatCount;
  final bool isRepeatedStudent;

  factory WeeklyIncidentItem.fromJson(Map<String, dynamic> json) {
    final student = json['student'] as Map<String, dynamic>?;

    return WeeklyIncidentItem(
      id: _toInt(json['id']),
      studentName: _toNullableString(student?['name']),
      whatHappened: _toNullableString(json['what_happened']),
      actionTaken: _toNullableString(json['action_taken']),
      reportedBy: _toNullableString(json['reported_by']),
      happenedAt: _toNullableString(json['happened_at']),
      repeatCount: _toInt(json['repeat_count']),
      isRepeatedStudent: json['is_repeated_student'] == true,
    );
  }
}

class StudentImportError {
  const StudentImportError({
    required this.row,
    required this.errors,
  });

  final int row;
  final List<String> errors;

  factory StudentImportError.fromJson(Map<String, dynamic> json) {
    return StudentImportError(
      row: _toInt(json['row']),
      errors: (json['errors'] as List<dynamic>? ?? const [])
          .map((value) => '$value')
          .where((value) => value.trim().isNotEmpty)
          .toList(),
    );
  }
}

class StudentImportResult {
  const StudentImportResult({
    required this.message,
    required this.created,
    required this.failed,
    required this.errors,
  });

  final String message;
  final int created;
  final int failed;
  final List<StudentImportError> errors;

  factory StudentImportResult.fromJson(Map<String, dynamic> json) {
    return StudentImportResult(
      message: '${json['message'] ?? ''}'.trim(),
      created: _toInt(json['created']),
      failed: _toInt(json['failed']),
      errors: (json['errors'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(StudentImportError.fromJson)
          .toList(),
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
