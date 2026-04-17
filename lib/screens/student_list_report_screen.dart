import 'package:flutter/material.dart';

import '../models/fee_models.dart';
import '../models/main_attendance_models.dart';
import '../models/student_management_models.dart';
import '../services/laravel_api.dart';

class StudentListReportScreen extends StatefulWidget {
  const StudentListReportScreen({
    super.key,
    required this.api,
    required this.token,
  });

  final LaravelApi api;
  final String token;

  @override
  State<StudentListReportScreen> createState() =>
      _StudentListReportScreenState();
}

class _StudentListReportScreenState extends State<StudentListReportScreen> {
  List<AcademicYearOption> _years = const [];
  List<MainAttendanceLevel> _levels = const [];
  List<SchoolClassOption> _classes = const [];
  StudentListReport? _report;
  String _filter = 'all';
  int? _selectedYearId;
  int? _selectedLevelId;
  int? _selectedClassId;
  String? _selectedSection;
  bool _loading = true;
  bool _loadingReport = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSetup();
  }

  Future<void> _loadSetup() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        widget.api.academicYears(widget.token),
        widget.api.attendanceLevels(widget.token),
        widget.api.schoolClassesWithSection(
          token: widget.token,
          includeAll: true,
        ),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _years = results[0] as List<AcademicYearOption>;
        _levels = results[1] as List<MainAttendanceLevel>;
        _classes = results[2] as List<SchoolClassOption>;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = 'Unable to load student report filters.';
      });
    }
  }

  List<String> get _sections {
    final values = _classes
        .map((entry) => entry.section)
        .whereType<String>()
        .toSet()
        .toList();
    values.sort();
    return values;
  }

  Future<void> _loadReport() async {
    if (_filter == 'level' && _selectedLevelId == null) {
      setState(() {
        _error = 'Select a level first.';
      });
      return;
    }

    if (_filter == 'class' && _selectedClassId == null) {
      setState(() {
        _error = 'Select a class first.';
      });
      return;
    }

    if (_filter == 'section' && _selectedSection == null) {
      setState(() {
        _error = 'Select a section first.';
      });
      return;
    }

    if (_filter == 'graduates' && _selectedYearId == null) {
      setState(() {
        _error = 'Select a graduation year first.';
      });
      return;
    }

    setState(() {
      _loadingReport = true;
      _error = null;
    });

    try {
      final query = <String, String>{
        'filter': _filter,
      };

      if (_filter == 'level' && _selectedLevelId != null) {
        query['level_id'] = '${_selectedLevelId!}';
      }

      if (_filter == 'class' && _selectedClassId != null) {
        query['class_id'] = '${_selectedClassId!}';
      }

      if (_filter == 'section' && _selectedSection != null) {
        query['section'] = _selectedSection!;
      }

      if (_filter == 'graduates') {
        if (_selectedYearId != null) {
          query['academic_year_id'] = '${_selectedYearId!}';
        }
        if (_selectedClassId != null) {
          query['class_id'] = '${_selectedClassId!}';
        }
      }

      final report = await widget.api.studentListReport(
        token: widget.token,
        queryParameters: query,
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
        _loadingReport = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingReport = false;
        _error = 'Unable to load student list report.';
      });
    }
  }

  void _resetFilters() {
    setState(() {
      _filter = 'all';
      _selectedYearId = null;
      _selectedLevelId = null;
      _selectedClassId = null;
      _selectedSection = null;
      _report = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student List Report'),
      ),
      body: ListView(
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
                Text('Report Filters', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _filter,
                  decoration: const InputDecoration(
                    labelText: 'Filter',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Students')),
                    DropdownMenuItem(value: 'level', child: Text('By Level')),
                    DropdownMenuItem(value: 'class', child: Text('By Class')),
                    DropdownMenuItem(
                        value: 'section', child: Text('By Section')),
                    DropdownMenuItem(
                      value: 'graduates',
                      child: Text('Graduates List'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _filter = value ?? 'all';
                      _selectedYearId = null;
                      _selectedLevelId = null;
                      _selectedClassId = null;
                      _selectedSection = null;
                      _report = null;
                    });
                  },
                ),
                if (_filter == 'level') ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    value: _selectedLevelId,
                    decoration: const InputDecoration(
                      labelText: 'Level',
                      border: OutlineInputBorder(),
                    ),
                    items: _levels
                        .map(
                          (level) => DropdownMenuItem(
                            value: level.id,
                            child: Text(level.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() {
                      _selectedLevelId = value;
                    }),
                  ),
                ],
                if (_filter == 'class') ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    value: _selectedClassId,
                    decoration: const InputDecoration(
                      labelText: 'Class',
                      border: OutlineInputBorder(),
                    ),
                    items: _classes
                        .map(
                          (schoolClass) => DropdownMenuItem(
                            value: schoolClass.id,
                            child: Text(schoolClass.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() {
                      _selectedClassId = value;
                    }),
                  ),
                ],
                if (_filter == 'section') ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String?>(
                    value: _selectedSection,
                    decoration: const InputDecoration(
                      labelText: 'Section',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All Sections'),
                      ),
                      ..._sections.map(
                        (section) => DropdownMenuItem(
                          value: section,
                          child: Text(section),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() {
                      _selectedSection = value;
                    }),
                  ),
                ],
                if (_filter == 'graduates') ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    value: _selectedYearId,
                    decoration: const InputDecoration(
                      labelText: 'Graduation Year',
                      border: OutlineInputBorder(),
                    ),
                    items: _years
                        .map(
                          (year) => DropdownMenuItem(
                            value: year.id,
                            child: Text(year.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() {
                      _selectedYearId = value;
                    }),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    value: _selectedClassId,
                    decoration: const InputDecoration(
                      labelText: 'Class',
                      border: OutlineInputBorder(),
                    ),
                    items: _classes
                        .map(
                          (schoolClass) => DropdownMenuItem(
                            value: schoolClass.id,
                            child: Text(schoolClass.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() {
                      _selectedClassId = value;
                    }),
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton(
                      onPressed: _loadingReport ? null : _loadReport,
                      child: _loadingReport
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Generate Report'),
                    ),
                    OutlinedButton(
                      onPressed: _loadingReport ? null : _resetFilters,
                      child: const Text('Clear'),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
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
          if (_report != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _report!.filterLabel ?? 'Student List Report',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Generated: ${_report!.generatedAt ?? '-'}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Total students: ${_report!.count}',
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildReportTable(_report!),
          ],
        ],
      ),
    );
  }

  Widget _buildReportTable(StudentListReport report) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('No.')),
          DataColumn(label: Text('Roll')),
          DataColumn(label: Text('Name')),
          DataColumn(label: Text('Gender')),
          DataColumn(label: Text('Level')),
          DataColumn(label: Text('Class')),
          DataColumn(label: Text('Section')),
          DataColumn(label: Text('Phone')),
        ],
        rows: report.students
            .asMap()
            .entries
            .map(
              (entry) => DataRow(
                cells: [
                  DataCell(Text('${entry.key + 1}')),
                  DataCell(Text(entry.value.rollNumber ?? '—')),
                  DataCell(Text(entry.value.name)),
                  DataCell(Text(entry.value.gender ?? '—')),
                  DataCell(Text(entry.value.levelName ?? '—')),
                  DataCell(Text(entry.value.className ?? '—')),
                  DataCell(Text(entry.value.section ?? '—')),
                  DataCell(Text(entry.value.phone ?? '—')),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}
