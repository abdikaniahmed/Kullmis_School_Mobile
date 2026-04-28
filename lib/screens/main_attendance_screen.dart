import 'package:flutter/material.dart';

import '../models/main_attendance_models.dart';
import '../services/laravel_api.dart';
import '../services/offline_cache_store.dart';
import '../services/offline_sync_queue.dart';

class MainAttendanceScreen extends StatefulWidget {
  const MainAttendanceScreen({
    super.key,
    required this.api,
    required this.token,
  });

  final LaravelApi api;
  final String token;

  @override
  State<MainAttendanceScreen> createState() => _MainAttendanceScreenState();
}

class _MainAttendanceScreenState extends State<MainAttendanceScreen> {
  static const _statusOptions = <String>[
    'present',
    'absent',
    'late',
    'excused',
  ];
  static const _shiftOptions = <_ShiftOption>[
    _ShiftOption(value: 'shift_1', label: 'Shift 1'),
    _ShiftOption(value: 'shift_2', label: 'Shift 2'),
  ];

  final OfflineCacheStore _cacheStore = const FileOfflineCacheStore();
  final OfflineSyncQueue _syncQueue = const OfflineSyncQueue();

  ActiveAcademicYear? _academicYear;
  List<MainAttendanceLevel> _levels = const [];
  List<MainAttendanceClass> _classes = const [];
  MainAttendanceSessionData? _session;
  Map<int, _AttendanceDraft> _drafts = const {};
  int? _selectedLevelId;
  int? _selectedClassId;
  String _selectedShift = 'shift_1';
  DateTime _selectedDate = DateTime.now();
  bool _loadingMeta = true;
  bool _loadingClasses = false;
  bool _loadingSession = false;
  bool _saving = false;
  bool _usingOfflineData = false;
  bool _hasPendingDraft = false;
  String? _statusMessage;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  bool get _isFutureDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );

    return selected.isAfter(today);
  }

  Future<void> _loadMeta() async {
    setState(() {
      _loadingMeta = true;
      _error = null;
      _statusMessage = null;
    });

    try {
      final academicYear = await widget.api.activeAcademicYear(widget.token);
      final levels = await widget.api.attendanceLevels(widget.token);

      if (!mounted) {
        return;
      }

      setState(() {
        _academicYear = academicYear;
        _levels = levels;
        _selectedLevelId = levels.isNotEmpty ? levels.first.id : null;
        _loadingMeta = false;
        _usingOfflineData = false;
        _hasPendingDraft = false;
      });

      await _loadClasses();
      await _restoreSnapshotIfNeeded(force: true);
    } on ApiException catch (error) {
      final restored = await _restoreSnapshotIfNeeded(
        force: true,
        fallbackMessage: 'Offline mode: showing last synced attendance data.',
      );
      if (restored) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _loadingMeta = false;
        _error = error.message;
      });
    } catch (_) {
      final restored = await _restoreSnapshotIfNeeded(
        force: true,
        fallbackMessage: 'Offline mode: showing last synced attendance data.',
      );
      if (restored) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _loadingMeta = false;
        _error = 'Unable to load attendance setup.';
      });
    }
  }

  Future<void> _loadClasses() async {
    final levelId = _selectedLevelId;

    if (levelId == null) {
      setState(() {
        _classes = const [];
        _selectedClassId = null;
      });
      await _writeSnapshot();
      return;
    }

    setState(() {
      _loadingClasses = true;
    });

    try {
      final classes = await widget.api.attendanceClasses(
        token: widget.token,
        levelId: levelId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _classes = classes;
        _selectedClassId = classes.any((entry) => entry.id == _selectedClassId)
            ? _selectedClassId
            : (classes.isNotEmpty ? classes.first.id : null);
        _loadingClasses = false;
      });

      await _writeSnapshot();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _classes = const [];
        _selectedClassId = null;
        _loadingClasses = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _classes = const [];
        _selectedClassId = null;
        _loadingClasses = false;
        _error = 'Unable to load classes for the selected level.';
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _selectedDate = picked;
      _clearSession();
    });

    await _writeSnapshot();
  }

  Future<void> _loadAttendance() async {
    final academicYear = _academicYear;

    if (academicYear == null || _selectedClassId == null) {
      _showMessage('Select a class first.');
      return;
    }

    setState(() {
      _loadingSession = true;
      _error = null;
      _statusMessage = null;
    });

    try {
      final session = await widget.api.mainAttendanceSession(
        token: widget.token,
        academicYearId: academicYear.id,
        schoolClassId: _selectedClassId!,
        date: _formatDate(_selectedDate),
        shift: _selectedShift,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _session = session;
        _drafts = {
          for (final student in session.students)
            student.id: _AttendanceDraft(
              status: _statusOptions.contains(student.status)
                  ? student.status
                  : 'present',
              remarks: student.remarks,
            ),
        };
        _loadingSession = false;
        _saving = false;
        _usingOfflineData = false;
        _hasPendingDraft = false;
      });

      await _writeSnapshot();
    } on ApiException catch (error) {
      final restored = await _restoreSnapshotIfNeeded(
        fallbackMessage: 'Offline mode: showing last synced attendance data.',
      );
      if (restored) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _session = null;
        _drafts = const {};
        _loadingSession = false;
        _error = error.message;
      });
    } catch (_) {
      final restored = await _restoreSnapshotIfNeeded(
        fallbackMessage: 'Offline mode: showing last synced attendance data.',
      );
      if (restored) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _session = null;
        _drafts = const {};
        _loadingSession = false;
        _error = 'Unable to load attendance.';
      });
    }
  }

  Future<void> _saveAttendance() async {
    final academicYear = _academicYear;
    final session = _session;

    if (academicYear == null || session == null || _selectedClassId == null) {
      return;
    }

    if (_isFutureDate) {
      _showMessage('Future dates are not allowed for attendance.');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final records = session.students.map((student) {
        final draft = _drafts[student.id] ??
            const _AttendanceDraft(status: 'present', remarks: '');

        return MainAttendanceRecordDraft(
          studentId: student.studentId,
          status: draft.status,
          remarks: draft.remarks.trim(),
        );
      }).toList();

      await widget.api.saveMainAttendance(
        token: widget.token,
        academicYearId: academicYear.id,
        schoolClassId: _selectedClassId!,
        date: _formatDate(_selectedDate),
        shift: _selectedShift,
        records: records,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _hasPendingDraft = false;
        _usingOfflineData = false;
        _statusMessage = null;
      });

      await _syncQueue.remove(_queueKeyForAttendance());

      await _writeSnapshot();
      _showMessage('Attendance saved.');
      await _loadAttendance();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      await _writeSnapshot(
        pendingDraft: true,
        statusMessage:
            'Offline draft saved on this device. Sync again when the server is reachable.',
      );
      await _syncQueue.upsert(
        OfflineSyncOperation(
          key: _queueKeyForAttendance(),
          type: 'main_attendance_save',
          payload: {
            'academic_year_id': academicYear.id,
            'school_class_id': _selectedClassId!,
            'date': _formatDate(_selectedDate),
            'shift': _selectedShift,
            'records': records.map((item) => item.toJson()).toList(),
          },
          createdAt: DateTime.now().toIso8601String(),
        ),
      );

      _showMessage(error.message);
      setState(() {
        _saving = false;
        _usingOfflineData = true;
        _hasPendingDraft = true;
        _statusMessage =
            'Offline draft saved on this device. Sync again when the server is reachable.';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      await _writeSnapshot(
        pendingDraft: true,
        statusMessage:
            'Offline draft saved on this device. Sync again when the server is reachable.',
      );
      await _syncQueue.upsert(
        OfflineSyncOperation(
          key: _queueKeyForAttendance(),
          type: 'main_attendance_save',
          payload: {
            'academic_year_id': academicYear.id,
            'school_class_id': _selectedClassId!,
            'date': _formatDate(_selectedDate),
            'shift': _selectedShift,
            'records': records.map((item) => item.toJson()).toList(),
          },
          createdAt: DateTime.now().toIso8601String(),
        ),
      );

      _showMessage('Attendance saved locally as a draft.');
      setState(() {
        _saving = false;
        _usingOfflineData = true;
        _hasPendingDraft = true;
        _statusMessage =
            'Offline draft saved on this device. Sync again when the server is reachable.';
      });
    }
  }

  void _clearSession() {
    _session = null;
    _drafts = const {};
    _error = null;
    _statusMessage = null;
    _usingOfflineData = false;
    _hasPendingDraft = false;
  }

  Future<bool> _restoreSnapshotIfNeeded({
    bool force = false,
    String? fallbackMessage,
  }) async {
    final json = await _cacheStore.readCacheDocument(_attendanceCacheKey);
    if (json == null) {
      return false;
    }

    final snapshot = MainAttendanceCacheSnapshot.fromJson(json);
    if (!force && !_matchesSnapshot(snapshot)) {
      return false;
    }

    final selectedDate = DateTime.tryParse(snapshot.selectedDate);

    if (!mounted) {
      return true;
    }

    setState(() {
      _academicYear = snapshot.academicYear ?? _academicYear;
      _levels = snapshot.levels;
      _classes = snapshot.classes;
      _selectedLevelId = snapshot.selectedLevelId;
      _selectedClassId = snapshot.selectedClassId;
      _selectedShift = snapshot.selectedShift;
      _selectedDate = selectedDate ?? _selectedDate;
      _session = snapshot.session;
      _drafts = {
        for (final entry in snapshot.drafts.entries)
          entry.key: _AttendanceDraft(
            status: entry.value.status,
            remarks: entry.value.remarks,
          ),
      };
      _loadingMeta = false;
      _loadingClasses = false;
      _loadingSession = false;
      _saving = false;
      _usingOfflineData = snapshot.session != null || snapshot.drafts.isNotEmpty;
      _hasPendingDraft = snapshot.drafts.isNotEmpty;
      _statusMessage = snapshot.drafts.isNotEmpty
          ? 'Offline draft restored. Sync again when the server is reachable.'
          : (fallbackMessage ?? 'Offline mode: showing last synced attendance data.');
      _error = null;
    });

    return true;
  }

  bool _matchesSnapshot(MainAttendanceCacheSnapshot snapshot) {
    return snapshot.selectedLevelId == _selectedLevelId &&
        snapshot.selectedClassId == _selectedClassId &&
        snapshot.selectedShift == _selectedShift &&
        snapshot.selectedDate == _formatDate(_selectedDate);
  }

  Future<void> _writeSnapshot({
    bool pendingDraft = false,
    String? statusMessage,
  }) async {
    await _cacheStore.writeCacheDocument(
      _attendanceCacheKey,
      MainAttendanceCacheSnapshot(
        academicYear: _academicYear,
        levels: _levels,
        classes: _classes,
        selectedLevelId: _selectedLevelId,
        selectedClassId: _selectedClassId,
        selectedShift: _selectedShift,
        selectedDate: _formatDate(_selectedDate),
        session: _session,
        drafts: {
          for (final entry in _drafts.entries)
            entry.key: MainAttendanceDraftState(
              status: entry.value.status,
              remarks: entry.value.remarks,
            ),
        },
      ).toJson()
        ..['pending_draft'] = pendingDraft
        ..['status_message'] = statusMessage,
    );
  }

  void _updateDraftStatus(MainAttendanceStudent student, String value) {
    final existing = _drafts[student.id] ??
        _AttendanceDraft(status: student.status, remarks: student.remarks);

    setState(() {
      _drafts = {
        ..._drafts,
        student.id: existing.copyWith(status: value),
      };
      _hasPendingDraft = true;
    });

    _writeSnapshot(
      pendingDraft: true,
      statusMessage:
          'Offline draft saved on this device. Sync again when the server is reachable.',
    );
  }

  void _updateDraftRemarks(MainAttendanceStudent student, String value) {
    final existing = _drafts[student.id] ??
        _AttendanceDraft(status: student.status, remarks: student.remarks);

    setState(() {
      _drafts = {
        ..._drafts,
        student.id: existing.copyWith(remarks: value),
      };
      _hasPendingDraft = true;
    });

    _writeSnapshot(
      pendingDraft: true,
      statusMessage:
          'Offline draft saved on this device. Sync again when the server is reachable.',
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _queueKeyForAttendance() {
    return '$mainAttendanceQueuePrefix${_selectedClassId ?? 0}:${_selectedShift}:${_formatDate(_selectedDate)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Attendance'),
      ),
      body: _loadingMeta
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadMeta,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Load Attendance',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Choose the class, date, and shift to load student attendance.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (_statusMessage != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF4CE),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _hasPendingDraft
                                      ? Icons.save_outlined
                                      : Icons.cloud_off_outlined,
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
                        const SizedBox(height: 18),
                        _buildFilterFields(),
                        if (_isFutureDate) ...[
                          const SizedBox(height: 14),
                          Text(
                            'Future dates are not allowed for attendance.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFFB42318),
                            ),
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _error!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFFB42318),
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: 220,
                              child: FilledButton(
                                onPressed: _loadingSession || _loadingClasses
                                    ? null
                                    : _loadAttendance,
                                child: _loadingSession
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Load Attendance'),
                              ),
                            ),
                            if (_usingOfflineData)
                              OutlinedButton.icon(
                                onPressed: _loadingSession || _loadingClasses
                                    ? null
                                    : _loadAttendance,
                                icon: const Icon(Icons.cloud_sync_outlined),
                                label: const Text('Retry Online'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_session != null) ...[
                    const SizedBox(height: 20),
                    _buildSessionSummary(theme),
                    const SizedBox(height: 20),
                    _buildStudentList(theme),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildFilterFields() {
    return Column(
      children: [
        DropdownButtonFormField<int>(
          value: _selectedLevelId,
          decoration: const InputDecoration(
            labelText: 'Level',
            border: OutlineInputBorder(),
          ),
          items: _levels
              .map(
                (level) => DropdownMenuItem<int>(
                  value: level.id,
                  child: Text(level.name),
                ),
              )
              .toList(),
          onChanged: (value) async {
            setState(() {
              _selectedLevelId = value;
              _selectedClassId = null;
              _clearSession();
            });
            await _loadClasses();
          },
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<int>(
          value: _classes.any((entry) => entry.id == _selectedClassId)
              ? _selectedClassId
              : null,
          decoration: const InputDecoration(
            labelText: 'Class',
            border: OutlineInputBorder(),
          ),
          items: _classes
              .map(
                (schoolClass) => DropdownMenuItem<int>(
                  value: schoolClass.id,
                  child: Text(schoolClass.name),
                ),
              )
              .toList(),
          onChanged: _loadingClasses
              ? null
              : (value) async {
                  setState(() {
                    _selectedClassId = value;
                    _clearSession();
                  });
                  await _writeSnapshot();
                },
        ),
        const SizedBox(height: 14),
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Date',
              border: OutlineInputBorder(),
            ),
            child: Row(
              children: [
                Expanded(child: Text(_formatDate(_selectedDate))),
                const Icon(Icons.calendar_month),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          value: _selectedShift,
          decoration: const InputDecoration(
            labelText: 'Shift',
            border: OutlineInputBorder(),
          ),
          items: _shiftOptions
              .map(
                (shift) => DropdownMenuItem<String>(
                  value: shift.value,
                  child: Text(shift.label),
                ),
              )
              .toList(),
          onChanged: (value) async {
            if (value == null) {
              return;
            }

            setState(() {
              _selectedShift = value;
              _clearSession();
            });
            await _writeSnapshot();
          },
        ),
      ],
    );
  }

  Widget _buildSessionSummary(ThemeData theme) {
    final session = _session!;
    MainAttendanceClass? selectedClass;

    for (final entry in _classes) {
      if (entry.id == _selectedClassId) {
        selectedClass = entry;
        break;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFCB6E17), Color(0xFF9A3412)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            selectedClass?.name ?? 'Selected class',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${_shiftLabel(session.shift)} - ${session.date}',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${session.students.length} students loaded',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentList(ThemeData theme) {
    final session = _session!;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Students', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Set a status and optional remarks for each student.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ...session.students.map(_buildStudentTile),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving || _isFutureDate ? null : _saveAttendance,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _isFutureDate
                          ? 'Future Date Not Allowed'
                          : (_hasPendingDraft
                              ? 'Sync Attendance'
                              : 'Save Attendance'),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentTile(MainAttendanceStudent student) {
    final draft = _drafts[student.id] ??
        _AttendanceDraft(status: student.status, remarks: student.remarks);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              student.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2933),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              student.rollNumber == null
                  ? 'No roll number'
                  : 'Roll No: ${student.rollNumber}',
              style: const TextStyle(color: Color(0xFF52606D)),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _statusOptions.contains(draft.status)
                  ? draft.status
                  : 'present',
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: _statusOptions
                  .map(
                    (status) => DropdownMenuItem<String>(
                      value: status,
                      child: Text(_titleCase(status)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                _updateDraftStatus(student, value);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: draft.remarks,
              decoration: const InputDecoration(
                labelText: 'Remarks',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                _updateDraftRemarks(student, value);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceDraft {
  const _AttendanceDraft({
    required this.status,
    required this.remarks,
  });

  final String status;
  final String remarks;

  _AttendanceDraft copyWith({
    String? status,
    String? remarks,
  }) {
    return _AttendanceDraft(
      status: status ?? this.status,
      remarks: remarks ?? this.remarks,
    );
  }
}

class _ShiftOption {
  const _ShiftOption({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;
}

String _formatDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String _titleCase(String value) {
  if (value.isEmpty) {
    return value;
  }

  return value[0].toUpperCase() + value.substring(1);
}

String _shiftLabel(String shift) {
  switch (shift) {
    case 'shift_2':
      return 'Shift 2';
    case 'shift_1':
    default:
      return 'Shift 1';
  }
}

const _attendanceCacheKey = 'main_attendance_snapshot';
