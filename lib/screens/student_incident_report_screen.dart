import 'package:flutter/material.dart';

import '../models/discipline_incident_models.dart';
import '../models/main_attendance_models.dart';
import '../models/student_list_models.dart';
import '../services/laravel_api.dart';

class StudentIncidentReportScreen extends StatefulWidget {
  const StudentIncidentReportScreen({
    super.key,
    required this.api,
    required this.token,
  });

  final LaravelApi api;
  final String token;

  @override
  State<StudentIncidentReportScreen> createState() =>
      _StudentIncidentReportScreenState();
}

class _StudentIncidentReportScreenState
    extends State<StudentIncidentReportScreen> {
  List<MainAttendanceClass> _classes = const [];
  List<StudentListItem> _students = const [];
  int? _selectedClassId;
  int? _selectedStudentId;
  StudentIncidentReport? _report;
  bool _loadingSetup = true;
  bool _loadingStudents = false;
  bool _loadingReport = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSetup();
  }

  Future<void> _loadSetup() async {
    setState(() {
      _loadingSetup = true;
      _error = null;
    });

    try {
      final classes = await widget.api.schoolClasses(
        token: widget.token,
        includeAll: true,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _classes = classes;
        _loadingSetup = false;
      });
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
        _error = 'Unable to load report filters.';
      });
    }
  }

  Future<void> _loadStudents() async {
    final classId = _selectedClassId;
    if (classId == null) {
      setState(() {
        _students = const [];
        _selectedStudentId = null;
      });
      return;
    }

    setState(() {
      _loadingStudents = true;
      _error = null;
      _students = const [];
      _selectedStudentId = null;
    });

    try {
      final students = <StudentListItem>[];
      var page = 1;
      var hasNext = true;

      while (hasNext) {
        final result = await widget.api.studentList(
          token: widget.token,
          page: page,
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
        _loadingStudents = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingStudents = false;
        _error = 'Unable to load students for this class.';
      });
    }
  }

  Future<void> _loadReport() async {
    final classId = _selectedClassId;
    final studentId = _selectedStudentId;

    if (classId == null || studentId == null) {
      _showMessage('Select a class and student first.');
      return;
    }

    setState(() {
      _loadingReport = true;
      _error = null;
    });

    try {
      final report = await widget.api.studentDisciplineIncidentReport(
        token: widget.token,
        classId: classId,
        studentId: studentId,
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
        _error = 'Unable to load incident report.';
      });
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loadingSetup) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Incident Report'),
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
                  onChanged: (value) {
                    setState(() {
                      _selectedClassId = value;
                      _report = null;
                    });
                    _loadStudents();
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  value: _selectedStudentId,
                  decoration: const InputDecoration(
                    labelText: 'Student',
                    border: OutlineInputBorder(),
                  ),
                  items: _students
                      .map(
                        (student) => DropdownMenuItem(
                          value: student.id,
                          child: Text(student.name),
                        ),
                      )
                      .toList(),
                  onChanged: _loadingStudents
                      ? null
                      : (value) {
                          setState(() {
                            _selectedStudentId = value;
                            _report = null;
                          });
                        },
                ),
                const SizedBox(height: 16),
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
                    _report!.student.name,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Roll: ${_report!.student.rollNumber ?? '-'}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    'Level: ${_report!.student.levelName ?? '-'}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    'Class: ${_report!.student.className ?? '-'}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Total incidents: ${_report!.incidents.length}',
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ..._report!.incidents.map(_buildIncidentCard),
          ],
        ],
      ),
    );
  }

  Widget _buildIncidentCard(DisciplineIncidentItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.whatHappened,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2933),
              ),
            ),
            const SizedBox(height: 8),
            Text('Reported by: ${item.reportedBy ?? '-'}'),
            Text('When: ${item.happenedAt ?? item.createdAt ?? '-'}'),
            if (item.actionTaken != null && item.actionTaken!.isNotEmpty)
              Text('Action: ${item.actionTaken}'),
          ],
        ),
      ),
    );
  }
}
