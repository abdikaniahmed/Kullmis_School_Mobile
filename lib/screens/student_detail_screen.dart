import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/discipline_incident_models.dart';
import '../models/student_list_models.dart';
import '../services/laravel_api.dart';
import 'student_incident_record_screen.dart';

class StudentDetailScreen extends StatefulWidget {
  const StudentDetailScreen({
    super.key,
    required this.api,
    required this.token,
    required this.session,
    required this.student,
  });

  final LaravelApi api;
  final String token;
  final AuthSession session;
  final StudentListItem student;

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  StudentIncidentReport? _report;
  bool _loadingReport = false;
  String? _error;

  bool get _canRecordIncident =>
      widget.session.hasPermission('discipline_incidents.create');

  bool get _canViewIncidentReport =>
      widget.session.hasPermission('discipline_incidents.report.view');

  StudentCurrentYear? get _currentYear => widget.student.currentYear;

  @override
  void initState() {
    super.initState();
    if (_canViewIncidentReport) {
      _loadReport();
    }
  }

  Future<void> _loadReport() async {
    final currentYear = _currentYear;

    if (currentYear == null || currentYear.classId == null) {
      setState(() {
        _error = 'This student does not have an active class assignment.';
      });
      return;
    }

    setState(() {
      _loadingReport = true;
      _error = null;
    });

    try {
      final report = await widget.api.studentDisciplineIncidentReport(
        token: widget.token,
        classId: currentYear.classId!,
        studentId: widget.student.id,
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
        _error = 'Unable to load the student incident report.';
      });
    }
  }

  Future<void> _openIncidentRecorder() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => StudentIncidentRecordScreen(
          api: widget.api,
          token: widget.token,
          session: widget.session,
          student: widget.student,
        ),
      ),
    );

    if (created == true && mounted && _canViewIncidentReport) {
      await _loadReport();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentYear = _currentYear;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Profile'),
      ),
      body: RefreshIndicator(
        onRefresh: _canViewIncidentReport ? _loadReport : () async {},
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF115E59),
                    Color(0xFF0F766E),
                    Color(0xFF134E4A)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.student.name,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.student.phone ?? '-',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _InfoChip(
                          label: 'Roll', value: currentYear?.rollNumber ?? '—'),
                      _InfoChip(
                          label: 'Level', value: currentYear?.levelName ?? '—'),
                      _InfoChip(
                          label: 'Class', value: currentYear?.className ?? '—'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Actions', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      if (_canRecordIncident)
                        FilledButton.icon(
                          onPressed: _openIncidentRecorder,
                          icon: const Icon(Icons.gavel_outlined),
                          label: const Text('Record Incident'),
                        ),
                      if (_canViewIncidentReport)
                        OutlinedButton.icon(
                          onPressed: _loadingReport ? null : _loadReport,
                          icon: const Icon(Icons.description_outlined),
                          label: const Text('Refresh Incident Report'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (_canViewIncidentReport) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Incident Report', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      'Recorded discipline incidents for this student.',
                      style: theme.textTheme.bodyMedium,
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
                    const SizedBox(height: 14),
                    if (_loadingReport)
                      const Center(child: CircularProgressIndicator())
                    else if (_report == null || _report!.incidents.isEmpty)
                      Text(
                        'No incidents recorded for this student.',
                        style: theme.textTheme.bodyLarge,
                      )
                    else ...[
                      Text(
                        'Total incidents: ${_report!.incidents.length}',
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 12),
                      ..._report!.incidents.map(_buildIncidentCard),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIncidentCard(DisciplineIncidentItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
              item.whatHappened,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2933),
              ),
            ),
            const SizedBox(height: 8),
            _DetailLine(label: 'Reported by', value: item.reportedBy ?? '—'),
            _DetailLine(
              label: 'When',
              value: _formatDisplayDate(item.happenedAt ?? item.createdAt),
            ),
            _DetailLine(label: 'Action', value: item.actionTaken ?? '—'),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2933),
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(color: Color(0xFF52606D)),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDisplayDate(String? value) {
  if (value == null || value.isEmpty) {
    return '—';
  }

  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return value;
  }

  final month = parsed.month.toString().padLeft(2, '0');
  final day = parsed.day.toString().padLeft(2, '0');
  final hour = parsed.hour.toString().padLeft(2, '0');
  final minute = parsed.minute.toString().padLeft(2, '0');
  return '${parsed.year}-$month-$day $hour:$minute';
}
