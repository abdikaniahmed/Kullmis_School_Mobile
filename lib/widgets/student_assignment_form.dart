import 'package:flutter/material.dart';

import '../models/fee_models.dart';
import '../models/main_attendance_models.dart';
import '../models/student_management_models.dart';
import '../services/laravel_api.dart';

class StudentAssignmentForm extends StatefulWidget {
  const StudentAssignmentForm({
    super.key,
    required this.api,
    required this.token,
    required this.studentId,
  });

  final LaravelApi api;
  final String token;
  final int studentId;

  @override
  State<StudentAssignmentForm> createState() => _StudentAssignmentFormState();
}

class _StudentAssignmentFormState extends State<StudentAssignmentForm> {
  List<AcademicYearOption> _years = const [];
  List<MainAttendanceLevel> _levels = const [];
  List<MainAttendanceClass> _classes = const [];
  List<StudentOptionalFee> _optionalFees = const [];
  List<int> _selectedOptionalFeeIds = const [];

  int? _assignmentId;
  int? _academicYearId;
  int? _levelId;
  int? _classId;
  final TextEditingController _rollNumberController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _feesLoading = false;
  bool _feesSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSetup();
  }

  @override
  void dispose() {
    _rollNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadSetup() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        widget.api.academicYears(widget.token),
        widget.api.attendanceLevels(widget.token),
        widget.api.schoolClasses(token: widget.token, includeAll: true),
        widget.api.studentDetail(
          token: widget.token,
          studentId: widget.studentId,
        ),
      ]);

      final years = results[0] as List<AcademicYearOption>;
      final levels = results[1] as List<MainAttendanceLevel>;
      final classes = results[2] as List<MainAttendanceClass>;
      final student = results[3] as StudentProfile;
      final currentYear = student.currentYear;

      if (!mounted) {
        return;
      }

      setState(() {
        _years = years;
        _levels = levels;
        _classes = classes;
        _assignmentId = currentYear?.id;
        _academicYearId = currentYear?.academicYearId;
        _levelId = currentYear?.levelId;
        _classId = currentYear?.classId;
        _rollNumberController.text = currentYear?.rollNumber ?? '';
        _loading = false;
      });

      if (_assignmentId != null) {
        await _loadOptionalFees();
      }
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
        _error = 'Unable to load student assignment data.';
      });
    }
  }

  List<MainAttendanceClass> get _filteredClasses {
    final levelId = _levelId;
    if (levelId == null) {
      return _classes;
    }

    return _classes.where((entry) => entry.levelId == levelId).toList();
  }

  Future<void> _loadOptionalFees() async {
    final assignmentId = _assignmentId;
    if (assignmentId == null) {
      return;
    }

    setState(() {
      _feesLoading = true;
    });

    try {
      final response = await widget.api.studentOptionalFees(
        token: widget.token,
        assignmentId: assignmentId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _optionalFees = response.fees;
        _selectedOptionalFeeIds = response.assignedFeeIds;
        _feesLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _feesLoading = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _feesLoading = false;
        _error = 'Unable to load optional fees.';
      });
    }
  }

  Future<void> _saveAssignment() async {
    final academicYearId = _academicYearId;
    final levelId = _levelId;
    final classId = _classId;

    if (academicYearId == null || levelId == null || classId == null) {
      setState(() {
        _error = 'Select an academic year, level, and class first.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (_assignmentId == null) {
        final assignment = await widget.api.createStudentAssignment(
          token: widget.token,
          payload: {
            'student_id': widget.studentId,
            'academic_year_id': academicYearId,
            'level_id': levelId,
            'school_class_id': classId,
            'roll_number': _rollNumberController.text.trim().isEmpty
                ? null
                : _rollNumberController.text.trim(),
          },
        );

        if (!mounted) {
          return;
        }

        setState(() {
          _assignmentId = assignment.id;
          _saving = false;
        });

        await _loadOptionalFees();
      } else {
        await widget.api.updateStudentAssignment(
          token: widget.token,
          assignmentId: _assignmentId!,
          payload: {
            'level_id': levelId,
            'school_class_id': classId,
            'roll_number': _rollNumberController.text.trim().isEmpty
                ? null
                : _rollNumberController.text.trim(),
          },
        );

        if (!mounted) {
          return;
        }

        setState(() {
          _saving = false;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Assignment saved.')),
          );
      }
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
        _error = 'Unable to save assignment.';
      });
    }
  }

  Future<void> _saveOptionalFees() async {
    final assignmentId = _assignmentId;
    if (assignmentId == null) {
      return;
    }

    setState(() {
      _feesSaving = true;
    });

    try {
      await widget.api.syncStudentOptionalFees(
        token: widget.token,
        assignmentId: assignmentId,
        feeIds: _selectedOptionalFeeIds,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _feesSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Optional fees updated.')),
          );
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _feesSaving = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _feesSaving = false;
        _error = 'Unable to update optional fees.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Academic Assignment', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            value: _academicYearId,
            decoration: const InputDecoration(
              labelText: 'Academic Year',
              border: OutlineInputBorder(),
            ),
            items: _years
                .map(
                  (year) => DropdownMenuItem(
                    value: year.id,
                    child: Text(year.name),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                _academicYearId = value;
              });
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(
            value: _levelId,
            decoration: const InputDecoration(
              labelText: 'Level',
              border: OutlineInputBorder(),
            ),
            items: _levels
                .map(
                  (level) => DropdownMenuItem(
                    value: level.id,
                    child: Text(level.name),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                _levelId = value;
                _classId = null;
              });
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(
            value: _classId,
            decoration: const InputDecoration(
              labelText: 'Class',
              border: OutlineInputBorder(),
            ),
            items: _filteredClasses
                .map(
                  (schoolClass) => DropdownMenuItem(
                    value: schoolClass.id,
                    child: Text(schoolClass.name),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                _classId = value;
              });
            },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _rollNumberController,
            decoration: const InputDecoration(
              labelText: 'Roll Number',
              hintText: 'Leave blank to auto-generate',
              border: OutlineInputBorder(),
            ),
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
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _saving ? null : _saveAssignment,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Assignment'),
            ),
          ),
          if (_assignmentId != null) ...[
            const SizedBox(height: 20),
            Text('Optional Fees', style: theme.textTheme.titleLarge),
            const SizedBox(height: 10),
            if (_feesLoading)
              const Center(child: CircularProgressIndicator())
            else if (_optionalFees.isEmpty)
              Text(
                'No optional fees available for this class.',
                style: theme.textTheme.bodyMedium,
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _optionalFees
                    .map(
                      (fee) => FilterChip(
                        label: Text(fee.name),
                        selected: _selectedOptionalFeeIds.contains(fee.id),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedOptionalFeeIds = [
                                ..._selectedOptionalFeeIds,
                                fee.id,
                              ];
                            } else {
                              _selectedOptionalFeeIds = _selectedOptionalFeeIds
                                  .where((id) => id != fee.id)
                                  .toList();
                            }
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: _feesSaving ? null : _saveOptionalFees,
                child: _feesSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Optional Fees'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
