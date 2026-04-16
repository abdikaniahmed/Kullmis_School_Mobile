import 'package:flutter/material.dart';

import '../models/subject_attendance_models.dart';
import '../services/laravel_api.dart';

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
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingFilters = false;
        _error = error.message;
      });
    } catch (_) {
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
      });
    } on ApiException catch (error) {
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

      _showMessage('Subject attendance saved.');
      await _loadSession();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(error.message);
      setState(() {
        _saving = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage('Failed to save subject attendance.');
      setState(() {
        _saving = false;
      });
    }
  }

  void _clearSession() {
    _session = null;
    _drafts = const {};
    _error = null;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
                        const SizedBox(height: 18),
                        _buildFilterFields(),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
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
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _error!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFFB42318),
                            ),
                          ),
                        ],
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

    return Column(
      children: [
        DropdownButtonFormField<int>(
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
              final firstClass =
                  _filteredClasses.isNotEmpty ? _filteredClasses.first : null;
              _selectedClassId = firstClass?.id;
              _clearSession();
            });
          },
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<int>(
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
        DropdownButtonFormField<int>(
          value: periods.any((entry) => entry.value == _selectedPeriodNumber)
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
          },
        ),
      ],
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
            '${session.schoolClass?.name ?? ''} • ${session.dayLabel} • Period ${session.periodNumber}',
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
          ...session.students.map(_buildStudentTile),
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
                  : const Text('Save Subject Attendance'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentTile(SubjectAttendanceStudent student) {
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

                setState(() {
                  _drafts = {
                    ..._drafts,
                    student.id: draft.copyWith(status: value),
                  };
                });
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
                _drafts = {
                  ..._drafts,
                  student.id: draft.copyWith(remarks: value),
                };
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
