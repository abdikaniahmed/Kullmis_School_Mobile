import 'package:flutter/material.dart';

import '../models/main_attendance_models.dart';
import '../models/student_management_models.dart';
import '../services/laravel_api.dart';

class WeeklyIncidentReportScreen extends StatefulWidget {
  const WeeklyIncidentReportScreen({
    super.key,
    required this.api,
    required this.token,
  });

  final LaravelApi api;
  final String token;

  @override
  State<WeeklyIncidentReportScreen> createState() =>
      _WeeklyIncidentReportScreenState();
}

class _WeeklyIncidentReportScreenState
    extends State<WeeklyIncidentReportScreen> {
  List<MainAttendanceLevel> _levels = const [];
  List<MainAttendanceClass> _classes = const [];
  int? _selectedLevelId;
  int? _selectedClassId;
  WeeklyIncidentReport? _report;
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
        widget.api.attendanceLevels(widget.token),
        widget.api.schoolClasses(token: widget.token, includeAll: true),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _levels = results[0] as List<MainAttendanceLevel>;
        _classes = results[1] as List<MainAttendanceClass>;
        _loading = false;
      });

      await _loadReport();
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
        _error = 'Unable to load weekly incident report setup.';
      });
    }
  }

  List<MainAttendanceClass> get _filteredClasses {
    if (_selectedLevelId == null) {
      return _classes;
    }

    return _classes
        .where((entry) => entry.levelId == _selectedLevelId)
        .toList();
  }

  Future<void> _loadReport() async {
    setState(() {
      _loadingReport = true;
      _error = null;
    });

    try {
      final report = await widget.api.weeklyIncidentReport(
        token: widget.token,
        levelId: _selectedLevelId,
        classId: _selectedClassId,
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
        _error = 'Unable to load weekly incident report.';
      });
    }
  }

  void _resetFilters() {
    setState(() {
      _selectedLevelId = null;
      _selectedClassId = null;
      _report = null;
    });

    _loadReport();
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
      appBar: AppBar(title: const Text('Weekly Incident Report')),
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
                  value: _selectedLevelId,
                  decoration: const InputDecoration(
                    labelText: 'Level',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int>(
                      value: null,
                      child: Text('All Levels'),
                    ),
                    ..._levels.map(
                      (level) => DropdownMenuItem<int>(
                        value: level.id,
                        child: Text(level.name),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedLevelId = value;
                      _selectedClassId = null;
                    });
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  value: _selectedClassId,
                  decoration: const InputDecoration(
                    labelText: 'Class',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int>(
                      value: null,
                      child: Text('All Classes'),
                    ),
                    ..._filteredClasses.map(
                      (schoolClass) => DropdownMenuItem<int>(
                        value: schoolClass.id,
                        child: Text(schoolClass.name),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedClassId = value;
                    });
                  },
                ),
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
                  Text('Weekly Summary', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    'Period: ${_report!.periodStart ?? '-'} to ${_report!.periodEnd ?? '-'}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total incidents: ${_report!.summary.totalIncidents}',
                    style: theme.textTheme.bodyLarge,
                  ),
                  Text(
                    'Students affected: ${_report!.summary.totalStudents}',
                    style: theme.textTheme.bodyLarge,
                  ),
                  Text(
                    'Repeated students: ${_report!.summary.repeatedStudentsCount}',
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildRepeatedSection(theme),
            const SizedBox(height: 12),
            _buildIncidentSection(theme),
          ],
        ],
      ),
    );
  }

  Widget _buildRepeatedSection(ThemeData theme) {
    final report = _report;
    if (report == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Repeated Students', style: theme.textTheme.titleLarge),
          const SizedBox(height: 10),
          if (report.repeatedStudents.isEmpty)
            Text('No repeated students found.',
                style: theme.textTheme.bodyMedium)
          else
            ...report.repeatedStudents.map(
              (student) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        student.studentName ?? '—',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                    Text('${student.incidentCount}x'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIncidentSection(ThemeData theme) {
    final report = _report;
    if (report == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Incident Details', style: theme.textTheme.titleLarge),
          const SizedBox(height: 10),
          if (report.incidents.isEmpty)
            Text('No incidents recorded.', style: theme.textTheme.bodyMedium)
          else
            ...report.incidents.map(
              (incident) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        incident.studentName ?? '—',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2933),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('Repeat count: ${incident.repeatCount}x'),
                      const SizedBox(height: 6),
                      Text(incident.whatHappened ?? '—'),
                      const SizedBox(height: 6),
                      Text('Reported by: ${incident.reportedBy ?? '—'}'),
                      if (incident.actionTaken != null &&
                          incident.actionTaken!.isNotEmpty)
                        Text('Action: ${incident.actionTaken}'),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
