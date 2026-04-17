import 'package:flutter/material.dart';

import '../models/academic_management_models.dart';
import '../models/fee_models.dart';
import '../services/laravel_api.dart';

class TermEditScreen extends StatefulWidget {
  const TermEditScreen({
    super.key,
    required this.api,
    required this.token,
    required this.termId,
  });

  final LaravelApi api;
  final String token;
  final int termId;

  @override
  State<TermEditScreen> createState() => _TermEditScreenState();
}

class _TermEditScreenState extends State<TermEditScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  List<AcademicYearOption> _academicYears = const [];
  int? _academicYearId;
  bool _isActive = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        widget.api.academicYears(widget.token),
        widget.api.termDetail(token: widget.token, termId: widget.termId),
      ]);

      final years = results[0] as List<AcademicYearOption>;
      final term = results[1] as TermListItem;

      if (!mounted) {
        return;
      }

      setState(() {
        _academicYears = years;
        _academicYearId = term.academicYearId;
        _nameController.text = term.name;
        _startDateController.text = term.startDate ?? '';
        _endDateController.text = term.endDate ?? '';
        _isActive = term.isActive;
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
        _error = 'Unable to load term.';
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
    if (_academicYearId == null) {
      setState(() {
        _error = 'Select an academic year.';
      });
      return;
    }

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _error = 'Term name is required.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.api.updateTerm(
        token: widget.token,
        termId: widget.termId,
        payload: {
          'academic_year_id': _academicYearId,
          'name': name,
          'start_date': _startDateController.text.trim().isEmpty
              ? null
              : _startDateController.text.trim(),
          'end_date': _endDateController.text.trim().isEmpty
              ? null
              : _endDateController.text.trim(),
          'is_active': _isActive,
        },
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Term updated successfully.')),
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
        _error = 'Unable to update term.';
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
      appBar: AppBar(title: const Text('Edit Term')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          DropdownButtonFormField<int>(
            value: _academicYearId,
            decoration: const InputDecoration(
              labelText: 'Academic Year',
              border: OutlineInputBorder(),
            ),
            items: _academicYears
                .map(
                  (year) => DropdownMenuItem<int>(
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
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Term Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          _buildDateField(
              label: 'Start Date', controller: _startDateController),
          const SizedBox(height: 12),
          _buildDateField(label: 'End Date', controller: _endDateController),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _isActive,
            onChanged: (value) {
              setState(() {
                _isActive = value;
              });
            },
            title: const Text('Active Term'),
            contentPadding: EdgeInsets.zero,
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
            child: Text(_saving ? 'Saving...' : 'Update'),
          ),
        ],
      ),
    );
  }
}
