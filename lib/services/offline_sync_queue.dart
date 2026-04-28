import '../models/exam_models.dart';
import '../models/main_attendance_models.dart';
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
  });

  final int flushedCount;
  final int failedCount;
  final int remainingCount;
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
  }

  Future<void> remove(String key) async {
    final items = await readQueue();
    await _write(items.where((item) => item.key != key).toList());
  }

  Future<int> count() async {
    final items = await readQueue();
    return items.length;
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

    for (final item in items) {
      try {
        await _flushItem(api: api, token: token, item: item);
        await queue.remove(item.key);
        flushed += 1;
      } catch (_) {
        failed += 1;
      }
    }

    final remaining = await queue.count();
    return OfflineSyncResult(
      flushedCount: flushed,
      failedCount: failed,
      remainingCount: remaining,
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
    }
  }
}

const _queueKey = 'offline_sync_queue';
const mainAttendanceQueuePrefix = 'main_attendance:';
const subjectAttendanceQueuePrefix = 'subject_attendance:';
const examMarksQueuePrefix = 'exam_marks:';
const taskCompleteQueuePrefix = 'task_complete:';
const busAssignQueuePrefix = 'bus_assign:';
const _mainAttendanceType = 'main_attendance_save';
const _subjectAttendanceType = 'subject_attendance_save';
const _examMarksType = 'exam_marks_save';
const _taskCompleteType = 'task_complete';
const _busAssignType = 'bus_assign';

int _toInt(dynamic value) {
  if (value is int) {
    return value;
  }

  if (value is double) {
    return value.round();
  }

  return int.tryParse('$value') ?? 0;
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
