import 'package:flutter/material.dart';

import '../models/fee_models.dart';
import '../services/laravel_api.dart';

class AcademicYearCreateScreen extends StatefulWidget {
  const AcademicYearCreateScreen({
    super.key,
    required this.api,
    required this.token,
  });

  final LaravelApi api;
  final String token;

  @override
  State<AcademicYearCreateScreen> createState() =>
      _AcademicYearCreateScreenState();
}

class _AcademicYearCreateScreenState extends State<AcademicYearCreateScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  List<AcademicYearOption> _sourceYears = const [];
  int? _sourceYearId;
  bool _carryForward = false;
  bool _copyTermStructure = false;
  bool _copyFeeStructure = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSources();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  Future<void> _loadSources() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        widget.api.academicYears(widget.token),
        widget.api.activeAcademicYear(widget.token),
      ]);

      final years = results[0] as List<AcademicYearOption>;
      final activeId = (results[1] as dynamic).id as int?;

      if (!mounted) {
        return;
      }

      setState(() {
        _sourceYears = years;
        _sourceYearId = years.any((year) => year.id == activeId)
            ? activeId
            : (years.isNotEmpty ? years.first.id : null);
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
        _error = 'Unable to load academic year setup.';
      });
    }
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(controller.text) ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      controller.text = picked.toIso8601String().split('T').first;
    });
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      setState(() {
        _error = 'Academic year name is required.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final payload = <String, dynamic>{
      'name': name,
      'start_date': _startDateController.text.trim().isEmpty
          ? null
          : _startDateController.text.trim(),
      'end_date': _endDateController.text.trim().isEmpty
          ? null
          : _endDateController.text.trim(),
      'carry_forward_students': _carryForward,
      'copy_term_structure': _copyTermStructure,
      'copy_fee_structure': _copyFeeStructure,
    };

    if (_copyTermStructure || _copyFeeStructure) {
      payload['source_academic_year_id'] = _sourceYearId;
    }

    try {
      await widget.api.createAcademicYear(
        token: widget.token,
        payload: payload,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Academic year created.')),
        );

      Navigator.of(context).pop(true);
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
        _error = 'Unable to create academic year.';
      });
    }
  }

  Widget _buildDateField({
    required String label,
    required TextEditingController controller,
  }) {
    return TextField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.calendar_today),
      ),
      onTap: () => _pickDate(controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Add Academic Year')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Academic Year Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          _buildDateField(
              label: 'Start Date', controller: _startDateController),
          const SizedBox(height: 12),
          _buildDateField(label: 'End Date', controller: _endDateController),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New Year Setup',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Reuse the current school structure instead of creating terms and exams again.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: _carryForward,
                  onChanged: (value) {
                    setState(() {
                      _carryForward = value ?? false;
                    });
                  },
                  title: const Text('Carry forward active students.'),
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  value: _copyTermStructure,
                  onChanged: (value) {
                    setState(() {
                      _copyTermStructure = value ?? false;
                      if (!_copyTermStructure && !_copyFeeStructure) {
                        _sourceYearId = _sourceYears.isNotEmpty
                            ? _sourceYears.first.id
                            : null;
                      }
                    });
                  },
                  title: const Text('Copy terms and exams from another year.'),
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  value: _copyFeeStructure,
                  onChanged: (value) {
                    setState(() {
                      _copyFeeStructure = value ?? false;
                      if (!_copyTermStructure && !_copyFeeStructure) {
                        _sourceYearId = _sourceYears.isNotEmpty
                            ? _sourceYears.first.id
                            : null;
                      }
                    });
                  },
                  title: const Text('Copy fee structures from another year.'),
                  contentPadding: EdgeInsets.zero,
                ),
                if (_copyTermStructure || _copyFeeStructure) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: _sourceYearId,
                    decoration: const InputDecoration(
                      labelText: 'Copy From Academic Year',
                      border: OutlineInputBorder(),
                    ),
                    items: _sourceYears
                        .map(
                          (year) => DropdownMenuItem<int>(
                            value: year.id,
                            child: Text(year.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _sourceYearId = value;
                      });
                    },
                  ),
                ],
              ],
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
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: Text(_saving ? 'Saving...' : 'Create'),
          ),
        ],
      ),
    );
  }
}
