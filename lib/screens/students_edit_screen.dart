import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/student_management_models.dart';
import '../services/laravel_api.dart';
import '../widgets/student_assignment_form.dart';
import '../widgets/student_profile_form.dart';

class StudentsEditScreen extends StatefulWidget {
  const StudentsEditScreen({
    super.key,
    required this.api,
    required this.token,
    required this.session,
    required this.studentId,
  });

  final LaravelApi api;
  final String token;
  final AuthSession session;
  final int studentId;

  @override
  State<StudentsEditScreen> createState() => _StudentsEditScreenState();
}

class _StudentsEditScreenState extends State<StudentsEditScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _secondPhoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _busAssignController = TextEditingController();
  final _bloodTypeController = TextEditingController();

  int _step = 0;
  String? _gender;
  String? _studentType;
  String? _feeType;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStudent();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _secondPhoneController.dispose();
    _addressController.dispose();
    _busAssignController.dispose();
    _bloodTypeController.dispose();
    super.dispose();
  }

  Future<void> _loadStudent() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final student = await widget.api.studentDetail(
        token: widget.token,
        studentId: widget.studentId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _nameController.text = student.name;
        _phoneController.text = student.phone ?? '';
        _secondPhoneController.text = student.secondPhone ?? '';
        _addressController.text = student.address ?? '';
        _busAssignController.text = student.busAssign ?? '';
        _bloodTypeController.text = student.bloodType ?? '';
        _gender = student.gender;
        _studentType = student.studentType ?? 'normal';
        _feeType = student.feeType ?? 'normal';
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
        _error = 'Unable to load student profile.';
      });
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _error = 'Student name is required.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.api.updateStudent(
        token: widget.token,
        studentId: widget.studentId,
        payload: {
          'name': name,
          'phone': _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          'second_phone': _secondPhoneController.text.trim().isEmpty
              ? null
              : _secondPhoneController.text.trim(),
          'gender': _gender,
          'student_type': _studentType,
          'fee_type': _feeType,
          'address': _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
          'bus_assign': _busAssignController.text.trim().isEmpty
              ? null
              : _busAssignController.text.trim(),
          'blood_type': _bloodTypeController.text.trim().isEmpty
              ? null
              : _bloodTypeController.text.trim(),
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Profile updated.')));
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
        _error = 'Unable to update student profile.';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Student')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          _StepHeader(step: _step),
          const SizedBox(height: 16),
          if (_step == 0)
            StudentProfileForm(
              nameController: _nameController,
              phoneController: _phoneController,
              secondPhoneController: _secondPhoneController,
              addressController: _addressController,
              busAssignController: _busAssignController,
              bloodTypeController: _bloodTypeController,
              gender: _gender,
              studentType: _studentType,
              feeType: _feeType,
              onGenderChanged: (value) => setState(() => _gender = value),
              onStudentTypeChanged: (value) =>
                  setState(() => _studentType = value),
              onFeeTypeChanged: (value) => setState(() => _feeType = value),
              onSubmit: _saveProfile,
              submitLabel: 'Update Profile',
              loading: _saving,
            )
          else
            StudentAssignmentForm(
              api: widget.api,
              token: widget.token,
              studentId: widget.studentId,
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
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          setState(() {
            _step = _step == 0 ? 1 : 0;
          });
        },
        label: Text(_step == 0 ? 'Academic Assignment' : 'Profile'),
        icon: const Icon(Icons.swap_horiz),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.step,
  });

  final int step;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _StepChip(label: '1. Profile', active: step == 0),
        _StepChip(label: '2. Academic Assignment', active: step == 1),
      ],
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({
    required this.label,
    required this.active,
  });

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = active
        ? theme.colorScheme.primary
        : theme.colorScheme.primary.withOpacity(0.08);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? Colors.white : theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
