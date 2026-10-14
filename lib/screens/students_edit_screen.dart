import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/student_management_models.dart';
import '../widgets/student_edit_design.dart';
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

  StudentProfile? _student;
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
        _student = student;
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
    FocusScope.of(context).unfocus();
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
        _step = 1;
      });

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
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

  void _resetProfile() {
    final student = _student;
    if (student == null) return;
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
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5ED),
      appBar: AppBar(
          title: const Text('Edit Student',
              style: TextStyle(color: studentInk, fontWeight: FontWeight.w700)),
          backgroundColor: Colors.white,
          foregroundColor: studentInk,
          surfaceTintColor: Colors.transparent),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(children: [
                if (MediaQuery.viewInsetsOf(context).bottom == 0) ...[
                  Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Row(children: [
                        Expanded(
                            flex: 2,
                            child: _stepChip(
                                '1. Profile',
                                _step == 1 ? Icons.check_circle : Icons.person,
                                _step == 0)),
                        Container(
                            width: 20,
                            height: 2,
                            color: studentTeal.withValues(alpha: .3)),
                        Expanded(
                            flex: 3,
                            child: _stepChip('2. Academic Assignment',
                                Icons.menu_book, _step == 1)),
                      ])),
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _summary()),
                  const SizedBox(height: 14),
                ],
                Expanded(
                    child: _step == 0
                        ? ListView(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                            children: [
                                StudentProfileForm(
                                    editDesign: true,
                                    nameController: _nameController,
                                    phoneController: _phoneController,
                                    secondPhoneController:
                                        _secondPhoneController,
                                    addressController: _addressController,
                                    busAssignController: _busAssignController,
                                    bloodTypeController: _bloodTypeController,
                                    gender: _gender,
                                    studentType: _studentType,
                                    feeType: _feeType,
                                    onGenderChanged: (v) =>
                                        setState(() => _gender = v),
                                    onStudentTypeChanged: (v) =>
                                        setState(() => _studentType = v),
                                    onFeeTypeChanged: (v) =>
                                        setState(() => _feeType = v),
                                    onSubmit: _saveProfile,
                                    submitLabel: 'Academic Assignment',
                                    loading: _saving),
                              ])
                        : StudentAssignmentForm(
                            api: widget.api,
                            token: widget.token,
                            studentId: widget.studentId,
                            editDesign: true,
                            onBack: () => setState(() => _step = 0))),
                if (_step == 0 && _error != null)
                  Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_error!,
                          style: const TextStyle(color: Color(0xFFB42318)))),
                if (_step == 0 && _student == null)
                  TextButton.icon(
                      onPressed: _loadStudent,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry')),
                if (_step == 0)
                  StudentFooter(
                      backLabel: 'Reset',
                      nextLabel: 'Academic Assignment',
                      backIcon: Icons.refresh,
                      nextIcon: Icons.arrow_forward,
                      busy: _saving,
                      onBack: _resetProfile,
                      onNext: _student == null ? null : _saveProfile),
              ]))),
    );
  }

  Widget _stepChip(String label, IconData icon, bool active) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
          color: active ? studentTeal : const Color(0xFFE7EEE7),
          borderRadius: BorderRadius.circular(30)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 21, color: active ? Colors.white : studentTeal),
        const SizedBox(width: 7),
        Flexible(
            child: Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : studentTeal)))
      ]));
  Widget _summary() => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFFE7F6F0),
          border: Border.all(color: Colors.white, width: 2),
          borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
                color: const Color(0xFFDCE6F4),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3)),
            child:
                const Icon(Icons.person, size: 52, color: Color(0xFF526178))),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_nameController.text,
              style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: studentInk)),
          const SizedBox(height: 4),
          Text(_phoneController.text,
              style: const TextStyle(color: Color(0xFF748094))),
          const SizedBox(height: 10),
          Wrap(spacing: 7, runSpacing: 6, children: [
            if (_student?.currentYear?.rollNumber != null)
              _badge(Icons.badge, _student!.currentYear!.rollNumber!),
            if (_gender != null)
              _badge(_gender == 'female' ? Icons.female : Icons.male,
                  _gender == 'female' ? 'Female' : 'Male'),
            _badge(Icons.school,
                _studentType == 'boarding' ? 'Boarding' : 'Normal'),
          ]),
        ])),
      ]));
  Widget _badge(IconData icon, String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
          color: const Color(0xFFD4EEE7),
          borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 17, color: studentTeal),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: studentInk, fontWeight: FontWeight.w600))
      ]));
}
