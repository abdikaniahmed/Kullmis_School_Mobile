import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/auth_session.dart';
import '../models/discipline_incident_models.dart';
import '../models/dashboard_data.dart';
import '../models/main_attendance_models.dart';
import '../models/student_list_models.dart';
import '../models/subject_attendance_models.dart';

class LaravelApi {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );

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
    final uri = Uri.parse('$baseUrl/school/students/discipline-incidents/report')
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
}

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
