import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/hr_models.dart';
import '../services/laravel_api.dart';

class TeacherDetailScreen extends StatefulWidget {
  const TeacherDetailScreen({
    super.key,
    required this.api,
    required this.token,
    required this.session,
    required this.teacherId,
  });

  final LaravelApi api;
  final String token;
  final AuthSession session;
  final int teacherId;

  @override
  State<TeacherDetailScreen> createState() => _TeacherDetailScreenState();
}

class _TeacherDetailScreenState extends State<TeacherDetailScreen> {
  final TextEditingController _employeeController = TextEditingController();
  final TextEditingController _qualificationController =
      TextEditingController();
  final TextEditingController _specializationController =
      TextEditingController();
  final TextEditingController _joiningController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  static const List<String> _statuses = [
    'active',
    'inactive',
    'on_leave',
  ];

  TeacherDetail? _detail;
  String _status = _statuses.first;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _canEdit =>
      widget.session.hasPermission('teachers.edit') &&
      widget.session.roles.any((role) => role.toLowerCase() == 'school_admin');

  @override
  void initState() {
    super.initState();
    _loadTeacher();
  }

  @override
  void dispose() {
    _employeeController.dispose();
    _qualificationController.dispose();
    _specializationController.dispose();
    _joiningController.dispose();
    _experienceController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadTeacher() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final detail = await widget.api.teacherDetail(
        token: widget.token,
        teacherId: widget.teacherId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _detail = detail;
        _employeeController.text = detail.profile.employeeNumber ?? '';
        _qualificationController.text = detail.profile.qualification ?? '';
        _specializationController.text = detail.profile.specialization ?? '';
        _joiningController.text = detail.profile.joiningDate ?? '';
        _experienceController.text =
            detail.profile.experienceYears?.toString() ?? '';
        _bioController.text = detail.profile.bio ?? '';
        _status = _statuses.contains(detail.profile.status)
            ? detail.profile.status!
            : _statuses.first;
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
        _error = 'Unable to load teacher.';
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_canEdit) {
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final experienceYears = int.tryParse(_experienceController.text.trim());

    try {
      final updated = await widget.api.updateTeacherProfile(
        token: widget.token,
        teacherId: widget.teacherId,
        payload: {
          'employee_number': _employeeController.text.trim().isEmpty
              ? null
              : _employeeController.text.trim(),
          'qualification': _qualificationController.text.trim().isEmpty
              ? null
              : _qualificationController.text.trim(),
          'specialization': _specializationController.text.trim().isEmpty
              ? null
              : _specializationController.text.trim(),
          'joining_date': _joiningController.text.trim().isEmpty
              ? null
              : _joiningController.text.trim(),
          'experience_years': experienceYears,
          'status': _status,
          'bio': _bioController.text.trim().isEmpty
              ? null
              : _bioController.text.trim(),
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _detail = _detail == null
            ? null
            : TeacherDetail(teacher: _detail!.teacher, profile: updated);
        _saving = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Teacher profile updated.')),
        );
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
        _error = 'Unable to update teacher profile.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final detail = _detail;

    if (detail == null) {
      return const Scaffold(
        body: Center(child: Text('Teacher not found.')),
      );
    }

    final teacher = detail.teacher;

    return Scaffold(
      appBar: AppBar(title: Text(teacher.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(teacher.name,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(teacher.position ?? 'No position'),
                const SizedBox(height: 6),
                Text(teacher.email ?? 'No email'),
                Text(teacher.phone ?? 'No phone'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Profile', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _employeeController,
            enabled: _canEdit && !_saving,
            decoration: const InputDecoration(
              labelText: 'Employee number',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _qualificationController,
            enabled: _canEdit && !_saving,
            decoration: const InputDecoration(
              labelText: 'Qualification',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _specializationController,
            enabled: _canEdit && !_saving,
            decoration: const InputDecoration(
              labelText: 'Specialization',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _joiningController,
            enabled: _canEdit && !_saving,
            decoration: const InputDecoration(
              labelText: 'Joining date (YYYY-MM-DD)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _experienceController,
            enabled: _canEdit && !_saving,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Experience years',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _status,
            items: _statuses
                .map(
                  (status) => DropdownMenuItem(
                    value: status,
                    child: Text(status),
                  ),
                )
                .toList(),
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
            ),
            onChanged: !_canEdit || _saving
                ? null
                : (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _status = value;
                    });
                  },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bioController,
            enabled: _canEdit && !_saving,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Bio',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFB42318),
                  ),
            ),
          ],
          if (_canEdit) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _saveProfile,
              child: Text(_saving ? 'Saving...' : 'Save profile'),
            ),
          ],
        ],
      ),
    );
  }
}
