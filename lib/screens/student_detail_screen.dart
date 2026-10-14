import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/discipline_incident_models.dart';
import '../models/student_list_models.dart';
import '../models/student_management_models.dart';
import '../services/laravel_api.dart';
import '../services/offline_cache_store.dart';
import 'student_incident_record_screen.dart';
import 'students_edit_screen.dart';

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
  int _selectedTab = 0;
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
      _profile?.currentYear ??
      _toAcademicAssignment(widget.student.currentYear);

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
        final currentYear = profile.currentYear ??
            _toAcademicAssignment(widget.student.currentYear);
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
    final json =
        await _cacheStore.readCacheDocument(_cacheKey(widget.student.id));
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
        _showMessage(
            'Incident queued offline. It will sync when the server is reachable.');
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

  Future<void> _openEditor() async {
    await Navigator.of(context).push<bool>(MaterialPageRoute<bool>(
        builder: (_) => StudentsEditScreen(
            api: widget.api,
            token: widget.token,
            session: widget.session,
            studentId: widget.student.id)));
    if (mounted) await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile;
    final year = _currentYear;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5EF),
      appBar: AppBar(
          title: const Text('Student Profile',
              style: TextStyle(fontWeight: FontWeight.w700)),
          backgroundColor: Colors.white),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadData(),
              child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                  children: [
                    Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [Color(0xFF00756D), Color(0xFF00615C)]),
                            borderRadius: BorderRadius.circular(22)),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const CircleAvatar(
                                  radius: 36,
                                  backgroundColor: Color(0xFFE6EBEF),
                                  child: Icon(Icons.person,
                                      size: 54, color: Color(0xFF64748B))),
                              const SizedBox(width: 16),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(p?.name ?? widget.student.name,
                                        style: const TextStyle(
                                            fontSize: 23,
                                            height: 1.2,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white)),
                                    const SizedBox(height: 8),
                                    Text(
                                        p?.phone ?? widget.student.phone ?? '-',
                                        style: const TextStyle(
                                            fontSize: 16,
                                            color: Color(0xFFBDE1DC))),
                                    const SizedBox(height: 12),
                                    Wrap(spacing: 8, runSpacing: 8, children: [
                                      _InfoChip(
                                          label: 'Roll',
                                          value: year?.rollNumber ?? '-'),
                                      _InfoChip(
                                          label: 'Level',
                                          value: year?.levelName ?? '-'),
                                      _InfoChip(
                                          label: 'Class',
                                          value: year?.className ?? '-'),
                                    ]),
                                  ])),
                            ])),
                    const SizedBox(height: 14),
                    Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16)),
                        child: Row(children: [
                          _tab('Profile', Icons.person, 0),
                          _tab('Academic', Icons.menu_book_outlined, 1),
                          if (_canRecordIncident || _canViewIncidentReport)
                            _tab('Incidents', Icons.shield_outlined, 2),
                        ])),
                    if (_statusMessage != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(_statusMessage!,
                              style:
                                  const TextStyle(color: Color(0xFF7A4F01)))),
                    if (_error != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(_error!,
                              style:
                                  const TextStyle(color: Color(0xFFB42318)))),
                    const SizedBox(height: 18),
                    if (_selectedTab == 0)
                      _section(
                          title: 'Personal Information',
                          icon: Icons.person,
                          trailing: widget.session
                                  .hasPermission('students.edit')
                              ? TextButton.icon(
                                  onPressed:
                                      _usingOfflineData ? null : _openEditor,
                                  style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFF006B63),
                                      backgroundColor: const Color(0xFFE1F3EF)),
                                  icon:
                                      const Icon(Icons.edit_outlined, size: 20),
                                  label: const Text('Edit'))
                              : null,
                          children: [
                            _DetailLine(
                                label: 'Phone',
                                value: p?.phone ?? widget.student.phone ?? '-'),
                            _DetailLine(
                                label: 'Second Phone',
                                value: p?.secondPhone ?? '-'),
                            _DetailLine(
                                label: 'Gender',
                                value: _displayValue(p?.gender)),
                            _DetailLine(
                                label: 'Student Type',
                                value: _displayValue(p?.studentType)),
                            _DetailLine(
                                label: 'Fee Type',
                                value: _displayValue(p?.feeType)),
                            _DetailLine(
                                label: 'Blood Type',
                                value: p?.bloodType ?? '-'),
                            _DetailLine(
                                label: 'Bus Assign',
                                value: p?.busAssign ?? '-'),
                            _DetailLine(
                                label: 'Address', value: p?.address ?? '-'),
                            if ((p?.disabledAt ?? '').isNotEmpty)
                              _DetailLine(
                                  label: 'Disabled At', value: p!.disabledAt!),
                            if ((p?.disableReason ?? '').isNotEmpty)
                              _DetailLine(
                                  label: 'Disable Reason',
                                  value: p!.disableReason!),
                          ]),
                    if (_selectedTab == 1)
                      _section(
                          title: 'Current Assignment',
                          icon: Icons.menu_book_outlined,
                          children: [
                            _DetailLine(
                                label: 'Roll Number',
                                value: year?.rollNumber ?? '-'),
                            _DetailLine(
                                label: 'Level', value: year?.levelName ?? '-'),
                            _DetailLine(
                                label: 'Class', value: year?.className ?? '-'),
                            _DetailLine(
                                label: 'Status',
                                value: _displayValue(year?.status)),
                          ]),
                    if (_selectedTab != 1 &&
                        (_canRecordIncident || _canViewIncidentReport)) ...[
                      const SizedBox(height: 18),
                      _section(
                          title: 'Actions',
                          icon: Icons.settings,
                          children: [
                            LayoutBuilder(builder: (context, constraints) {
                              final buttons = <Widget>[
                                if (_canRecordIncident)
                                  FilledButton.icon(
                                      onPressed: _usingOfflineData
                                          ? null
                                          : _openIncidentRecorder,
                                      style: FilledButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF00756D),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 18),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12))),
                                      icon: const Icon(Icons.gavel),
                                      label: const Text('Record Incident')),
                                if (_canViewIncidentReport)
                                  OutlinedButton.icon(
                                      onPressed: _refreshingReport
                                          ? null
                                          : () => _loadData(reportOnly: true),
                                      style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              const Color(0xFF006B63),
                                          side: const BorderSide(
                                              color: Color(0xFF00756D)),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 18),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12))),
                                      icon: const Icon(
                                          Icons.description_outlined),
                                      label: Text(_usingOfflineData
                                          ? 'Retry Online'
                                          : 'Refresh Incident Report')),
                              ];
                              if (constraints.maxWidth < 460 ||
                                  MediaQuery.textScalerOf(context).scale(1) >
                                      1.2) {
                                return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      for (var i = 0;
                                          i < buttons.length;
                                          i++) ...[
                                        if (i > 0) const SizedBox(height: 10),
                                        buttons[i],
                                      ]
                                    ]);
                              }
                              return Row(children: [
                                for (var i = 0; i < buttons.length; i++) ...[
                                  if (i > 0) const SizedBox(width: 12),
                                  Expanded(child: buttons[i]),
                                ]
                              ]);
                            }),
                          ]),
                    ],
                    if (_selectedTab != 1 && _canViewIncidentReport) ...[
                      const SizedBox(height: 18),
                      _section(
                          title: 'Incident Report',
                          icon: Icons.description_outlined,
                          trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                  color: const Color(0xFFEDF3FF),
                                  borderRadius: BorderRadius.circular(14)),
                              child: Text('${_report?.incidents.length ?? 0}',
                                  style: const TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w700))),
                          children: [
                            const Text(
                                'Recorded discipline incidents for this student.',
                                style: TextStyle(color: Color(0xFF748091))),
                            const SizedBox(height: 14),
                            if (_refreshingReport)
                              const Center(child: CircularProgressIndicator())
                            else if (_report == null ||
                                _report!.incidents.isEmpty)
                              Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                      color: const Color(0xFFF5F6F8),
                                      borderRadius: BorderRadius.circular(16)),
                                  child: const Column(children: [
                                    Icon(Icons.description_outlined,
                                        size: 32, color: Color(0xFF8590A0)),
                                    SizedBox(height: 10),
                                    Text('No incidents recorded',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600)),
                                    SizedBox(height: 4),
                                    Text(
                                        'There are no discipline incidents for this student.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            color: Color(0xFF748091))),
                                  ]))
                            else
                              ..._report!.incidents.map(_buildIncidentCard),
                          ]),
                    ],
                  ])),
    );
  }

  Widget _tab(String label, IconData icon, int index) => Expanded(
          child: TextButton(
        onPressed: () => setState(() => _selectedTab = index),
        style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            foregroundColor: _selectedTab == index
                ? const Color(0xFF006B63)
                : const Color(0xFF475569),
            backgroundColor: _selectedTab == index
                ? const Color(0xFFE3F6F0)
                : Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))),
        child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [Icon(icon, size: 20), Text(label)]),
      ));

  Widget _section(
          {required String title,
          required IconData icon,
          Widget? trailing,
          required List<Widget> children}) =>
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(22)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
                radius: 21,
                backgroundColor: const Color(0xFFE3F6F0),
                child: Icon(icon, color: const Color(0xFF00756D))),
            const SizedBox(width: 12),
            Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w700))),
            if (trailing != null) trailing,
          ]),
          const SizedBox(height: 14),
          ...children,
        ]),
      );

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
        color: Colors.white.withValues(alpha: 0.14),
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
  const _DetailLine({required this.label, required this.value});
  final String label;
  final String value;
  static const _icons = <String, IconData>{
    'Phone': Icons.phone,
    'Second Phone': Icons.phone,
    'Gender': Icons.person_outline,
    'Student Type': Icons.school,
    'Fee Type': Icons.paid,
    'Blood Type': Icons.water_drop,
    'Bus Assign': Icons.directions_bus,
    'Address': Icons.location_on
  };
  static const _colors = <String, Color>{
    'Phone': Colors.green,
    'Second Phone': Colors.purple,
    'Gender': Colors.blue,
    'Student Type': Colors.orange,
    'Fee Type': Colors.amber,
    'Blood Type': Colors.red,
    'Bus Assign': Colors.blue,
    'Address': Colors.red
  };
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFF0F2F4)))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_icons.containsKey(label)) ...[
            Icon(_icons[label], size: 22, color: _colors[label]),
            const SizedBox(width: 12)
          ],
          Expanded(
              child: Text(label,
                  style: const TextStyle(color: Color(0xFF748091)))),
          const SizedBox(width: 12),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      color: Color(0xFF172033), fontWeight: FontWeight.w500))),
        ]),
      );
}

String _displayValue(String? value) {
  if (value == null || value.trim().isEmpty) return '-';
  return value
      .trim()
      .split(RegExp(r'[_\s]+'))
      .map((word) =>
          word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
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
