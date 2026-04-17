import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/auth_session.dart';
import '../models/discipline_incident_models.dart';
import '../models/dashboard_data.dart';
import '../models/exam_models.dart';
import '../models/fee_models.dart';
import '../models/main_attendance_models.dart';
import '../models/student_management_models.dart';
import '../models/student_list_models.dart';
import '../models/subject_attendance_models.dart';

class LaravelApi {
  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl;
    }

    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api';
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'http://10.0.2.2:8000/api',
      _ => 'http://127.0.0.1:8000/api',
    };
  }

  LaravelApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/login'),
      headers: _headers(jsonRequest: true),
      body: jsonEncode({
        'email': email,
        'password': password,
        'device_name': 'flutter-mobile',
      }),
    );

    final payload = _decode(response);
    _throwIfNeeded(response, payload);

    final token = '${payload['token'] ?? ''}'.trim();

    if (token.isEmpty) {
      throw const ApiException(
        'Login succeeded but no API token was returned.',
      );
    }

    return currentUser(token);
  }

  Future<AuthSession> currentUser(String token) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/user'),
      headers: _headers(token: token),
    );

    final payload = _decode(response);
    _throwIfNeeded(response, payload);

    return AuthSession.fromUserResponse(token: token, payload: payload);
  }

  Future<DashboardData> dashboard(String token) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/school/dashboard'),
      headers: _headers(token: token),
    );

    final payload = _decode(response);
    _throwIfNeeded(response, payload);

    return DashboardData.fromResponse(payload);
  }

  Future<ActiveAcademicYear> activeAcademicYear(String token) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/school/academic-years/active'),
      headers: _headers(token: token),
    );

    final payload = _decode(response);
    _throwIfNeeded(response, payload);

    return ActiveAcademicYear.fromJson(payload);
  }

  Future<List<AcademicYearOption>> academicYears(String token) async {
    final uri = Uri.parse('$baseUrl/school/academic-years').replace(
      queryParameters: {
        'per_page': '100',
      },
    );

    final response = await _client.get(
      uri,
      headers: _headers(token: token),
    );

    final payload = _decode(response);
    _throwIfNeeded(response, payload);

    final data = payload['data'] as List<dynamic>? ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(AcademicYearOption.fromJson)
        .toList();
  }

  Future<List<MainAttendanceLevel>> attendanceLevels(String token) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/school/levels'),
      headers: _headers(token: token),
    );

    final payload = _decode(response);
    _throwIfNeeded(response, payload);

    final data = payload['data'] as List<dynamic>? ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(MainAttendanceLevel.fromJson)
        .toList();
  }

  Future<List<MainAttendanceClass>> attendanceClasses({
    required String token,
    required int levelId,
  }) async {
    final uri = Uri.parse('$baseUrl/school/classes').replace(
      queryParameters: {
        'level_id': '$levelId',
      },
    );

    final response = await _client.get(
      uri,
      headers: _headers(token: token),
    );

    final payload = _decode(response);
    _throwIfNeeded(response, payload);

    final data = payload['data'] as List<dynamic>? ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(MainAttendanceClass.fromJson)
        .toList();
  }

  Future<List<MainAttendanceClass>> schoolClasses({
    required String token,
    int? levelId,
    bool includeAll = false,
  }) async {
    final queryParameters = <String, String>{};

    if (levelId != null) {
      queryParameters['level_id'] = '$levelId';
    } else if (includeAll) {
      queryParameters['all'] = '1';
    }

    final uri = Uri.parse('$baseUrl/school/classes').replace(
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );

    final response = await _client.get(
      uri,
      headers: _headers(token: token),
    );

    final payload = _decode(response);
    _throwIfNeeded(response, payload);

    final data = payload['data'] as List<dynamic>? ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(MainAttendanceClass.fromJson)
        .toList();
  }

  Future<List<SchoolClassOption>> schoolClassesWithSection({
    required String token,
    int? levelId,
    bool includeAll = false,
  }) async {
    final queryParameters = <String, String>{};

    if (levelId != null) {
      queryParameters['level_id'] = '$levelId';
    } else if (includeAll) {
      queryParameters['all'] = '1';
    }

    final uri = Uri.parse('$baseUrl/school/classes').replace(
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );

    final response = await _client.get(
      uri,
      headers: _headers(token: token),
    );

    final payload = _decode(response);
    _throwIfNeeded(response, payload);

    final data = payload['data'] as List<dynamic>? ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(SchoolClassOption.fromJson)
        .toList();
  }

  Future<List<FeeStructureItem>> feeStructures({
    required String token,
    required int academicYearId,
  }) async {
    final uri = Uri.parse('$baseUrl/school/fees/structures').replace(
      queryParameters: {
        'academic_year_id': '$academicYearId',
      },
    );

    final response = await _client.get(
      uri,
      headers: _headers(token: token),
    );

    final payload = _decode(response);
    _throwIfNeeded(response, payload);

    final data = payload['data'] as List<dynamic>? ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(FeeStructureItem.fromJson)
        .toList();
  }

  Future<void> generateFeeInvoices({
    required String token,
    required int academicYearId,
    int? schoolClassId,
    String? issueDate,
    String? dueDate,
    String? remarks,
  }) async {
    final body = <String, dynamic>{
      'academic_year_id': academicYearId,
    };

    if (schoolClassId != null) {
      body['school_class_id'] = schoolClassId;
    }

    if (issueDate != null && issueDate.isNotEmpty) {
      body['issue_date'] = issueDate;
    }

    if (dueDate != null && dueDate.isNotEmpty) {
      body['due_date'] = dueDate;
    }

    if (remarks != null && remarks.isNotEmpty) {
      body['remarks'] = remarks;
    }

    final response = await _client.post(
      Uri.parse('$baseUrl/school/fees/invoices/generate'),
      headers: _headers(token: token, jsonRequest: true),
      body: jsonEncode(body),
    );

    final payload = _decode(response);
    _throwIfNeeded(response, payload);
  }

  Future<FeeInvoicePage> feeInvoices({
    required String token,
    required int page,
    String? status,
    String? search,
    int? academicYearId,
    int? levelId,
    int? schoolClassId,
    bool hasBalance = false,
  }) async {
    final queryParameters = <String, String>{
      'page': '$page',
    };

    if (status != null && status.isNotEmpty) {
      queryParameters['status'] = status;
    }

    if (search != null && search.isNotEmpty) {
      queryParameters['search'] = search;
    }

    if (academicYearId != null) {
      queryParameters['academic_year_id'] = '$academicYearId';
    }

    if (levelId != null) {
      queryParameters['level_id'] = '$levelId';
    }

    if (schoolClassId != null) {
      queryParameters['school_class_id'] = '$schoolClassId';
    }

    if (hasBalance) {
      queryParameters['has_balance'] = '1';
    }

    final uri = Uri.parse('$baseUrl/school/fees/invoices').replace(
      queryParameters: queryParameters,
    );

    final response = await _client.get(
      uri,
      headers: _headers(token: token),
    );

    final payload = _decode(response);
    _throwIfNeeded(response, payload);

    return FeeInvoicePage.fromJson(payload);
  }

  Future<FeeInvoiceDetail> feeInvoiceDetail({
    required String token,
    required int invoiceId,
  }) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/school/fees/invoices/$invoiceId'),
      headers: _headers(token: token),
    );

    final payload = _decode(response);
    _throwIfNeeded(response, payload);

    return FeeInvoiceDetail.fromJson(payload);
  }

  Future<List<FeePaymentMethod>> feePaymentMethods({
    required String token,
  }) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/school/fees/payment-methods'),
      headers: _headers(token: token),
    );

    final payload = _decode(response);
    _throwIfNeeded(response, payload);

    final data = payload['data'] as List<dynamic>? ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(FeePaymentMethod.fromJson)
        .toList();
  }

  Future<FeePaymentResult> createFeePayment({
    required String token,
    required int feeInvoiceId,
    required double amount,
    required String paymentMethod,
    required String paymentDate,
    String? referenceNumber,
  }) async {
    final body = <String, dynamic>{
      'fee_invoice_id': feeInvoiceId,
      'amount': amount,
      'payment_method': paymentMethod,
      'payment_date': paymentDate,
    };

    if (referenceNumber != null && referenceNumber.isNotEmpty) {
      body['reference_no'] = referenceNumber;
    }

    final response = await _client.post(
      Uri.parse('$baseUrl/school/fees/payments'),
      headers: _headers(token: token, jsonRequest: true),
      body: jsonEncode(body),
    );

    final payload = _decode(response);
    _throwIfNeeded(response, payload);

    return FeePaymentResult.fromJson(payload);
  }

  Future<MainAttendanceSessionData> mainAttendanceSession({
    required String token,
    required int academicYearId,
    required int schoolClassId,
    required String date,
    required String shift,
  }) async {
    final uri = Uri.parse('$baseUrl/school/attendance').replace(
      queryParameters: {
        'academic_year_id': '$academicYearId',
        'school_class_id': '$schoolClassId',
        'date': date,
        'shift': shift,
      },
    );

    final response = await _client.get(
      uri,
      headers: _headers(token: token),
    );

    final payload = _decode(response);
    _throwIfNeeded(response, payload);

    return MainAttendanceSessionData.fromJson(payload);
  }

  Future<void> saveMainAttendance({
    required String token,
    required int academicYearId,
    required int schoolClassId,
    required String date,
    required String shift,
    required List<MainAttendanceRecordDraft> records,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/school/attendance'),
      headers: _headers(token: token, jsonRequest: true),
      body: jsonEncode({
        'academic_year_id': academicYearId,
        'school_class_id': schoolClassId,
        'date': date,
        'shift': shift,
        'records': records.map((entry) => entry.toJson()).toList(),
      }),
    );

    final payload = _decode(response);
    _throwIfNeeded(response, payload);
  }

  Future<StudentListPage> studentList({
    required String token,
    required int page,
    String? search,
    int? levelId,
    int? classId,
  }) async {
    final queryParameters = <String, String>{
      'page': '$page',
    };

    if (search != null && search.isNotEmpty) {
      queryParameters['search'] = search;
    }

    if (levelId != null) {
      queryParameters['level_id'] = '$levelId';
    }

    if (classId != null) {
      queryParameters['class_id'] = '$classId';
    }

    final uri = Uri.parse('$baseUrl/school/students').replace(
      queryParameters: queryParameters,
    );

    final response = await _client.get(
      uri,
      headers: _headers(token: token),
    );

    final payload = _decode(response);
    _throwIfNeeded(response, payload);

    return StudentListPage.fromJson(payload);
  }

  Future<StudentProfile> studentDetail({
    required String token,
    required int studentId,
  }) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/school/students/$studentId'),
      headers: _headers(token: token),
    );

    final payload = _decode(response);
    _throwIfNeeded(response, payload);

    return StudentProfile.fromJson(payload);
  }

  Future<StudentCreateResult> createStudent({
    required String token,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/school/students'),
      headers: _headers(token: token, jsonRequest: true),
      body: jsonEncode(payload),
    );

    final body = _decode(response);
    _throwIfNeeded(response, body);

    return StudentCreateResult.fromJson(body);
  }

  Future<void> updateStudent({
    required String token,
    required int studentId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client.put(
      Uri.parse('$baseUrl/school/students/$studentId'),
      headers: _headers(token: token, jsonRequest: true),
      body: jsonEncode(payload),
    );

    final body = _decode(response);
    _throwIfNeeded(response, body);
  }

  Future<void> deleteStudent({
    required String token,
    required int studentId,
  }) async {
    final response = await _client.delete(
      Uri.parse('$baseUrl/school/students/$studentId'),
      headers: _headers(token: token),
    );

    final payload = _decode(response);
    _throwIfNeeded(response, payload);
  }

  Future<void> disableStudent({
    required String token,
    required int studentId,
    required String reason,
  }) async {
    final response = await _client.patch(
      Uri.parse('$baseUrl/school/students/$studentId/disable'),
      headers: _headers(token: token, jsonRequest: true),
      body: jsonEncode({'reason': reason}),
    );

    final payload = _decode(response);
    _throwIfNeeded(response, payload);
  }

  Future<void> activateStudent({
    required String token,
    required int studentId,
    required String reason,
  }) async {
    final response = await _client.patch(
      Uri.parse('$baseUrl/school/students/$studentId/activate'),
      headers: _headers(token: token, jsonRequest: true),
      body: jsonEncode({'reason': reason}),
    );

    final payload = _decode(response);
    _throwIfNeeded(response, payload);
  }

  Future<DisabledStudentPage> disabledStudents({
    required String token,
    required int page,
    String? search,
    int? levelId,
    int? classId,
  }) async {
    final queryParameters = <String, String>{
      'page': '$page',
    };

    if (search != null && search.isNotEmpty) {
      queryParameters['search'] = search;
    }

    if (levelId != null) {
      queryParameters['level_id'] = '$levelId';
    }

    if (classId != null) {
      queryParameters['class_id'] = '$classId';
    }

    final uri = Uri.parse('$baseUrl/school/students/disabled').replace(
      queryParameters: queryParameters,
    );

    final response = await _client.get(
      uri,
      headers: _headers(token: token),
    );

    final payload = _decode(response);
    _throwIfNeeded(response, payload);

    return DisabledStudentPage.fromJson(payload);
  }

  Future<GraduatesPage> graduateStudents({
    required String token,
    required int page,
    String? search,
    int? academicYearId,
  }) async {
    final queryParameters = <String, String>{
      'page': '$page',
    };

    if (search != null && search.isNotEmpty) {
      queryParameters['search'] = search;
    }

    if (academicYearId != null) {
      queryParameters['academic_year_id'] = '$academicYearId';
    }

    final uri = Uri.parse('$baseUrl/school/students/graduates').replace(
      queryParameters: queryParameters,
    );

    final response = await _client.get(
      uri,
      headers: _headers(token: token),
    );

    final payload = _decode(response);
    _throwIfNeeded(response, payload);

    return GraduatesPage.fromJson(payload);
  }

  Future<StudentListReport> studentListReport({
    required String token,
    required Map<String, String> queryParameters,
  }) async {
    final uri = Uri.parse('$baseUrl/school/students/report/list').replace(
      queryParameters: queryParameters,
    );

    final response = await _client.get(
      uri,
      headers: _headers(token: token),
    );

    final payload = _decode(response);
    _throwIfNeeded(response, payload);

    return StudentListReport.fromJson(payload);
  }

  Future<WeeklyIncidentReport> weeklyIncidentReport({
    required String token,
    int? levelId,
    int? classId,
  }) async {
    final queryParameters = <String, String>{};

    if (levelId != null) {
      queryParameters['level_id'] = '$levelId';
    }

    if (classId != null) {
      queryParameters['class_id'] = '$classId';
    }

    final uri =
        Uri.parse('$baseUrl/school/students/discipline-incidents/weekly-report')
            .replace(
                queryParameters:
                    queryParameters.isEmpty ? null : queryParameters);

    final response = await _client.get(
      uri,
      headers: _headers(token: token),
    );

    final payload = _decode(response);
    _throwIfNeeded(response, payload);

    return WeeklyIncidentReport.fromJson(payload);
  }

  Future<StudentAcademicAssignment> createStudentAssignment({
    required String token,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/school/student-academic-years'),
      headers: _headers(token: token, jsonRequest: true),
      body: jsonEncode(payload),
    );

    final body = _decode(response);
    _throwIfNeeded(response, body);

    return StudentAcademicAssignment.fromDynamic(body) ??
        StudentAcademicAssignment(
          id: _toInt(body['id']),
          academicYearId: _toNullableInt(body['academic_year_id']),
          levelId: _toNullableInt(body['level_id']),
          classId: _toNullableInt(body['school_class_id']),
          rollNumber: _toNullableString(body['roll_number']),
          status: _toNullableString(body['status']),
          levelName: null,
          className: null,
        );
  }

  Future<void> updateStudentAssignment({
    required String token,
    required int assignmentId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client.put(
      Uri.parse('$baseUrl/school/student-academic-years/$assignmentId'),
      headers: _headers(token: token, jsonRequest: true),
      body: jsonEncode(payload),
    );

    final body = _decode(response);
    _throwIfNeeded(response, body);
  }

  Future<StudentOptionalFeesResponse> studentOptionalFees({
    required String token,
    required int assignmentId,
  }) async {
    final response = await _client.get(
      Uri.parse(
          '$baseUrl/school/student-academic-years/$assignmentId/optional-fees'),
      headers: _headers(token: token),
    );

    final payload = _decode(response);
    _throwIfNeeded(response, payload);

    return StudentOptionalFeesResponse.fromJson(payload);
  }

  Future<void> syncStudentOptionalFees({
    required String token,
    required int assignmentId,
    required List<int> feeIds,
  }) async {
    final response = await _client.put(
      Uri.parse(
          '$baseUrl/school/student-academic-years/$assignmentId/optional-fees'),
      headers: _headers(token: token, jsonRequest: true),
      body: jsonEncode({'fee_structure_ids': feeIds}),
    );

    final payload = _decode(response);
    _throwIfNeeded(response, payload);
  }

  Future<StudentImportResult> uploadStudents({
    required String token,
    required String filePath,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/school/students/import'),
    );
    request.headers.addAll(_headers(token: token));
    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    final payload = _decode(response);
    _throwIfNeeded(response, payload);

    return StudentImportResult.fromJson(payload);
  }

  Future<List<ExamTermOption>> terms({
    required String token,
    required int academicYearId,
  }) async {
    final uri = Uri.parse('$baseUrl/school/terms').replace(
      queryParameters: {
        'academic_year_id': '$academicYearId',
      },
    );

    final response = await _client.get(
      uri,
      headers: _headers(token: token),
    );

    final payload = _decode(response);
    _throwIfNeeded(response, payload);

    final data = payload['data'] as List<dynamic>? ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(ExamTermOption.fromJson)
        .toList();
  }

  Future<List<ExamOption>> exams({
    required String token,
    int? academicYearId,
    int? termId,
  }) async {
    final queryParameters = <String, String>{};

    if (academicYearId != null) {
      queryParameters['academic_year_id'] = '$academicYearId';
    }

    if (termId != null) {
      queryParameters['term_id'] = '$termId';
    }

    final uri = Uri.parse('$baseUrl/school/exams').replace(
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );

    final response = await _client.get(
      uri,
      headers: _headers(token: token),
    );

    final payload = _decode(response);
    _throwIfNeeded(response, payload);

    final data = payload['data'] as List<dynamic>? ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(ExamOption.fromJson)
        .toList();
  }

  Future<List<ExamSubjectOption>> subjects({
    required String token,
  }) async {
    final results = <ExamSubjectOption>[];
    var page = 1;
    var hasNext = true;

    while (hasNext) {
      final uri = Uri.parse('$baseUrl/school/subjects').replace(
        queryParameters: {
          'page': '$page',
        },
      );

      final response = await _client.get(
        uri,
        headers: _headers(token: token),
      );

      final payload = _decode(response);
      _throwIfNeeded(response, payload);

      final data = payload['data'] as List<dynamic>? ?? const [];
      results.addAll(
        data.whereType<Map<String, dynamic>>().map(ExamSubjectOption.fromJson),
      );

      hasNext = payload['next_page_url'] != null;
      page += 1;
    }

    return results;
  }

  Future<List<ClassMarkEntry>> classMarks({
    required String token,
    required int classId,
    required int examId,
    required int subjectId,
  }) async {
    final uri = Uri.parse('$baseUrl/school/marks/class').replace(
      queryParameters: {
        'class_id': '$classId',
        'exam_id': '$examId',
        'subject_id': '$subjectId',
      },
    );

    final response = await _client.get(
      uri,
      headers: _headers(token: token),
    );

    final payload = _decodeList(response);
    return payload
        .whereType<Map<String, dynamic>>()
        .map(ClassMarkEntry.fromJson)
        .toList();
  }

  Future<void> saveBulkMarks({
    required String token,
    required int classId,
    required List<ExamMarkDraft> marks,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/school/marks/bulk'),
      headers: _headers(token: token, jsonRequest: true),
      body: jsonEncode({
        'class_id': classId,
        'marks': marks.map((entry) => entry.toJson()).toList(),
      }),
    );

    final payload = _decode(response);
    _throwIfNeeded(response, payload);
  }

  Future<ExamReportCard> studentReportCard({
    required String token,
    required int studentId,
    required int academicYearId,
    int? termId,
    int? examId,
  }) async {
    final queryParameters = <String, String>{
      'academic_year_id': '$academicYearId',
    };

    if (termId != null) {
      queryParameters['term_id'] = '$termId';
    }

    if (examId != null) {
      queryParameters['exam_id'] = '$examId';
    }

    final uri = Uri.parse('$baseUrl/school/report-cards/student/$studentId')
        .replace(queryParameters: queryParameters);

    final response = await _client.get(
      uri,
      headers: _headers(token: token),
    );

    final payload = _decode(response);
    _throwIfNeeded(response, payload);

    return ExamReportCard.fromJson(payload);
  }

  Future<void> createStudentDisciplineIncident({
    required String token,
    required int studentId,
    required String whatHappened,
    required String happenedAt,
    String? actionTaken,
    String? reportedByName,
  }) async {
    final body = <String, dynamic>{
      'student_id': studentId,
      'what_happened': whatHappened,
      'happened_at': happenedAt,
    };

    if (actionTaken != null && actionTaken.isNotEmpty) {
      body['action_taken'] = actionTaken;
    }

    if (reportedByName != null && reportedByName.isNotEmpty) {
      body['reported_by_name'] = reportedByName;
    }

    final response = await _client.post(
      Uri.parse('$baseUrl/school/students/discipline-incidents'),
      headers: _headers(token: token, jsonRequest: true),
      body: jsonEncode(body),
    );

    final payload = _decode(response);
    _throwIfNeeded(response, payload);
  }

  Future<DisciplineIncidentPage> studentDisciplineIncidents({
    required String token,
    required int page,
    String? search,
    int? levelId,
    int? classId,
    int? studentId,
  }) async {
    final queryParameters = <String, String>{
      'page': '$page',
    };

    if (search != null && search.isNotEmpty) {
      queryParameters['search'] = search;
    }

    if (levelId != null) {
      queryParameters['level_id'] = '$levelId';
    }

    if (classId != null) {
      queryParameters['class_id'] = '$classId';
    }

    if (studentId != null) {
      queryParameters['student_id'] = '$studentId';
    }

    final uri = Uri.parse('$baseUrl/school/students/discipline-incidents')
        .replace(queryParameters: queryParameters);

    final response = await _client.get(
      uri,
      headers: _headers(token: token),
    );

    final payload = _decode(response);
    _throwIfNeeded(response, payload);

    return DisciplineIncidentPage.fromJson(payload);
  }

  Future<StudentIncidentReport> studentDisciplineIncidentReport({
    required String token,
    required int classId,
    required int studentId,
  }) async {
    final uri =
        Uri.parse('$baseUrl/school/students/discipline-incidents/report')
            .replace(
      queryParameters: {
        'class_id': '$classId',
        'student_id': '$studentId',
      },
    );

    final response = await _client.get(
      uri,
      headers: _headers(token: token),
    );

    final payload = _decode(response);
    _throwIfNeeded(response, payload);

    return StudentIncidentReport.fromJson(payload);
  }

  Future<SubjectAttendanceFilters> subjectAttendanceFilters(
      String token) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/school/subject-attendance/filters'),
      headers: _headers(token: token),
    );

    final payload = _decode(response);
    _throwIfNeeded(response, payload);

    return SubjectAttendanceFilters.fromJson(payload);
  }

  Future<SubjectAttendanceSessionData> subjectAttendanceSession({
    required String token,
    required int academicYearId,
    required int schoolClassId,
    required String date,
    required int periodNumber,
  }) async {
    final uri = Uri.parse('$baseUrl/school/subject-attendance/session').replace(
      queryParameters: {
        'academic_year_id': '$academicYearId',
        'school_class_id': '$schoolClassId',
        'date': date,
        'period_number': '$periodNumber',
      },
    );

    final response = await _client.get(
      uri,
      headers: _headers(token: token),
    );

    final payload = _decode(response);
    _throwIfNeeded(response, payload);

    return SubjectAttendanceSessionData.fromJson(payload);
  }

  Future<void> saveSubjectAttendanceSession({
    required String token,
    required int academicYearId,
    required int schoolClassId,
    required String date,
    required int periodNumber,
    required List<SubjectAttendanceRecordDraft> records,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/school/subject-attendance/session'),
      headers: _headers(token: token, jsonRequest: true),
      body: jsonEncode({
        'academic_year_id': academicYearId,
        'school_class_id': schoolClassId,
        'date': date,
        'period_number': periodNumber,
        'records': records.map((record) => record.toJson()).toList(),
      }),
    );

    final payload = _decode(response);
    _throwIfNeeded(response, payload);
  }

  Future<void> logout(String token) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/logout'),
      headers: _headers(token: token),
    );

    final payload = _decode(response);
    _throwIfNeeded(response, payload);
  }

  Map<String, String> _headers({String? token, bool jsonRequest = false}) {
    final headers = <String, String>{
      'Accept': 'application/json',
    };

    if (jsonRequest) {
      headers['Content-Type'] = 'application/json';
    }

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.body.isEmpty) {
      return const {};
    }

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } on FormatException {
      return const {};
    }

    return const {};
  }

  List<dynamic> _decodeList(http.Response response) {
    if (response.body.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is List<dynamic>) {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return decoded;
        }

        final payload = <String, dynamic>{'message': 'Request failed.'};
        _throwIfNeeded(response, payload);
      }

      if (decoded is Map<String, dynamic>) {
        _throwIfNeeded(response, decoded);
      }
    } on FormatException {
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          'Request failed with status ${response.statusCode}.',
          statusCode: response.statusCode,
        );
      }
    }

    return const [];
  }

  void _throwIfNeeded(http.Response response, Map<String, dynamic> payload) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    final message = _extractMessage(payload) ??
        'Request failed with status ${response.statusCode}.';

    throw ApiException(message, statusCode: response.statusCode);
  }

  String? _extractMessage(Map<String, dynamic> payload) {
    final errors = payload['errors'];

    if (errors is Map) {
      for (final value in errors.values) {
        if (value is List && value.isNotEmpty) {
          return '${value.first}';
        }

        if (value is String && value.isNotEmpty) {
          return value;
        }
      }
    }

    final message = payload['message'];
    if (message is String && message.isNotEmpty) {
      return message;
    }

    return null;
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
}

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
