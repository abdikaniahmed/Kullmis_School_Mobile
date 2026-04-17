import 'package:flutter/material.dart';

import '../models/fee_models.dart';
import '../services/laravel_api.dart';

class TermCreateScreen extends StatefulWidget {
  const TermCreateScreen({
    super.key,
    required this.api,
    required this.token,
  });

  final LaravelApi api;
  final String token;

  @override
  State<TermCreateScreen> createState() => _TermCreateScreenState();
}

class _TermCreateScreenState extends State<TermCreateScreen> {
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
    _loadMeta();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        widget.api.academicYears(widget.token),
        widget.api.termCreateMeta(token: widget.token),
      ]);

      final years = results[0] as List<AcademicYearOption>;
      final activeId = results[1] as int?;

      if (!mounted) {
        return;
      }

      setState(() {
        _academicYears = years;
        _academicYearId = years.any((year) => year.id == activeId)
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
        _error = 'Unable to load term setup.';
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
      await widget.api.createTerm(
        token: widget.token,
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
          const SnackBar(content: Text('Term created successfully.')),
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
        _error = 'Unable to create term.';
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
      appBar: AppBar(title: const Text('Add Term')),
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
            child: Text(_saving ? 'Saving...' : 'Create'),
          ),
        ],
      ),
    );
  }
}
