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
    this.cacheStore = const FileOfflineCacheStore(),
  });

  final LaravelApi api;
  final String token;
  final OfflineCacheStore cacheStore;

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

  OfflineCacheStore get _cacheStore => widget.cacheStore;
  late final OfflineSyncQueue _syncQueue =
      OfflineSyncQueue(cacheStore: _cacheStore);

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
  String _sortBy = 'roll';
  static const _teal = Color(0xFF0F766E);

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
        fallbackMessage:
            'Offline mode: showing last synced subject attendance.',
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
        fallbackMessage:
            'Offline mode: showing last synced subject attendance.',
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
        fallbackMessage:
            'Offline mode: showing last synced subject attendance.',
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
        fallbackMessage:
            'Offline mode: showing last synced subject attendance.',
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

    final records = session.students.map((student) {
      final draft = _drafts[student.id] ??
          const _AttendanceDraft(status: 'present', remarks: '');

      return SubjectAttendanceRecordDraft(
        studentId: student.studentId,
        status: draft.status,
        remarks: draft.remarks.trim(),
      );
    }).toList();

    try {
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
    final json =
        await _cacheStore.readCacheDocument(_subjectAttendanceCacheKey);
    if (json == null) {
      return false;
    }

    final snapshot = SubjectAttendanceOfflineSnapshot.fromJson(json);
    final pendingDraft = json['pending_draft'] == true;
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
      _usingOfflineData =
          snapshot.session != null || snapshot.drafts.isNotEmpty;
      _hasPendingDraft = pendingDraft;
      _statusMessage = pendingDraft
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
      backgroundColor: const Color(0xFFF7F6F0),
      bottomNavigationBar: _session == null ? null : _buildSaveBar(),
      appBar: AppBar(
        title: const Text('Subject Attendance',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFFEAF5F3),
      ),
      body: _loadingFilters
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadFilters,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(
                          Icons.calendar_month_outlined,
                          'Load Subject Session',
                          'Choose your class, date, and period to take subject attendance.',
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
                              width: double.infinity,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                    backgroundColor: _teal,
                                    minimumSize: const Size(0, 48),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14))),
                                icon: const Icon(Icons.search),
                                onPressed:
                                    _loadingSession ? null : _loadSession,
                                label: _loadingSession
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
                                onPressed:
                                    _loadingSession ? null : _loadSession,
                                icon: const Icon(Icons.cloud_sync_outlined),
                                label: const Text('Retry Online'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_session != null) ...[
                    const SizedBox(height: 12),
                    _buildSessionSummary(theme),
                    const SizedBox(height: 12),
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
        final columns = constraints.maxWidth >= 680
            ? 4
            : constraints.maxWidth >= 320 &&
                    MediaQuery.textScalerOf(context).scale(14) <= 18
                ? 2
                : 1;
        final fieldWidth =
            (constraints.maxWidth - (columns - 1) * 10) / columns;

        return Wrap(
          spacing: 10,
          runSpacing: 16,
          children: [
            SizedBox(
              width: fieldWidth,
              child: DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: _selectedLevelId,
                decoration: _fieldDecoration('Level', Icons.school_outlined),
                items: (filters?.levels ?? const <AttendanceLevel>[])
                    .map(
                      (level) => DropdownMenuItem<int>(
                        value: level.id,
                        child:
                            Text(level.name, overflow: TextOverflow.ellipsis),
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
                isExpanded: true,
                initialValue:
                    classes.any((entry) => entry.id == _selectedClassId)
                        ? _selectedClassId
                        : null,
                decoration: _fieldDecoration('Class', Icons.groups_outlined),
                items: classes
                    .map(
                      (schoolClass) => DropdownMenuItem<int>(
                        value: schoolClass.id,
                        child: Text(schoolClass.name,
                            overflow: TextOverflow.ellipsis),
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
                  decoration:
                      _fieldDecoration('Date', Icons.calendar_month_outlined),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text(_formatDate(_selectedDate),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              width: fieldWidth,
              child: DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue:
                    periods.any((entry) => entry.value == _selectedPeriodNumber)
                        ? _selectedPeriodNumber
                        : null,
                decoration: _fieldDecoration('Period', Icons.schedule),
                items: periods
                    .map(
                      (period) => DropdownMenuItem<int>(
                        value: period.value,
                        child:
                            Text(period.label, overflow: TextOverflow.ellipsis),
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

  InputDecoration _fieldDecoration(String label, IconData icon) =>
      InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 36, minHeight: 40),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE0E3E7))),
      );

  Color _statusColor(String status) => switch (status) {
        'absent' => const Color(0xFFD92D50),
        'late' => const Color(0xFFEA850C),
        'excused' => const Color(0xFF7F56D9),
        _ => _teal,
      };

  Widget _buildSessionSummary(ThemeData theme) {
    final session = _session!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF115E59), _teal]),
          borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        const CircleAvatar(
            radius: 25,
            backgroundColor: Color(0xFFDBF7EF),
            child: Icon(Icons.menu_book_outlined, color: _teal, size: 28)),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              session.subject?.name.isNotEmpty == true
                  ? session.subject!.name
                  : 'Assigned subject',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
              session.teacher?.name.isNotEmpty == true
                  ? 'Teacher: ${session.teacher!.name}'
                  : 'Teacher assignment available',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 5),
          Text(
              '${session.schoolClass?.name ?? ''}  ·  ${session.dayLabel}  ·  Period ${session.periodNumber}',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          Text('${session.students.length} students',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ])),
      ]),
    );
  }

  Widget _buildStudentList(ThemeData theme) {
    final students = [..._session!.students];
    students.sort((a, b) {
      if (_sortBy == 'name') {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      final roll = (a.rollNumber ?? '').compareTo(b.rollNumber ?? '');
      return roll == 0 ? a.name.compareTo(b.name) : roll;
    });
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle(Icons.groups_outlined, 'Students (${students.length})',
            'Mark attendance and add optional remarks.'),
        Align(
            alignment: Alignment.centerRight,
            child: DropdownButton<String>(
              value: _sortBy,
              underline: const SizedBox.shrink(),
              icon: const Icon(Icons.expand_more, size: 18),
              items: const [
                DropdownMenuItem(value: 'roll', child: Text('By Roll No.')),
                DropdownMenuItem(value: 'name', child: Text('By Name'))
              ],
              onChanged: (value) {
                if (value != null) setState(() => _sortBy = value);
              },
            )),
        if (students.isEmpty)
          const Padding(
              padding: EdgeInsets.all(20),
              child: Text('No students in this session.')),
        ...students
            .asMap()
            .entries
            .map((entry) => _buildStudentRow(entry.key + 1, entry.value)),
      ]),
    );
  }

  Widget _sectionTitle(IconData icon, String title, String subtitle) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: const Color(0xFFDCF8F2),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: _teal, size: 23)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF101828))),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF667085))),
              ])),
        ],
      );

  Widget _buildStudentRow(int index, SubjectAttendanceStudent student) {
    final draft = _drafts[student.id] ??
        _AttendanceDraft(status: student.status, remarks: student.remarks);
    final initials = student.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join()
        .toUpperCase();
    const colors = [
      Color(0xFFE2F1FF),
      Color(0xFFFFE5EB),
      Color(0xFFFFF4D6),
      Color(0xFFF0E4FF)
    ];
    return Container(
      key: ValueKey('student-${student.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEEF0F2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('$index',
              style: const TextStyle(color: Color(0xFF667085), fontSize: 12)),
          const SizedBox(width: 8),
          CircleAvatar(
              radius: 22,
              backgroundColor: colors[(index - 1) % colors.length],
              child: Text(initials,
                  style: const TextStyle(
                      color: _teal,
                      fontWeight: FontWeight.w700,
                      fontSize: 14))),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(student.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF101828),
                        fontSize: 14)),
                const SizedBox(height: 3),
                Text(
                    student.rollNumber == null
                        ? 'No roll number'
                        : 'Roll No: ${student.rollNumber}',
                    style: const TextStyle(
                        color: Color(0xFF667085), fontSize: 12)),
              ])),
        ]),
        const SizedBox(height: 10),
        Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _statusOptions.map((status) {
              final selected = draft.status == status;
              final color = _statusColor(status);
              return ChoiceChip(
                key: ValueKey('status-${student.id}-$status'),
                label: Text(_titleCase(status)),
                selected: selected,
                showCheckmark: false,
                avatar: Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 16,
                    color: selected ? color : const Color(0xFF667085)),
                labelStyle: TextStyle(
                    fontSize: 11,
                    color: selected ? color : const Color(0xFF667085),
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400),
                padding: const EdgeInsets.symmetric(horizontal: 3),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.padded,
                backgroundColor: const Color(0xFFF6F7F9),
                selectedColor: color.withValues(alpha: .10),
                side: BorderSide(
                    color: selected ? color : const Color(0xFFE3E5E8)),
                shape: const StadiumBorder(),
                onSelected:
                    _saving ? null : (_) => _updateDraftStatus(student, status),
              );
            }).toList()),
        const SizedBox(height: 8),
        TextFormField(
          key: ValueKey('remarks-${student.id}'),
          initialValue: draft.remarks,
          enabled: !_saving,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Add remarks (optional)...',
            hintStyle: const TextStyle(color: Color(0xFF667085), fontSize: 12),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: Color(0xFFD8DCE1))),
          ),
          onChanged: (value) => _updateDraftRemarks(student, value),
        ),
      ]),
    );
  }

  Widget _buildSaveBar() {
    final counts = {for (final status in _statusOptions) status: 0};
    for (final student in _session!.students) {
      final status = _drafts[student.id]?.status ?? student.status;
      counts[status] = (counts[status] ?? 0) + 1;
    }
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          boxShadow: [
            BoxShadow(
                color: Color(0x14000000), blurRadius: 14, offset: Offset(0, -3))
          ]),
      child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: LayoutBuilder(builder: (context, constraints) {
              final totals = Row(
                  children: _statusOptions
                      .map((status) => Expanded(
                            child: Semantics(
                              label: '${_titleCase(status)}: ${counts[status]}',
                              excludeSemantics: true,
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: _statusColor(status)
                                                .withValues(alpha: .10),
                                            border: Border.all(
                                                color: _statusColor(status)
                                                    .withValues(alpha: .4))),
                                        child: Text('${counts[status]}',
                                            style: TextStyle(
                                                color: _statusColor(status),
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13))),
                                    const SizedBox(height: 4),
                                    Text(_titleCase(status),
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFF667085))),
                                  ]),
                            ),
                          ))
                      .toList());
              final save = FilledButton.icon(
                key: const ValueKey('save-attendance'),
                onPressed:
                    _saving || _loadingSession || _session!.students.isEmpty
                        ? null
                        : _saveAttendance,
                style: FilledButton.styleFrom(
                    backgroundColor: _teal,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15))),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined),
                label: Text(_saving
                    ? 'Saving...'
                    : _usingOfflineData && _hasPendingDraft
                        ? 'Sync Attendance'
                        : 'Save Attendance'),
              );
              if (constraints.maxWidth >= 560 &&
                  MediaQuery.textScalerOf(context).scale(14) <= 18) {
                return Row(children: [
                  Expanded(child: totals),
                  const SizedBox(width: 20),
                  save
                ]);
              }
              return Column(mainAxisSize: MainAxisSize.min, children: [
                totals,
                const SizedBox(height: 10),
                SizedBox(width: double.infinity, child: save)
              ]);
            }),
          )),
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
