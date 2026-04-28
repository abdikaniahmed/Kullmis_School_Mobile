import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/discipline_incident_models.dart';
import '../models/student_list_models.dart';
import '../models/student_management_models.dart';
import '../services/laravel_api.dart';
import '../services/offline_cache_store.dart';
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
  final OfflineCacheStore _cacheStore = const FileOfflineCacheStore();

  StudentProfile? _profile;
  StudentIncidentReport? _report;
  bool _loading = true;
  bool _refreshingReport = false;
  bool _usingOfflineData = false;
  String? _statusMessage;
  String? _error;

  bool get _canRecordIncident =>
      widget.session.hasPermission('discipline_incidents.create');

  bool get _canViewIncidentReport =>
      widget.session.hasPermission('discipline_incidents.report.view');

  StudentAcademicAssignment? get _currentYear =>
      _profile?.currentYear ?? _toAcademicAssignment(widget.student.currentYear);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool reportOnly = false}) async {
    setState(() {
      if (reportOnly) {
        _refreshingReport = true;
      } else {
        _loading = true;
      }
      _error = null;
      _statusMessage = null;
    });

    try {
      final profile = reportOnly
          ? (_profile ??
              await widget.api.studentDetail(
                token: widget.token,
                studentId: widget.student.id,
              ))
          : await widget.api.studentDetail(
              token: widget.token,
              studentId: widget.student.id,
            );

      StudentIncidentReport? report = _report;
      if (_canViewIncidentReport) {
        final currentYear =
            profile.currentYear ?? _toAcademicAssignment(widget.student.currentYear);
        final classId = currentYear?.classId;
        if (classId == null) {
          report = null;
        } else {
          report = await widget.api.studentDisciplineIncidentReport(
            token: widget.token,
            classId: classId,
            studentId: widget.student.id,
          );
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _profile = profile;
        _report = report;
        _loading = false;
        _refreshingReport = false;
        _usingOfflineData = false;
      });

      await _writeSnapshot();
    } on ApiException catch (error) {
      final restored = await _restoreSnapshot(
        fallbackMessage: 'Offline mode: showing last synced student profile.',
      );
      if (restored) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _refreshingReport = false;
        _error = error.message;
      });
    } catch (_) {
      final restored = await _restoreSnapshot(
        fallbackMessage: 'Offline mode: showing last synced student profile.',
      );
      if (restored) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _refreshingReport = false;
        _error = 'Unable to load the student profile.';
      });
    }
  }

  Future<bool> _restoreSnapshot({
    required String fallbackMessage,
  }) async {
    final json = await _cacheStore.readCacheDocument(_cacheKey(widget.student.id));
    if (json == null) {
      return false;
    }

    final snapshot = StudentDetailOfflineSnapshot.fromJson(json);

    if (!mounted) {
      return true;
    }

    setState(() {
      _profile = snapshot.profile;
      _report = snapshot.report;
      _loading = false;
      _refreshingReport = false;
      _usingOfflineData = true;
      _statusMessage = fallbackMessage;
      _error = null;
    });

    return true;
  }

  Future<void> _writeSnapshot() async {
    await _cacheStore.writeCacheDocument(
      _cacheKey(widget.student.id),
      StudentDetailOfflineSnapshot(
        studentListItem: widget.student.toJson(),
        profile: _profile,
        report: _report,
      ).toJson(),
    );
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
      if (_usingOfflineData) {
        _showMessage('Incident queued offline. It will sync when the server is reachable.');
        return;
      }

      await _loadData(reportOnly: true);
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
    final profile = _profile;
    final currentYear = _currentYear;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Profile'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadData(),
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
                          Color(0xFF134E4A),
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
                          profile?.name ?? widget.student.name,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          profile?.phone ?? widget.student.phone ?? '-',
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
                              label: 'Roll',
                              value: currentYear?.rollNumber ?? '-',
                            ),
                            _InfoChip(
                              label: 'Level',
                              value: currentYear?.levelName ?? '-',
                            ),
                            _InfoChip(
                              label: 'Class',
                              value: currentYear?.className ?? '-',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4CE),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.cloud_off_outlined,
                            size: 18,
                            color: Color(0xFF7A4F01),
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
                        Text('Profile', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 14),
                        _DetailLine(label: 'Phone', value: profile?.phone ?? '-'),
                        _DetailLine(
                          label: 'Second Phone',
                          value: profile?.secondPhone ?? '-',
                        ),
                        _DetailLine(label: 'Gender', value: profile?.gender ?? '-'),
                        _DetailLine(
                          label: 'Student Type',
                          value: profile?.studentType ?? '-',
                        ),
                        _DetailLine(
                          label: 'Fee Type',
                          value: profile?.feeType ?? '-',
                        ),
                        _DetailLine(
                          label: 'Blood Type',
                          value: profile?.bloodType ?? '-',
                        ),
                        _DetailLine(
                          label: 'Bus Assign',
                          value: profile?.busAssign ?? '-',
                        ),
                        _DetailLine(
                          label: 'Address',
                          value: profile?.address ?? '-',
                        ),
                        if ((profile?.disabledAt ?? '').isNotEmpty)
                          _DetailLine(
                            label: 'Disabled At',
                            value: profile?.disabledAt ?? '-',
                          ),
                        if ((profile?.disableReason ?? '').isNotEmpty)
                          _DetailLine(
                            label: 'Disable Reason',
                            value: profile?.disableReason ?? '-',
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
                                onPressed: _usingOfflineData
                                    ? null
                                    : _openIncidentRecorder,
                                icon: const Icon(Icons.gavel_outlined),
                                label: const Text('Record Incident'),
                              ),
                            if (_canViewIncidentReport)
                              OutlinedButton.icon(
                                onPressed: _refreshingReport
                                    ? null
                                    : () => _loadData(reportOnly: true),
                                icon: const Icon(Icons.description_outlined),
                                label: Text(
                                  _usingOfflineData
                                      ? 'Retry Online'
                                      : 'Refresh Incident Report',
                                ),
                              ),
                          ],
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
                          const SizedBox(height: 14),
                          if (_refreshingReport)
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
            _DetailLine(label: 'Reported by', value: item.reportedBy ?? '-'),
            _DetailLine(
              label: 'When',
              value: _formatDisplayDate(item.happenedAt ?? item.createdAt),
            ),
            _DetailLine(label: 'Action', value: item.actionTaken ?? '-'),
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

StudentAcademicAssignment? _toAcademicAssignment(StudentCurrentYear? value) {
  if (value == null) {
    return null;
  }

  return StudentAcademicAssignment(
    id: 0,
    academicYearId: null,
    levelId: null,
    classId: value.classId,
    rollNumber: value.rollNumber,
    status: null,
    levelName: value.levelName,
    className: value.className,
  );
}

String _formatDisplayDate(String? value) {
  if (value == null || value.isEmpty) {
    return '-';
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

String _cacheKey(int studentId) => 'student_detail_$studentId';
