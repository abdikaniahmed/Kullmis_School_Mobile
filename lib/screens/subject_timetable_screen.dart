import 'package:flutter/material.dart';

import '../models/main_attendance_models.dart';
import '../models/school_reports_models.dart';
import '../models/subject_attendance_models.dart';
import '../services/laravel_api.dart';

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
  SubjectAttendanceFilters? _filters;
  SubjectTimetableResponse? _timetable;
  SubjectTimetableAssignmentResponse? _assignments;
  final Map<int, int?> _selectedAssignments = {};
  int? _selectedClassId;
  int _selectedDay = 1;
  bool _loadingFilters = true;
  bool _loadingTimetable = false;
  bool _saving = false;
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
      _error = null;
    });

    try {
      final filters = await widget.api.subjectAttendanceFilters(widget.token);
      final firstClass = filters.classes.isNotEmpty ? filters.classes.first : null;

      if (!mounted) {
        return;
      }

      setState(() {
        _filters = filters;
        _selectedClassId = firstClass?.id;
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
      });
    } on ApiException catch (error) {
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
      await widget.api.saveSubjectTimetable(
        token: widget.token,
        academicYearId: _filters?.academicYearId,
        schoolClassId: classId,
        dayOfWeek: _selectedDay,
        entries: timetable.periods
            .map(
              (period) => SubjectTimetableSaveDraft(
                periodNumber: period.value,
                teacherSubjectAssignmentId: _selectedAssignments[period.value],
              ),
            )
            .toList(),
      );

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
      });

      await _loadTimetable();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = 'Unable to save subject timetable.';
      });
    }
  }

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
                        label: Text(_saving ? 'Saving...' : 'Save Timetable'),
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
