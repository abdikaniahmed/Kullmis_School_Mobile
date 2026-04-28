import 'package:flutter/material.dart';

import '../models/main_attendance_models.dart';
import '../models/school_reports_models.dart';
import '../models/subject_attendance_models.dart';
import '../services/laravel_api.dart';
import '../services/offline_cache_store.dart';
import '../services/offline_sync_queue.dart';

class SubjectTimetableScreen extends StatefulWidget {
  const SubjectTimetableScreen({
    super.key,
    required this.api,
    required this.token,
    required this.canEdit,
  });

  final LaravelApi api;
  final String token;
  final bool canEdit;

  @override
  State<SubjectTimetableScreen> createState() => _SubjectTimetableScreenState();
}

class _SubjectTimetableScreenState extends State<SubjectTimetableScreen> {
  final OfflineCacheStore _cacheStore = const FileOfflineCacheStore();
  final OfflineSyncQueue _syncQueue = const OfflineSyncQueue();
  SubjectAttendanceFilters? _filters;
  SubjectTimetableResponse? _timetable;
  SubjectTimetableAssignmentResponse? _assignments;
  final Map<int, int?> _selectedAssignments = {};
  int? _selectedClassId;
  int _selectedDay = 1;
  bool _loadingFilters = true;
  bool _loadingTimetable = false;
  bool _saving = false;
  bool _usingOfflineData = false;
  bool _hasPendingDraft = false;
  String? _statusMessage;
  String? _error;

  static const _weekdays = <int, String>{
    0: 'Sunday',
    1: 'Monday',
    2: 'Tuesday',
    3: 'Wednesday',
    4: 'Thursday',
    5: 'Friday',
    6: 'Saturday',
  };

  @override
  void initState() {
    super.initState();
    _loadFilters();
  }

  Future<void> _loadFilters() async {
    setState(() {
      _loadingFilters = true;
      _statusMessage = null;
      _error = null;
    });

    try {
      final filters = await widget.api.subjectAttendanceFilters(widget.token);
      final firstClass = filters.classes.isNotEmpty ? filters.classes.first : null;
      final snapshot = await _readSnapshot();
      final restoredClassId = snapshot?.selectedClassId;
      final hasRestoredClass = filters.classes.any(
        (item) => item.id == restoredClassId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _filters = filters;
        _selectedClassId = hasRestoredClass ? restoredClassId : firstClass?.id;
        _selectedDay = (snapshot?.selectedDay ?? 0) > 0
            ? snapshot!.selectedDay
            : _selectedDay;
        _loadingFilters = false;
        _usingOfflineData = false;
      });
      await _writeSnapshot();
    } on ApiException catch (error) {
      final restored = await _restoreSnapshot(
        'Offline mode: showing last synced timetable setup.',
      );
      if (restored) {
        return;
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _loadingFilters = false;
        _error = error.message;
      });
    } catch (_) {
      final restored = await _restoreSnapshot(
        'Offline mode: showing last synced timetable setup.',
      );
      if (restored) {
        return;
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _loadingFilters = false;
        _error = 'Unable to load subject timetable setup.';
      });
    }
  }

  Future<void> _loadTimetable() async {
    final classId = _selectedClassId;
    if (classId == null) {
      return;
    }

    setState(() {
      _loadingTimetable = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        widget.api.subjectTimetable(
          token: widget.token,
          academicYearId: _filters?.academicYearId,
          schoolClassId: classId,
          dayOfWeek: _selectedDay,
        ),
        widget.api.subjectTimetableAssignments(
          token: widget.token,
          academicYearId: _filters?.academicYearId,
          schoolClassId: classId,
        ),
      ]);

      final timetable = results[0] as SubjectTimetableResponse;
      final assignments = results[1] as SubjectTimetableAssignmentResponse;
      final pendingDraft = await _loadPendingDraft(
        classId: classId,
        dayOfWeek: _selectedDay,
      );

      if (!mounted) {
        return;
      }

      _selectedAssignments
        ..clear()
        ..addEntries(
          timetable.entries.map(
            (item) => MapEntry(item.periodNumber, item.teacherSubjectAssignmentId),
          ),
        );

      setState(() {
        _timetable = timetable;
        _assignments = assignments;
        _loadingTimetable = false;
        _usingOfflineData = false;
        _hasPendingDraft = pendingDraft != null;
        _statusMessage = pendingDraft == null
            ? null
            : 'Offline timetable draft restored. Sync again when the server is reachable.';
      });

      if (pendingDraft != null) {
        _selectedAssignments
          ..clear()
          ..addAll(pendingDraft);
        setState(() {});
      }
      await _writeSnapshot();
    } on ApiException catch (error) {
      final restored = await _restoreSnapshot(
        'Offline mode: showing last synced subject timetable.',
      );
      if (restored) {
        return;
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _timetable = null;
        _assignments = null;
        _loadingTimetable = false;
        _error = error.message;
      });
    } catch (_) {
      final restored = await _restoreSnapshot(
        'Offline mode: showing last synced subject timetable.',
      );
      if (restored) {
        return;
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _timetable = null;
        _assignments = null;
        _loadingTimetable = false;
        _error = 'Unable to load subject timetable.';
      });
    }
  }

  Future<void> _saveTimetable() async {
    final classId = _selectedClassId;
    final timetable = _timetable;
    if (classId == null || timetable == null) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final entries = timetable.periods
          .map(
            (period) => SubjectTimetableSaveDraft(
              periodNumber: period.value,
              teacherSubjectAssignmentId: _selectedAssignments[period.value],
            ),
          )
          .toList();

      await widget.api.saveSubjectTimetable(
        token: widget.token,
        academicYearId: _filters?.academicYearId,
        schoolClassId: classId,
        dayOfWeek: _selectedDay,
        entries: entries,
      );
      await _syncQueue.remove(_queueKey(classId, _selectedDay));

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Subject timetable saved.')),
        );

      setState(() {
        _saving = false;
        _hasPendingDraft = false;
        _usingOfflineData = false;
        _statusMessage = null;
      });

      await _loadTimetable();
    } on ApiException catch (error) {
      await _queueOfflineDraft(
        classId: classId,
        timetable: timetable,
      );
    } catch (_) {
      await _queueOfflineDraft(
        classId: classId,
        timetable: timetable,
      );
    }
  }

  Future<void> _queueOfflineDraft({
    required int classId,
    required SubjectTimetableResponse timetable,
  }) async {
    final entries = timetable.periods
        .map(
          (period) => SubjectTimetableSaveDraft(
            periodNumber: period.value,
            teacherSubjectAssignmentId: _selectedAssignments[period.value],
          ),
        )
        .toList();

    await _syncQueue.upsert(
      OfflineSyncOperation(
        key: _queueKey(classId, _selectedDay),
        type: 'subject_timetable_save',
        payload: {
          'academic_year_id': _filters?.academicYearId,
          'school_class_id': classId,
          'day_of_week': _selectedDay,
          'entries': entries.map((item) => item.toJson()).toList(),
        },
        createdAt: DateTime.now().toIso8601String(),
      ),
    );

    await _writeSnapshot();

    if (!mounted) {
      return;
    }

    setState(() {
      _saving = false;
      _usingOfflineData = true;
      _hasPendingDraft = true;
      _statusMessage =
          'Timetable draft saved locally and queued for sync.';
      _error = null;
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Subject timetable saved offline for later sync.'),
        ),
      );
  }

  Future<SubjectTimetableOfflineSnapshot?> _readSnapshot() async {
    final json = await _cacheStore.readCacheDocument(_cacheKey);
    if (json == null) {
      return null;
    }

    return SubjectTimetableOfflineSnapshot.fromJson(json);
  }

  Future<bool> _restoreSnapshot(String fallbackMessage) async {
    final snapshot = await _readSnapshot();
    if (snapshot == null) {
      return false;
    }

    final pendingDraft = await _loadPendingDraft(
      classId: snapshot.selectedClassId,
      dayOfWeek: snapshot.selectedDay,
    );

    if (!mounted) {
      return true;
    }

    _selectedAssignments
      ..clear()
      ..addAll(pendingDraft ?? snapshot.selectedAssignments);

    setState(() {
      _filters = snapshot.filters;
      _timetable = snapshot.timetable;
      _assignments = snapshot.assignments;
      _selectedClassId = snapshot.selectedClassId;
      _selectedDay = snapshot.selectedDay;
      _loadingFilters = false;
      _loadingTimetable = false;
      _saving = false;
      _usingOfflineData = true;
      _hasPendingDraft = pendingDraft != null;
      _statusMessage = pendingDraft == null
          ? fallbackMessage
          : 'Offline timetable draft restored. Sync again when the server is reachable.';
      _error = null;
    });

    return true;
  }

  Future<void> _writeSnapshot() async {
    await _cacheStore.writeCacheDocument(
      _cacheKey,
      SubjectTimetableOfflineSnapshot(
        filters: _filters,
        timetable: _timetable,
        assignments: _assignments,
        selectedClassId: _selectedClassId,
        selectedDay: _selectedDay,
        selectedAssignments: _selectedAssignments,
      ).toJson(),
    );
  }

  Future<Map<int, int?>?> _loadPendingDraft({
    required int? classId,
    required int dayOfWeek,
  }) async {
    if (classId == null) {
      return null;
    }

    final queued = await _syncQueue.readQueue();
    OfflineSyncOperation? operation;
    for (final item in queued) {
      if (item.key == _queueKey(classId, dayOfWeek)) {
        operation = item;
        break;
      }
    }
    if (operation == null) {
      return null;
    }

    final entries = operation.payload['entries'] as List<dynamic>? ?? const [];
    return {
      for (final entry in entries.whereType<Map<String, dynamic>>())
        _parseInt(entry['period_number']):
            _parseNullableInt(entry['teacher_subject_assignment_id']),
    };
  }

  String _queueKey(int classId, int dayOfWeek) =>
      '$subjectTimetableQueuePrefix$classId:$dayOfWeek';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timetable = _timetable;
    final assignments = _assignments?.assignments ?? const <SubjectTimetableAssignment>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Subject Timetable')),
      body: RefreshIndicator(
        onRefresh: _loadFilters,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            if (_statusMessage != null) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4CE),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      _usingOfflineData
                          ? Icons.cloud_off_outlined
                          : Icons.sync_problem_outlined,
                      size: 18,
                      color: const Color(0xFF7A4F01),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF7A4F01),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: _loadingFilters
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Timetable Filters', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          value: _selectedClassId,
                          decoration: const InputDecoration(labelText: 'Class'),
                          items: (_filters?.classes ?? const <AttendanceClass>[])
                              .map(
                                (item) => DropdownMenuItem<int>(
                                  value: item.id,
                                  child: Text(item.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedClassId = value;
                              _timetable = null;
                            });
                            _writeSnapshot();
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          value: _selectedDay,
                          decoration: const InputDecoration(labelText: 'Day'),
                          items: _weekdays.entries
                              .map(
                                (item) => DropdownMenuItem<int>(
                                  value: item.key,
                                  child: Text(item.value),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _selectedDay = value;
                              _timetable = null;
                            });
                            _writeSnapshot();
                          },
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _loadingTimetable ? null : _loadTimetable,
                          icon: const Icon(Icons.schedule_outlined),
                          label: Text(
                            _loadingTimetable ? 'Loading...' : 'Load Timetable',
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 20),
            if (timetable != null)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _weekdays[_selectedDay] ?? 'Day',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    ...timetable.periods.map(
                      (period) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                period.label,
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 10),
                              if (widget.canEdit)
                                DropdownButtonFormField<int?>(
                                  value: _selectedAssignments[period.value],
                                  decoration: const InputDecoration(
                                    labelText: 'Assignment',
                                  ),
                                  items: [
                                    const DropdownMenuItem<int?>(
                                      value: null,
                                      child: Text('Unassigned'),
                                    ),
                                    ...assignments.map(
                                      (item) => DropdownMenuItem<int?>(
                                        value: item.id,
                                        child: Text(item.label),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedAssignments[period.value] = value;
                                    });
                                    _writeSnapshot();
                                  },
                                )
                              else
                                Text(
                                  assignments
                                          .firstWhere(
                                            (item) =>
                                                item.id ==
                                                _selectedAssignments[period.value],
                                            orElse: () =>
                                                const SubjectTimetableAssignment(
                                              id: 0,
                                              subjectId: null,
                                              teacherId: null,
                                              label: 'Unassigned',
                                              subjectName: null,
                                              teacherName: null,
                                            ),
                                          )
                                          .label
                                          .isEmpty
                                      ? 'Unassigned'
                                      : assignments
                                          .firstWhere(
                                            (item) =>
                                                item.id ==
                                                _selectedAssignments[period.value],
                                            orElse: () =>
                                                const SubjectTimetableAssignment(
                                              id: 0,
                                              subjectId: null,
                                              teacherId: null,
                                              label: 'Unassigned',
                                              subjectName: null,
                                              teacherName: null,
                                            ),
                                          )
                                          .label,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (widget.canEdit) ...[
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _saving ? null : _saveTimetable,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(
                          _saving
                              ? 'Saving...'
                              : _hasPendingDraft
                                  ? 'Sync Timetable'
                                  : 'Save Timetable',
                        ),
                      ),
                    ],
                  ],
                ),
              )
            else if (!_loadingFilters && !_loadingTimetable)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Load a class timetable to review or update subject periods.',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

const _cacheKey = 'subject_timetable_snapshot';

int _parseInt(dynamic value) {
  if (value is int) {
    return value;
  }

  if (value is double) {
    return value.round();
  }

  return int.tryParse('$value') ?? 0;
}

int? _parseNullableInt(dynamic value) {
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
