import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/student_management_models.dart';
import '../services/laravel_api.dart';
import '../widgets/student_assignment_form.dart';
import '../widgets/student_profile_form.dart';

class StudentsCreateScreen extends StatefulWidget {
  const StudentsCreateScreen({
    super.key,
    required this.api,
    required this.token,
    required this.session,
  });

  final LaravelApi api;
  final String token;
  final AuthSession session;

  @override
  State<StudentsCreateScreen> createState() => _StudentsCreateScreenState();
}

class _StudentsCreateScreenState extends State<StudentsCreateScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _secondPhoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _busAssignController = TextEditingController();
  final _bloodTypeController = TextEditingController();

  int _step = 0;
  int? _studentId;
  String? _gender;
  String? _studentType = 'normal';
  String? _feeType = 'normal';
  bool _saving = false;
  String? _error;

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

  Future<void> _submitProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _error = 'Student name is required.';
      });
      return;
    }

    if (_studentType == null || _feeType == null) {
      setState(() {
        _error = 'Select student type and fee type.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final result = await widget.api.createStudent(
        token: widget.token,
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

      _studentId = result.student.id;
      _step = 1;
      _saving = false;

      final password = result.generatedPassword;
      if (password != null && password.isNotEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('Student created. Password: $password')),
          );
      } else {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Student profile saved.')),
          );
      }

      setState(() {});
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
        _error = 'Unable to save student profile.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Student')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          _StepHeader(step: _step, studentId: _studentId),
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
              onSubmit: _submitProfile,
              submitLabel: 'Save & Continue',
              loading: _saving,
            )
          else if (_studentId != null)
            StudentAssignmentForm(
              api: widget.api,
              token: widget.token,
              studentId: _studentId!,
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
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.step,
    required this.studentId,
  });

  final int step;
  final int? studentId;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _StepChip(
          label: '1. Profile',
          active: step == 0,
        ),
        _StepChip(
          label: '2. Academic Assignment',
          active: step == 1,
          enabled: studentId != null,
        ),
      ],
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({
    required this.label,
    required this.active,
    this.enabled = true,
  });

  final String label;
  final bool active;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = active
        ? theme.colorScheme.primary
        : theme.colorScheme.primary.withOpacity(0.08);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: enabled ? background : theme.disabledColor.withOpacity(0.2),
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
