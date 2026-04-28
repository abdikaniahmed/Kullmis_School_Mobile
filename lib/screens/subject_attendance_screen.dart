import 'package:flutter/material.dart';

import '../models/subject_attendance_models.dart';
import '../services/laravel_api.dart';
import '../services/offline_cache_store.dart';
import '../services/offline_sync_queue.dart';

class SubjectAttendanceScreen extends StatefulWidget {
  const SubjectAttendanceScreen({
    super.key,
    required this.api,
    required this.token,
  });

  final LaravelApi api;
  final String token;

  @override
  State<SubjectAttendanceScreen> createState() =>
      _SubjectAttendanceScreenState();
}

class _SubjectAttendanceScreenState extends State<SubjectAttendanceScreen> {
  static const _statusOptions = <String>[
    'present',
    'absent',
    'late',
    'excused'
  ];

  final OfflineCacheStore _cacheStore = const FileOfflineCacheStore();
  final OfflineSyncQueue _syncQueue = const OfflineSyncQueue();

  SubjectAttendanceFilters? _filters;
  SubjectAttendanceSessionData? _session;
  Map<int, _AttendanceDraft> _drafts = const {};
  int? _selectedLevelId;
  int? _selectedClassId;
  int? _selectedPeriodNumber;
  DateTime _selectedDate = DateTime.now();
  bool _loadingFilters = true;
  bool _loadingSession = false;
  bool _saving = false;
  bool _usingOfflineData = false;
  bool _hasPendingDraft = false;
  String? _statusMessage;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFilters();
  }

  List<AttendanceClass> get _filteredClasses {
    final filters = _filters;
    if (filters == null) {
      return const [];
    }

    if (_selectedLevelId == null) {
      return filters.classes;
    }

    return filters.classes
        .where((entry) => entry.levelId == _selectedLevelId)
        .toList();
  }

  Future<void> _loadFilters() async {
    setState(() {
      _loadingFilters = true;
      _error = null;
      _statusMessage = null;
    });

    try {
      final filters = await widget.api.subjectAttendanceFilters(widget.token);
      final firstClass =
          filters.classes.isNotEmpty ? filters.classes.first : null;
      final firstPeriod =
          filters.periods.isNotEmpty ? filters.periods.first.value : 1;

      if (!mounted) {
        return;
      }

      setState(() {
        _filters = filters;
        _selectedLevelId = firstClass?.levelId;
        _selectedClassId = firstClass?.id;
        _selectedPeriodNumber = firstPeriod;
        _loadingFilters = false;
        _usingOfflineData = false;
        _hasPendingDraft = false;
      });

      await _restoreSnapshotIfNeeded(force: true);
    } on ApiException catch (error) {
      final restored = await _restoreSnapshotIfNeeded(
        force: true,
        fallbackMessage: 'Offline mode: showing last synced subject attendance.',
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
      final restored = await _restoreSnapshotIfNeeded(
        force: true,
        fallbackMessage: 'Offline mode: showing last synced subject attendance.',
      );
      if (restored) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _loadingFilters = false;
        _error = 'Unable to load subject attendance setup.';
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

  Future<void> _loadSession() async {
    final filters = _filters;

    if (filters == null ||
        _selectedClassId == null ||
        _selectedPeriodNumber == null) {
      _showMessage('Select a class and period first.');
      return;
    }

    setState(() {
      _loadingSession = true;
      _error = null;
      _statusMessage = null;
    });

    try {
      final session = await widget.api.subjectAttendanceSession(
        token: widget.token,
        academicYearId: filters.academicYearId,
        schoolClassId: _selectedClassId!,
        date: _formatDate(_selectedDate),
        periodNumber: _selectedPeriodNumber!,
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
        fallbackMessage: 'Offline mode: showing last synced subject attendance.',
      );
      if (restored) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _loadingSession = false;
        _session = null;
        _drafts = const {};
        _error = error.message;
      });
    } catch (_) {
      final restored = await _restoreSnapshotIfNeeded(
        fallbackMessage: 'Offline mode: showing last synced subject attendance.',
      );
      if (restored) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _loadingSession = false;
        _session = null;
        _drafts = const {};
        _error = 'Unable to load the subject session.';
      });
    }
  }

  Future<void> _saveAttendance() async {
    final filters = _filters;
    final session = _session;

    if (filters == null ||
        session == null ||
        _selectedClassId == null ||
        _selectedPeriodNumber == null) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final records = session.students.map((student) {
        final draft = _drafts[student.id] ??
            const _AttendanceDraft(status: 'present', remarks: '');

        return SubjectAttendanceRecordDraft(
          studentId: student.studentId,
          status: draft.status,
          remarks: draft.remarks.trim(),
        );
      }).toList();

      await widget.api.saveSubjectAttendanceSession(
        token: widget.token,
        academicYearId: filters.academicYearId,
        schoolClassId: _selectedClassId!,
        date: _formatDate(_selectedDate),
        periodNumber: _selectedPeriodNumber!,
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
      _showMessage('Subject attendance saved.');
      await _loadSession();
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
          type: 'subject_attendance_save',
          payload: {
            'academic_year_id': filters.academicYearId,
            'school_class_id': _selectedClassId!,
            'date': _formatDate(_selectedDate),
            'period_number': _selectedPeriodNumber!,
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
          type: 'subject_attendance_save',
          payload: {
            'academic_year_id': filters.academicYearId,
            'school_class_id': _selectedClassId!,
            'date': _formatDate(_selectedDate),
            'period_number': _selectedPeriodNumber!,
            'records': records.map((item) => item.toJson()).toList(),
          },
          createdAt: DateTime.now().toIso8601String(),
        ),
      );

      _showMessage('Subject attendance saved locally as a draft.');
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
    final json = await _cacheStore.readCacheDocument(_subjectAttendanceCacheKey);
    if (json == null) {
      return false;
    }

    final snapshot = SubjectAttendanceOfflineSnapshot.fromJson(json);
    if (!force && !_matchesSnapshot(snapshot)) {
      return false;
    }

    final selectedDate = DateTime.tryParse(snapshot.selectedDate);

    if (!mounted) {
      return true;
    }

    setState(() {
      _filters = snapshot.filters ?? _filters;
      _selectedLevelId = snapshot.selectedLevelId;
      _selectedClassId = snapshot.selectedClassId;
      _selectedPeriodNumber = snapshot.selectedPeriodNumber;
      _selectedDate = selectedDate ?? _selectedDate;
      _session = snapshot.session;
      _drafts = {
        for (final entry in snapshot.drafts.entries)
          entry.key: _AttendanceDraft(
            status: entry.value.status,
            remarks: entry.value.remarks,
          ),
      };
      _loadingFilters = false;
      _loadingSession = false;
      _saving = false;
      _usingOfflineData = snapshot.session != null || snapshot.drafts.isNotEmpty;
      _hasPendingDraft = snapshot.drafts.isNotEmpty;
      _statusMessage = snapshot.drafts.isNotEmpty
          ? 'Offline draft restored. Sync again when the server is reachable.'
          : (fallbackMessage ??
              'Offline mode: showing last synced subject attendance.');
      _error = null;
    });

    return true;
  }

  bool _matchesSnapshot(SubjectAttendanceOfflineSnapshot snapshot) {
    return snapshot.selectedLevelId == _selectedLevelId &&
        snapshot.selectedClassId == _selectedClassId &&
        snapshot.selectedPeriodNumber == _selectedPeriodNumber &&
        snapshot.selectedDate == _formatDate(_selectedDate);
  }

  Future<void> _writeSnapshot({
    bool pendingDraft = false,
    String? statusMessage,
  }) async {
    await _cacheStore.writeCacheDocument(
      _subjectAttendanceCacheKey,
      SubjectAttendanceOfflineSnapshot(
        filters: _filters,
        selectedLevelId: _selectedLevelId,
        selectedClassId: _selectedClassId,
        selectedPeriodNumber: _selectedPeriodNumber,
        selectedDate: _formatDate(_selectedDate),
        session: _session,
        drafts: {
          for (final entry in _drafts.entries)
            entry.key: SubjectAttendanceDraftState(
              status: entry.value.status,
              remarks: entry.value.remarks,
            ),
        },
      ).toJson()
        ..['pending_draft'] = pendingDraft
        ..['status_message'] = statusMessage,
    );
  }

  void _updateDraftStatus(SubjectAttendanceStudent student, String value) {
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

  void _updateDraftRemarks(SubjectAttendanceStudent student, String value) {
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
    return '$subjectAttendanceQueuePrefix${_selectedClassId ?? 0}:${_selectedPeriodNumber ?? 0}:${_formatDate(_selectedDate)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subject Attendance'),
      ),
      body: _loadingFilters
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadFilters,
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
                        Text('Load Subject Session',
                            style: theme.textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text(
                          'Choose your class, date, and period to take subject attendance.',
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
                              width: 240,
                              child: FilledButton(
                                onPressed: _loadingSession ? null : _loadSession,
                                child: _loadingSession
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Text('Load Subject Session'),
                              ),
                            ),
                            if (_usingOfflineData)
                              OutlinedButton.icon(
                                onPressed: _loadingSession ? null : _loadSession,
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
    final filters = _filters;
    final classes = _filteredClasses;
    final periods = filters?.periods ?? const <AttendancePeriod>[];

    return LayoutBuilder(
      builder: (context, constraints) {
        final fieldWidth = constraints.maxWidth >= 1100
            ? (constraints.maxWidth - 42) / 4
            : 260.0;

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            SizedBox(
              width: fieldWidth,
              child: DropdownButtonFormField<int>(
                value: _selectedLevelId,
                decoration: const InputDecoration(
                  labelText: 'Level',
                  border: OutlineInputBorder(),
                ),
                items: (filters?.levels ?? const <AttendanceLevel>[])
                    .map(
                      (level) => DropdownMenuItem<int>(
                        value: level.id,
                        child: Text(level.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedLevelId = value;
                    final firstClass = _filteredClasses.isNotEmpty
                        ? _filteredClasses.first
                        : null;
                    _selectedClassId = firstClass?.id;
                    _clearSession();
                  });
                  _writeSnapshot();
                },
              ),
            ),
            SizedBox(
              width: fieldWidth,
              child: DropdownButtonFormField<int>(
                value: classes.any((entry) => entry.id == _selectedClassId)
                    ? _selectedClassId
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Class',
                  border: OutlineInputBorder(),
                ),
                items: classes
                    .map(
                      (schoolClass) => DropdownMenuItem<int>(
                        value: schoolClass.id,
                        child: Text(schoolClass.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedClassId = value;
                    _clearSession();
                  });
                  _writeSnapshot();
                },
              ),
            ),
            SizedBox(
              width: fieldWidth,
              child: InkWell(
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
            ),
            SizedBox(
              width: fieldWidth,
              child: DropdownButtonFormField<int>(
                value:
                    periods.any((entry) => entry.value == _selectedPeriodNumber)
                        ? _selectedPeriodNumber
                        : null,
                decoration: const InputDecoration(
                  labelText: 'Period',
                  border: OutlineInputBorder(),
                ),
                items: periods
                    .map(
                      (period) => DropdownMenuItem<int>(
                        value: period.value,
                        child: Text(period.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPeriodNumber = value;
                    _clearSession();
                  });
                  _writeSnapshot();
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSessionSummary(ThemeData theme) {
    final session = _session!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF115E59), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            session.subject?.name.isNotEmpty == true
                ? session.subject!.name
                : 'Assigned subject',
            style:
                theme.textTheme.headlineMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 14),
          Text(
            session.teacher?.name.isNotEmpty == true
                ? 'Teacher: ${session.teacher!.name}'
                : 'Teacher assignment available',
            style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 6),
          Text(
            '${session.schoolClass?.name ?? ''} - ${session.dayLabel} - Period ${session.periodNumber}',
            style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white70),
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
            '${session.students.length} students loaded',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          _buildStudentTable(theme, session.students),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _saveAttendance,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _hasPendingDraft
                          ? 'Sync Subject Attendance'
                          : 'Save Subject Attendance',
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentTable(
    ThemeData theme,
    List<SubjectAttendanceStudent> students,
  ) {
    return Table(
      columnWidths: const {
        0: FixedColumnWidth(55),
        1: FlexColumnWidth(3),
        2: FlexColumnWidth(2),
        3: FlexColumnWidth(3),
      },
      border: TableBorder.all(color: const Color(0xFFE2E8F0)),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
          children: [
            _tableHeaderCell('No.'),
            _tableHeaderCell('Student Name'),
            _tableHeaderCell('Status'),
            _tableHeaderCell('Remarks'),
          ],
        ),
        ...students.asMap().entries.map(
              (entry) => _buildStudentRow(
                entry.key + 1,
                entry.value,
              ),
            ),
      ],
    );
  }

  TableRow _buildStudentRow(int index, SubjectAttendanceStudent student) {
    final draft = _drafts[student.id] ??
        _AttendanceDraft(status: student.status, remarks: student.remarks);

    return TableRow(
      children: [
        _tableCell(Text('$index')),
        _tableCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(student.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                student.rollNumber == null
                    ? 'No roll number'
                    : 'Roll No: ${student.rollNumber}',
                style: const TextStyle(color: Color(0xFF52606D), fontSize: 12),
              ),
            ],
          ),
        ),
        _tableCell(
          DropdownButtonFormField<String>(
            value: _statusOptions.contains(draft.status)
                ? draft.status
                : 'present',
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
        ),
        _tableCell(
          TextFormField(
            key: ValueKey('remarks-${student.id}'),
            initialValue: draft.remarks,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onChanged: (value) {
              _updateDraftRemarks(student, value);
            },
          ),
        ),
      ],
    );
  }

  Widget _tableHeaderCell(String label) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _tableCell(Widget child) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: child,
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

const _subjectAttendanceCacheKey = 'subject_attendance_snapshot';
