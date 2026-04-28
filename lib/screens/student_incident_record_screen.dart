import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/student_list_models.dart';
import '../services/laravel_api.dart';
import '../services/offline_sync_queue.dart';

class StudentIncidentRecordScreen extends StatefulWidget {
  const StudentIncidentRecordScreen({
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
  State<StudentIncidentRecordScreen> createState() =>
      _StudentIncidentRecordScreenState();
}

class _StudentIncidentRecordScreenState
    extends State<StudentIncidentRecordScreen> {
  final OfflineSyncQueue _syncQueue = const OfflineSyncQueue();
  final _whatHappenedController = TextEditingController();
  final _actionTakenController = TextEditingController();
  final _reportedByController = TextEditingController();
  DateTime _happenedAt = DateTime.now();
  bool _saving = false;
  String? _error;

  bool get _isSchoolAdmin => widget.session.roles.any(
        (role) => role.toLowerCase() == 'school_admin',
      );

  StudentCurrentYear? get _currentYear => widget.student.currentYear;

  @override
  void initState() {
    super.initState();
    _reportedByController.text = widget.session.name;
  }

  @override
  void dispose() {
    _whatHappenedController.dispose();
    _actionTakenController.dispose();
    _reportedByController.dispose();
    super.dispose();
  }

  Future<void> _pickHappenedAt() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _happenedAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_happenedAt),
    );

    if (pickedTime == null) {
      return;
    }

    setState(() {
      _happenedAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _submit() async {
    final currentYear = _currentYear;

    if (currentYear == null || currentYear.classId == null) {
      setState(() {
        _error = 'This student does not have an active class assignment.';
      });
      return;
    }

    final whatHappened = _whatHappenedController.text.trim();
    if (whatHappened.length < 3) {
      setState(() {
        _error = 'Describe what happened in at least 3 characters.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.api.createStudentDisciplineIncident(
        token: widget.token,
        studentId: widget.student.id,
        whatHappened: whatHappened,
        happenedAt: _formatDateTime(_happenedAt),
        actionTaken: _actionTakenController.text.trim(),
        reportedByName:
            _isSchoolAdmin ? _reportedByController.text.trim() : null,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Discipline incident recorded.')),
        );

      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      await _queueOfflineIncident(
        currentYearClassId: currentYear.classId!,
        fallbackMessage: error.message,
      );
    } catch (_) {
      await _queueOfflineIncident(
        currentYearClassId: currentYear.classId!,
      );
    }
  }

  Future<void> _queueOfflineIncident({
    required int currentYearClassId,
    String? fallbackMessage,
  }) async {
    final whatHappened = _whatHappenedController.text.trim();
    if (whatHappened.length < 3) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
        _error = fallbackMessage ?? 'Unable to save discipline incident.';
      });
      return;
    }

    await _syncQueue.upsert(
      OfflineSyncOperation(
        key:
            '$incidentCreateQueuePrefix${widget.student.id}:${_happenedAt.millisecondsSinceEpoch}',
        type: 'incident_create',
        payload: {
          'student_id': widget.student.id,
          'class_id': currentYearClassId,
          'what_happened': whatHappened,
          'happened_at': _formatDateTime(_happenedAt),
          'action_taken': _actionTakenController.text.trim(),
          'reported_by_name':
              _isSchoolAdmin ? _reportedByController.text.trim() : null,
        },
        createdAt: DateTime.now().toIso8601String(),
      ),
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Incident saved offline and queued for sync.'),
        ),
      );

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentYear = _currentYear;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Incident'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF9A3412), Color(0xFFCB6E17)],
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
                  '${currentYear?.levelName ?? '—'} • ${currentYear?.className ?? '—'}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.student.phone ?? '-',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Incident details', style: theme.textTheme.titleLarge),
                const SizedBox(height: 18),
                TextField(
                  controller: _whatHappenedController,
                  minLines: 4,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'What happened?',
                    hintText: 'Describe the incident',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: _pickHappenedAt,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'When did it happen?',
                      border: OutlineInputBorder(),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                            child: Text(_formatHumanDateTime(_happenedAt))),
                        const Icon(Icons.schedule),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _actionTakenController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'What action was taken?',
                    hintText: 'Optional',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _reportedByController,
                  readOnly: !_isSchoolAdmin,
                  decoration: InputDecoration(
                    labelText: 'Who reported it?',
                    hintText: _isSchoolAdmin ? 'Reporter name' : null,
                    border: const OutlineInputBorder(),
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
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save Incident'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.year}-$month-$day $hour:$minute:00';
}

String _formatHumanDateTime(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.year}-$month-$day $hour:$minute';
}
