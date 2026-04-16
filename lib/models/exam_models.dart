class ExamTermOption {
  const ExamTermOption({
    required this.id,
    required this.name,
    required this.academicYearId,
    required this.isActive,
  });

  final int id;
  final String name;
  final int academicYearId;
  final bool isActive;

  factory ExamTermOption.fromJson(Map<String, dynamic> json) {
    return ExamTermOption(
      id: _toInt(json['id']),
      name: '${json['name'] ?? ''}'.trim(),
      academicYearId: _toInt(json['academic_year_id']),
      isActive: _toBool(json['is_active']),
    );
  }
}

class ExamOption {
  const ExamOption({
    required this.id,
    required this.name,
    required this.termId,
    required this.orderNumber,
    required this.maxMark,
    required this.weight,
  });

  final int id;
  final String name;
  final int termId;
  final int? orderNumber;
  final double maxMark;
  final double? weight;

  factory ExamOption.fromJson(Map<String, dynamic> json) {
    return ExamOption(
      id: _toInt(json['id']),
      name: '${json['name'] ?? ''}'.trim(),
      termId: _toInt(json['term_id']),
      orderNumber: _toNullableInt(json['order_n']),
      maxMark: _toDouble(json['max_mark']),
      weight: _toNullableDouble(json['weight']),
    );
  }
}

class ExamSubjectOption {
  const ExamSubjectOption({
    required this.id,
    required this.name,
    required this.type,
  });

  final int id;
  final String name;
  final String type;

  factory ExamSubjectOption.fromJson(Map<String, dynamic> json) {
    return ExamSubjectOption(
      id: _toInt(json['id']),
      name: '${json['name'] ?? ''}'.trim(),
      type: '${json['type'] ?? ''}'.trim(),
    );
  }
}

class ClassMarkEntry {
  const ClassMarkEntry({
    required this.studentId,
    required this.mark,
    required this.comment,
  });

  final int studentId;
  final double? mark;
  final String? comment;

  factory ClassMarkEntry.fromJson(Map<String, dynamic> json) {
    return ClassMarkEntry(
      studentId: _toInt(json['student_id']),
      mark: _toNullableDouble(json['mark']),
      comment: _toNullableString(json['comment']),
    );
  }
}

class ExamMarkDraft {
  const ExamMarkDraft({
    required this.studentId,
    required this.subjectId,
    required this.examId,
    required this.mark,
    required this.comment,
  });

  final int studentId;
  final int subjectId;
  final int examId;
  final double mark;
  final String? comment;

  Map<String, dynamic> toJson() {
    return {
      'student_id': studentId,
      'subject_id': subjectId,
      'exam_id': examId,
      'mark': mark,
      'comment': comment,
    };
  }
}

class ExamReportCard {
  const ExamReportCard({
    required this.student,
    required this.academicYear,
    required this.termName,
    required this.examName,
    required this.date,
    required this.exams,
    required this.subjects,
    required this.finalScore,
    required this.summary,
  });

  final ExamReportStudent student;
  final String academicYear;
  final String termName;
  final String examName;
  final String date;
  final List<ExamReportHeader> exams;
  final List<ExamReportSubject> subjects;
  final double finalScore;
  final ExamReportSummary summary;

  factory ExamReportCard.fromJson(Map<String, dynamic> json) {
    final subjectsValue = json['subjects'];
    final subjectRows = <Map<String, dynamic>>[];

    if (subjectsValue is List) {
      subjectRows.addAll(subjectsValue.whereType<Map<String, dynamic>>());
    } else if (subjectsValue is Map) {
      for (final value in subjectsValue.values) {
        if (value is Map<String, dynamic>) {
          subjectRows.add(value);
        }
      }
    }

    return ExamReportCard(
      student: ExamReportStudent.fromJson(
        json['student'] as Map<String, dynamic>? ?? const {},
      ),
      academicYear: '${json['academic_year'] ?? ''}'.trim(),
      termName: '${json['term_name'] ?? ''}'.trim(),
      examName: '${json['exam_name'] ?? ''}'.trim(),
      date: '${json['date'] ?? ''}'.trim(),
      exams: (json['exams'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ExamReportHeader.fromJson)
          .toList(),
      subjects: subjectRows.map(ExamReportSubject.fromJson).toList(),
      finalScore: _toDouble(json['final_score']),
      summary: ExamReportSummary.fromJson(
        json['summary'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

class ExamReportStudent {
  const ExamReportStudent({
    required this.name,
    required this.rollNumber,
    required this.className,
    required this.levelName,
  });

  final String name;
  final String rollNumber;
  final String className;
  final String levelName;

  factory ExamReportStudent.fromJson(Map<String, dynamic> json) {
    return ExamReportStudent(
      name: '${json['name'] ?? ''}'.trim(),
      rollNumber: '${json['roll_number'] ?? '—'}'.trim(),
      className: '${json['class_name'] ?? '—'}'.trim(),
      levelName: '${json['level_name'] ?? '—'}'.trim(),
    );
  }
}

class ExamReportHeader {
  const ExamReportHeader({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  factory ExamReportHeader.fromJson(Map<String, dynamic> json) {
    return ExamReportHeader(
      id: _toInt(json['id']),
      name: '${json['name'] ?? ''}'.trim(),
    );
  }
}

class ExamReportSubject {
  const ExamReportSubject({
    required this.subject,
    required this.examsMap,
    required this.total,
  });

  final String subject;
  final Map<int, double> examsMap;
  final double total;

  factory ExamReportSubject.fromJson(Map<String, dynamic> json) {
    final examsMap = <int, double>{};
    final rawMap = json['exams_map'];

    if (rawMap is Map) {
      for (final entry in rawMap.entries) {
        final key = int.tryParse('${entry.key}');
        if (key != null) {
          examsMap[key] = _toDouble(entry.value);
        }
      }
    }

    return ExamReportSubject(
      subject: '${json['subject'] ?? ''}'.trim(),
      examsMap: examsMap,
      total: _toDouble(json['total']),
    );
  }
}

class ExamReportSummary {
  const ExamReportSummary({
    required this.total,
    required this.average,
    required this.percentage,
    required this.grade,
  });

  final double total;
  final double average;
  final double percentage;
  final String grade;

  factory ExamReportSummary.fromJson(Map<String, dynamic> json) {
    return ExamReportSummary(
      total: _toDouble(json['total']),
      average: _toDouble(json['average']),
      percentage: _toDouble(json['percentage']),
      grade: '${json['grade'] ?? ''}'.trim(),
    );
  }
}

bool _toBool(dynamic value) {
  if (value is bool) {
    return value;
  }

  if (value is num) {
    return value != 0;
  }

  final normalized = '${value ?? ''}'.trim().toLowerCase();
  return normalized == '1' || normalized == 'true';
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

double? _toNullableDouble(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse('$value');
}

String? _toNullableString(dynamic value) {
  final normalized = '${value ?? ''}'.trim();
  if (normalized.isEmpty) {
    return null;
  }

  return normalized;
}
