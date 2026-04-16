import 'package:flutter/material.dart';

import '../models/exam_models.dart';
import '../models/fee_models.dart';
import '../models/main_attendance_models.dart';
import '../models/student_list_models.dart';
import '../services/laravel_api.dart';

class ExamReportScreen extends StatefulWidget {
  const ExamReportScreen({
    super.key,
    required this.api,
    required this.token,
  });

  final LaravelApi api;
  final String token;

  @override
  State<ExamReportScreen> createState() => _ExamReportScreenState();
}

class _ExamReportScreenState extends State<ExamReportScreen> {
  List<AcademicYearOption> _years = const [];
  List<MainAttendanceLevel> _levels = const [];
  List<MainAttendanceClass> _classes = const [];
  List<ExamTermOption> _terms = const [];
  List<ExamOption> _exams = const [];
  List<StudentListItem> _students = const [];

  int? _selectedYearId;
  int? _selectedLevelId;
  int? _selectedClassId;
  int? _selectedTermId;
  int? _selectedExamId;
  int? _selectedStudentId;
  bool _loadingSetup = true;
  bool _loadingStudents = false;
  bool _loadingReport = false;
  String? _error;
  ExamReportCard? _report;

  @override
  void initState() {
    super.initState();
    _loadSetup();
  }

  List<MainAttendanceClass> get _filteredClasses {
    if (_selectedLevelId == null) {
      return _classes;
    }

    return _classes
        .where((entry) => entry.levelId == _selectedLevelId)
        .toList();
  }

  Future<void> _loadSetup() async {
    setState(() {
      _loadingSetup = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        widget.api.academicYears(widget.token),
        widget.api.activeAcademicYear(widget.token),
        widget.api.attendanceLevels(widget.token),
        widget.api.schoolClasses(token: widget.token, includeAll: true),
      ]);

      final years = results[0] as List<AcademicYearOption>;
      final activeYear = results[1] as ActiveAcademicYear;
      final levels = results[2] as List<MainAttendanceLevel>;
      final classes = results[3] as List<MainAttendanceClass>;

      final selectedYearId = years.any((entry) => entry.id == activeYear.id)
          ? activeYear.id
          : (years.isNotEmpty ? years.first.id : null);
      final firstClass = classes.isNotEmpty ? classes.first : null;

      if (!mounted) {
        return;
      }

      setState(() {
        _years = years;
        _levels = levels;
        _classes = classes;
        _selectedYearId = selectedYearId;
        _selectedLevelId = firstClass?.levelId;
        _selectedClassId = firstClass?.id;
        _loadingSetup = false;
      });

      await _loadTermsAndExams();
      await _loadStudents();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingSetup = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingSetup = false;
        _error = 'Unable to load exam report setup.';
      });
    }
  }

  Future<void> _loadTermsAndExams() async {
    final yearId = _selectedYearId;
    if (yearId == null) {
      return;
    }

    try {
      final terms = await widget.api.terms(
        token: widget.token,
        academicYearId: yearId,
      );
      final exams = await widget.api.exams(
        token: widget.token,
        academicYearId: yearId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _terms = terms;
        _exams = exams;
        _selectedTermId = null;
        _selectedExamId = null;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.message;
      });
    }
  }

  Future<void> _loadStudents() async {
    final classId = _selectedClassId;
    if (classId == null) {
      return;
    }

    setState(() {
      _loadingStudents = true;
      _selectedStudentId = null;
      _report = null;
      _error = null;
    });

    try {
      final students = <StudentListItem>[];
      var page = 1;
      var hasNext = true;

      while (hasNext) {
        final result = await widget.api.studentList(
          token: widget.token,
          page: page,
          levelId: _selectedLevelId,
          classId: classId,
        );
        students.addAll(result.items);
        hasNext = result.hasNextPage;
        page += 1;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _students = students;
        _selectedStudentId = students.isNotEmpty ? students.first.id : null;
        _loadingStudents = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _students = const [];
        _loadingStudents = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _students = const [];
        _loadingStudents = false;
        _error = 'Unable to load students for the selected class.';
      });
    }
  }

  Future<void> _loadReport() async {
    final yearId = _selectedYearId;
    final studentId = _selectedStudentId;

    if (yearId == null || studentId == null) {
      _showMessage('Select an academic year and student first.');
      return;
    }

    setState(() {
      _loadingReport = true;
      _error = null;
    });

    try {
      final report = await widget.api.studentReportCard(
        token: widget.token,
        studentId: studentId,
        academicYearId: yearId,
        termId: _selectedTermId,
        examId: _selectedExamId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _report = report;
        _loadingReport = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _report = null;
        _loadingReport = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _report = null;
        _loadingReport = false;
        _error = 'Unable to load the exam report.';
      });
    }
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
        title: const Text('Exam Report'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadSetup,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: _loadingSetup
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Report Filters',
                            style: theme.textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text(
                          'Choose a student and optionally narrow the report to one term or one exam.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        _DropdownField<int>(
                          label: 'Academic Year',
                          value: _selectedYearId,
                          items: _years
                              .map(
                                (entry) => DropdownMenuItem<int>(
                                  value: entry.id,
                                  child: Text(entry.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) async {
                            setState(() {
                              _selectedYearId = value;
                              _selectedTermId = null;
                              _selectedExamId = null;
                              _report = null;
                            });
                            await _loadTermsAndExams();
                          },
                        ),
                        const SizedBox(height: 12),
                        _DropdownField<int>(
                          label: 'Level',
                          value: _selectedLevelId,
                          items: _levels
                              .map(
                                (entry) => DropdownMenuItem<int>(
                                  value: entry.id,
                                  child: Text(entry.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) async {
                            final classes = _classes
                                .where((entry) => entry.levelId == value)
                                .toList();
                            setState(() {
                              _selectedLevelId = value;
                              _selectedClassId =
                                  classes.isNotEmpty ? classes.first.id : null;
                              _students = const [];
                              _selectedStudentId = null;
                              _report = null;
                            });
                            await _loadStudents();
                          },
                        ),
                        const SizedBox(height: 12),
                        _DropdownField<int>(
                          label: 'Class',
                          value: _selectedClassId,
                          items: _filteredClasses
                              .map(
                                (entry) => DropdownMenuItem<int>(
                                  value: entry.id,
                                  child: Text(entry.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) async {
                            setState(() {
                              _selectedClassId = value;
                              _students = const [];
                              _selectedStudentId = null;
                              _report = null;
                            });
                            await _loadStudents();
                          },
                        ),
                        const SizedBox(height: 12),
                        _DropdownField<int?>(
                          label: 'Term',
                          value: _selectedTermId,
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('All Terms'),
                            ),
                            ..._terms.map(
                              (entry) => DropdownMenuItem<int?>(
                                value: entry.id,
                                child: Text(entry.name),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedTermId = value;
                              _selectedExamId = null;
                              _report = null;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        _DropdownField<int?>(
                          label: 'Exam',
                          value: _selectedExamId,
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('All Exams'),
                            ),
                            ..._exams
                                .where(
                                  (entry) =>
                                      _selectedTermId == null ||
                                      entry.termId == _selectedTermId,
                                )
                                .map(
                                  (entry) => DropdownMenuItem<int?>(
                                    value: entry.id,
                                    child: Text(entry.name),
                                  ),
                                ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedExamId = value;
                              _report = null;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        _DropdownField<int>(
                          label: _loadingStudents
                              ? 'Student (loading...)'
                              : 'Student',
                          value: _selectedStudentId,
                          items: _students
                              .map(
                                (entry) => DropdownMenuItem<int>(
                                  value: entry.id,
                                  child: Text(entry.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedStudentId = value;
                              _report = null;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _loadingReport ? null : _loadReport,
                          icon: const Icon(Icons.assessment_outlined),
                          label: Text(
                              _loadingReport ? 'Loading…' : 'Load Exam Report'),
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
            if (_report != null) ...[
              _ReportHero(report: _report!),
              const SizedBox(height: 16),
              _ReportSummary(report: _report!),
              const SizedBox(height: 16),
              ..._report!.subjects.map(
                (subject) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SubjectReportCard(
                    subject: subject,
                    exams: _report!.exams,
                  ),
                ),
              ),
            ] else if (!_loadingSetup && !_loadingReport)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Load a student report to see exam totals, averages, and grades.',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: items.any((entry) => entry.value == value) ? value : null,
      decoration: InputDecoration(labelText: label),
      items: items,
      onChanged: items.isEmpty ? null : onChanged,
    );
  }
}

class _ReportHero extends StatelessWidget {
  const _ReportHero({required this.report});

  final ExamReportCard report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F766E),
            Color(0xFF155E75),
            Color(0xFFB45309),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            report.student.name,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${report.academicYear} · ${report.termName} · ${report.examName}',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                label: Text('Class: ${report.student.className}'),
                backgroundColor: Colors.white.withOpacity(0.16),
                labelStyle: const TextStyle(color: Colors.white),
              ),
              Chip(
                label: Text('Level: ${report.student.levelName}'),
                backgroundColor: Colors.white.withOpacity(0.16),
                labelStyle: const TextStyle(color: Colors.white),
              ),
              Chip(
                label: Text('Roll: ${report.student.rollNumber}'),
                backgroundColor: Colors.white.withOpacity(0.16),
                labelStyle: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportSummary extends StatelessWidget {
  const _ReportSummary({required this.report});

  final ExamReportCard report;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _MetricTile(
              label: 'Total', value: _formatMetric(report.summary.total)),
          _MetricTile(
            label: 'Average',
            value: _formatMetric(report.summary.average),
          ),
          _MetricTile(
            label: 'Percentage',
            value: '${_formatMetric(report.summary.percentage)}%',
          ),
          _MetricTile(label: 'Grade', value: report.summary.grade),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 148,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 6),
          Text(value, style: theme.textTheme.titleLarge),
        ],
      ),
    );
  }
}

class _SubjectReportCard extends StatelessWidget {
  const _SubjectReportCard({
    required this.subject,
    required this.exams,
  });

  final ExamReportSubject subject;
  final List<ExamReportHeader> exams;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(subject.subject, style: theme.textTheme.titleLarge),
              ),
              Text('Total: ${_formatMetric(subject.total)}'),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: exams
                .map(
                  (exam) => Chip(
                    label: Text(
                      '${exam.name}: ${_formatExamMark(subject.examsMap[exam.id])}',
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

String _formatMetric(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }

  return value.toStringAsFixed(2);
}

String _formatExamMark(double? value) {
  if (value == null) {
    return '—';
  }

  return _formatMetric(value);
}
