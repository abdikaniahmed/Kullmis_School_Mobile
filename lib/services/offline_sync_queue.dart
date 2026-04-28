import '../models/exam_models.dart';
import '../models/finance_admin_models.dart';
import '../models/main_attendance_models.dart';
import '../models/school_reports_models.dart';
import '../models/subject_attendance_models.dart';
import 'laravel_api.dart';
import 'offline_cache_store.dart';

class OfflineSyncOperation {
  const OfflineSyncOperation({
    required this.key,
    required this.type,
    required this.payload,
    required this.createdAt,
  });

  final String key;
  final String type;
  final Map<String, dynamic> payload;
  final String createdAt;

  factory OfflineSyncOperation.fromJson(Map<String, dynamic> json) {
    return OfflineSyncOperation(
      key: '${json['key'] ?? ''}',
      type: '${json['type'] ?? ''}',
      payload: json['payload'] as Map<String, dynamic>? ?? const {},
      createdAt: '${json['created_at'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'type': type,
      'payload': payload,
      'created_at': createdAt,
    };
  }
}

class OfflineSyncResult {
  const OfflineSyncResult({
    required this.flushedCount,
    required this.failedCount,
    required this.remainingCount,
    required this.issueCount,
  });

  final int flushedCount;
  final int failedCount;
  final int remainingCount;
  final int issueCount;
}

class OfflineSyncIssue {
  const OfflineSyncIssue({
    required this.key,
    required this.type,
    required this.payload,
    required this.message,
    required this.statusCode,
    required this.createdAt,
  });

  final String key;
  final String type;
  final Map<String, dynamic> payload;
  final String message;
  final int? statusCode;
  final String createdAt;

  factory OfflineSyncIssue.fromJson(Map<String, dynamic> json) {
    return OfflineSyncIssue(
      key: '${json['key'] ?? ''}',
      type: '${json['type'] ?? ''}',
      payload: json['payload'] as Map<String, dynamic>? ?? const {},
      message: '${json['message'] ?? ''}',
      statusCode: _toNullableInt(json['status_code']),
      createdAt: '${json['created_at'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'type': type,
      'payload': payload,
      'message': message,
      'status_code': statusCode,
      'created_at': createdAt,
    };
  }
}

class OfflineSyncQueue {
  const OfflineSyncQueue({
    this.cacheStore = const FileOfflineCacheStore(),
  });

  final OfflineCacheStore cacheStore;

  Future<List<OfflineSyncOperation>> readQueue() async {
    final json = await cacheStore.readCacheDocument(_queueKey);
    final items = json?['items'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(OfflineSyncOperation.fromJson)
        .toList();
  }

  Future<void> upsert(OfflineSyncOperation operation) async {
    final items = await readQueue();
    final next = <OfflineSyncOperation>[
      for (final item in items)
        if (item.key != operation.key) item,
      operation,
    ];
    await _write(next);
    await clearIssue(operation.key);
  }

  Future<void> remove(String key) async {
    final items = await readQueue();
    await _write(items.where((item) => item.key != key).toList());
  }

  Future<int> count() async {
    final items = await readQueue();
    return items.length;
  }

  Future<List<OfflineSyncIssue>> readIssues() async {
    final json = await cacheStore.readCacheDocument(_issuesKey);
    final items = json?['items'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(OfflineSyncIssue.fromJson)
        .toList();
  }

  Future<int> countIssues() async {
    final items = await readIssues();
    return items.length;
  }

  Future<void> recordIssue(OfflineSyncIssue issue) async {
    final items = await readIssues();
    final next = <OfflineSyncIssue>[
      for (final item in items)
        if (item.key != issue.key) item,
      issue,
    ];
    await cacheStore.writeCacheDocument(
      _issuesKey,
      {
        'items': next.map((item) => item.toJson()).toList(),
      },
    );
  }

  Future<void> clearIssue(String key) async {
    final items = await readIssues();
    await cacheStore.writeCacheDocument(
      _issuesKey,
      {
        'items': items
            .where((item) => item.key != key)
            .map((item) => item.toJson())
            .toList(),
      },
    );
  }

  Future<void> clearAllIssues() async {
    await cacheStore.writeCacheDocument(
      _issuesKey,
      const {'items': []},
    );
  }

  Future<void> requeueIssue(String key) async {
    final issues = await readIssues();
    final issue = issues.where((item) => item.key == key).firstOrNull;
    if (issue == null) {
      return;
    }

    await upsert(
      OfflineSyncOperation(
        key: issue.key,
        type: issue.type,
        payload: issue.payload,
        createdAt: issue.createdAt,
      ),
    );
  }

  Future<void> _write(List<OfflineSyncOperation> items) async {
    await cacheStore.writeCacheDocument(
      _queueKey,
      {
        'items': items.map((item) => item.toJson()).toList(),
      },
    );
  }
}

class OfflineSyncCoordinator {
  const OfflineSyncCoordinator({
    this.queue = const OfflineSyncQueue(),
  });

  final OfflineSyncQueue queue;

  Future<OfflineSyncResult> flush({
    required LaravelApi api,
    required String token,
  }) async {
    final items = await queue.readQueue();
    var flushed = 0;
    var failed = 0;
    var issues = 0;

    for (final item in items) {
      try {
        await _flushItem(api: api, token: token, item: item);
        await queue.remove(item.key);
        flushed += 1;
      } on ApiException catch (error) {
        if (_shouldMoveToIssue(error.statusCode)) {
          await queue.recordIssue(
            OfflineSyncIssue(
              key: item.key,
              type: item.type,
              payload: item.payload,
              message: error.message,
              statusCode: error.statusCode,
              createdAt: DateTime.now().toIso8601String(),
            ),
          );
          await queue.remove(item.key);
          issues += 1;
          continue;
        }
        failed += 1;
      } catch (_) {
        failed += 1;
      }
    }

    final remaining = await queue.count();
    final issueCount = await queue.countIssues();
    return OfflineSyncResult(
      flushedCount: flushed,
      failedCount: failed,
      remainingCount: remaining,
      issueCount: issueCount,
    );
  }

  Future<void> _flushItem({
    required LaravelApi api,
    required String token,
    required OfflineSyncOperation item,
  }) async {
    switch (item.type) {
      case _mainAttendanceType:
        await api.saveMainAttendance(
          token: token,
          academicYearId: _toInt(item.payload['academic_year_id']),
          schoolClassId: _toInt(item.payload['school_class_id']),
          date: '${item.payload['date'] ?? ''}',
          shift: '${item.payload['shift'] ?? 'shift_1'}',
          records: (item.payload['records'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(
                (row) => MainAttendanceRecordDraft(
                  studentId: _toInt(row['student_id']),
                  status: '${row['status'] ?? 'present'}',
                  remarks: '${row['remarks'] ?? ''}',
                ),
              )
              .toList(),
        );
        return;
      case _subjectAttendanceType:
        await api.saveSubjectAttendanceSession(
          token: token,
          academicYearId: _toInt(item.payload['academic_year_id']),
          schoolClassId: _toInt(item.payload['school_class_id']),
          date: '${item.payload['date'] ?? ''}',
          periodNumber: _toInt(item.payload['period_number']),
          records: (item.payload['records'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(
                (row) => SubjectAttendanceRecordDraft(
                  studentId: _toInt(row['student_id']),
                  status: '${row['status'] ?? 'present'}',
                  remarks: '${row['remarks'] ?? ''}',
                ),
              )
              .toList(),
        );
        return;
      case _examMarksType:
        await api.saveBulkMarks(
          token: token,
          classId: _toInt(item.payload['class_id']),
          marks: (item.payload['marks'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(
                (row) => ExamMarkDraft(
                  studentId: _toInt(row['student_id']),
                  subjectId: _toInt(row['subject_id']),
                  examId: _toInt(row['exam_id']),
                  mark: _toDouble(row['mark']),
                  comment: _toNullableString(row['comment']),
                ),
              )
              .toList(),
        );
        return;
      case _taskCompleteType:
        await api.completeTask(
          token: token,
          taskId: _toInt(item.payload['task_id']),
        );
        return;
      case _taskCreateType:
        await api.createTask(
          token: token,
          payload: item.payload['payload'] as Map<String, dynamic>? ?? const {},
        );
        return;
      case _taskUpdateType:
        await api.updateTask(
          token: token,
          taskId: _toInt(item.payload['task_id']),
          payload: item.payload['payload'] as Map<String, dynamic>? ?? const {},
        );
        return;
      case _taskDeleteType:
        await api.deleteTask(
          token: token,
          taskId: _toInt(item.payload['task_id']),
        );
        return;
      case _expenseCreateType:
        await api.createExpense(
          token: token,
          payload: item.payload['payload'] as Map<String, dynamic>? ?? const {},
        );
        return;
      case _expenseUpdateType:
        await api.updateExpense(
          token: token,
          expenseId: _toInt(item.payload['expense_id']),
          payload: item.payload['payload'] as Map<String, dynamic>? ?? const {},
        );
        return;
      case _expenseDeleteType:
        await api.deleteExpense(
          token: token,
          expenseId: _toInt(item.payload['expense_id']),
        );
        return;
      case _pettyCashCreateType:
        await api.createPettyCashBudget(
          token: token,
          payload: item.payload['payload'] as Map<String, dynamic>? ?? const {},
        );
        return;
      case _pettyCashUpdateType:
        await api.updatePettyCashBudget(
          token: token,
          budgetId: _toInt(item.payload['budget_id']),
          payload: item.payload['payload'] as Map<String, dynamic>? ?? const {},
        );
        return;
      case _pettyCashDeleteType:
        await api.deletePettyCashBudget(
          token: token,
          budgetId: _toInt(item.payload['budget_id']),
        );
        return;
      case _pettyCashTopUpType:
        await api.topUpPettyCashBudget(
          token: token,
          budgetId: _toInt(item.payload['budget_id']),
          payload: item.payload['payload'] as Map<String, dynamic>? ?? const {},
        );
        return;
      case _busAssignType:
        await api.assignBusStudents(
          token: token,
          busId: _toInt(item.payload['bus_id']),
          studentIds: (item.payload['student_ids'] as List<dynamic>? ?? const [])
              .map(_toInt)
              .where((value) => value > 0)
              .toList(),
        );
        return;
      case _subjectTimetableType:
        await api.saveSubjectTimetable(
          token: token,
          academicYearId: _toNullableInt(item.payload['academic_year_id']),
          schoolClassId: _toInt(item.payload['school_class_id']),
          dayOfWeek: _toInt(item.payload['day_of_week']),
          entries: (item.payload['entries'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(
                (row) => SubjectTimetableSaveDraft(
                  periodNumber: _toInt(row['period_number']),
                  teacherSubjectAssignmentId:
                      _toNullableInt(row['teacher_subject_assignment_id']),
                ),
              )
              .toList(),
        );
        return;
      case _incidentCreateType:
        await api.createStudentDisciplineIncident(
          token: token,
          studentId: _toInt(item.payload['student_id']),
          whatHappened: '${item.payload['what_happened'] ?? ''}',
          happenedAt: '${item.payload['happened_at'] ?? ''}',
          actionTaken: _toNullableString(item.payload['action_taken']),
          reportedByName: _toNullableString(item.payload['reported_by_name']),
        );
        return;
    }
  }
}

const _queueKey = 'offline_sync_queue';
const _issuesKey = 'offline_sync_issues';
const mainAttendanceQueuePrefix = 'main_attendance:';
const subjectAttendanceQueuePrefix = 'subject_attendance:';
const examMarksQueuePrefix = 'exam_marks:';
const taskCompleteQueuePrefix = 'task_complete:';
const taskCreateQueuePrefix = 'task_create:';
const taskUpdateQueuePrefix = 'task_update:';
const taskDeleteQueuePrefix = 'task_delete:';
const expenseCreateQueuePrefix = 'expense_create:';
const expenseUpdateQueuePrefix = 'expense_update:';
const expenseDeleteQueuePrefix = 'expense_delete:';
const pettyCashCreateQueuePrefix = 'petty_cash_create:';
const pettyCashUpdateQueuePrefix = 'petty_cash_update:';
const pettyCashDeleteQueuePrefix = 'petty_cash_delete:';
const pettyCashTopUpQueuePrefix = 'petty_cash_topup:';
const busAssignQueuePrefix = 'bus_assign:';
const subjectTimetableQueuePrefix = 'subject_timetable:';
const incidentCreateQueuePrefix = 'incident_create:';
const _mainAttendanceType = 'main_attendance_save';
const _subjectAttendanceType = 'subject_attendance_save';
const _examMarksType = 'exam_marks_save';
const _taskCompleteType = 'task_complete';
const _taskCreateType = 'task_create';
const _taskUpdateType = 'task_update';
const _taskDeleteType = 'task_delete';
const _expenseCreateType = 'expense_create';
const _expenseUpdateType = 'expense_update';
const _expenseDeleteType = 'expense_delete';
const _pettyCashCreateType = 'petty_cash_create';
const _pettyCashUpdateType = 'petty_cash_update';
const _pettyCashDeleteType = 'petty_cash_delete';
const _pettyCashTopUpType = 'petty_cash_topup';
const _busAssignType = 'bus_assign';
const _subjectTimetableType = 'subject_timetable_save';
const _incidentCreateType = 'incident_create';

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

  if (value is int) {
    return value;
  }

  if (value is double) {
    return value.round();
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

bool _shouldMoveToIssue(int? statusCode) {
  return statusCode == 400 ||
      statusCode == 403 ||
      statusCode == 404 ||
      statusCode == 409 ||
      statusCode == 422;
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
