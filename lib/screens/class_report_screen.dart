import 'package:flutter/material.dart';

import '../models/exam_models.dart';
import '../models/fee_models.dart';
import '../models/main_attendance_models.dart';
import '../models/school_reports_models.dart';
import '../services/laravel_api.dart';

class ClassReportScreen extends StatefulWidget {
  const ClassReportScreen({
    super.key,
    required this.api,
    required this.token,
  });

  final LaravelApi api;
  final String token;

  @override
  State<ClassReportScreen> createState() => _ClassReportScreenState();
}

class _ClassReportScreenState extends State<ClassReportScreen> {
  List<AcademicYearOption> _years = const [];
  List<MainAttendanceLevel> _levels = const [];
  List<MainAttendanceClass> _classes = const [];
  List<ExamTermOption> _terms = const [];
  ClassReportResponse? _report;
  int? _selectedYearId;
  int? _selectedLevelId;
  int? _selectedClassId;
  int? _selectedTermId;
  bool _loadingSetup = true;
  bool _loadingReport = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSetup();
  }

  List<MainAttendanceClass> get _filteredClasses {
    if (_selectedLevelId == null) {
      return _classes;
    }

    return _classes.where((item) => item.levelId == _selectedLevelId).toList();
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
      final firstClass = classes.isNotEmpty ? classes.first : null;

      if (!mounted) {
        return;
      }

      setState(() {
        _years = years;
        _levels = levels;
        _classes = classes;
        _selectedYearId = activeYear.id;
        _selectedLevelId = firstClass?.levelId;
        _selectedClassId = firstClass?.id;
        _loadingSetup = false;
      });

      await _loadTerms();
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
        _error = 'Unable to load class report setup.';
      });
    }
  }

  Future<void> _loadTerms() async {
    final yearId = _selectedYearId;
    if (yearId == null) {
      return;
    }

    try {
      final terms = await widget.api.terms(
        token: widget.token,
        academicYearId: yearId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _terms = terms;
        _selectedTermId = null;
      });
    } catch (_) {}
  }

  Future<void> _loadReport() async {
    final yearId = _selectedYearId;
    final classId = _selectedClassId;
    if (yearId == null || classId == null) {
      return;
    }

    setState(() {
      _loadingReport = true;
      _error = null;
    });

    try {
      final report = await widget.api.classReport(
        token: widget.token,
        academicYearId: yearId,
        classId: classId,
        termId: _selectedTermId,
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
        _error = 'Unable to load class report.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final report = _report;

    return Scaffold(
      appBar: AppBar(title: const Text('Class Report')),
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
                        Text('Report Filters', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 16),
                        _DropdownField<int>(
                          label: 'Academic Year',
                          value: _selectedYearId,
                          items: _years
                              .map((item) => DropdownMenuItem<int>(
                                    value: item.id,
                                    child: Text(item.name),
                                  ))
                              .toList(),
                          onChanged: (value) async {
                            setState(() {
                              _selectedYearId = value;
                              _report = null;
                            });
                            await _loadTerms();
                          },
                        ),
                        const SizedBox(height: 12),
                        _DropdownField<int>(
                          label: 'Level',
                          value: _selectedLevelId,
                          items: _levels
                              .map((item) => DropdownMenuItem<int>(
                                    value: item.id,
                                    child: Text(item.name),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            final classes = _classes
                                .where((item) => item.levelId == value)
                                .toList();
                            setState(() {
                              _selectedLevelId = value;
                              _selectedClassId =
                                  classes.isNotEmpty ? classes.first.id : null;
                              _report = null;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        _DropdownField<int>(
                          label: 'Class',
                          value: _selectedClassId,
                          items: _filteredClasses
                              .map((item) => DropdownMenuItem<int>(
                                    value: item.id,
                                    child: Text(item.name),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedClassId = value;
                              _report = null;
                            });
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
                            ..._terms.map((item) => DropdownMenuItem<int?>(
                                  value: item.id,
                                  child: Text(item.name),
                                )),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedTermId = value;
                              _report = null;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _loadingReport ? null : _loadReport,
                          icon: const Icon(Icons.bar_chart_outlined),
                          label: Text(
                            _loadingReport ? 'Loading...' : 'Load Class Report',
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
            if (report != null)
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
                      '${report.className} · ${report.term}',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${report.count} students ranked',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    ...report.students.map(
                      (student) => Padding(
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
                                '#${student.rank} ${student.studentName}',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                student.rollNumber == null
                                    ? 'No roll number'
                                    : 'Roll No: ${student.rollNumber}',
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: report.subjects
                                    .map(
                                      (subject) => Chip(
                                        label: Text(
                                          '${subject.name}: ${_formatMark(student.subjects[subject.id] ?? 0)}',
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Total: ${_formatMark(student.total)}',
                                style: theme.textTheme.titleSmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (!_loadingSetup && !_loadingReport)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Load a class report to view subject totals and rankings.',
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

String _formatMark(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }

  return value.toStringAsFixed(2);
}
