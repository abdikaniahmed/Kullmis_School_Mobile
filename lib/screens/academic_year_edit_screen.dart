import 'package:flutter/material.dart';

import '../services/laravel_api.dart';

class AcademicYearEditScreen extends StatefulWidget {
  const AcademicYearEditScreen({
    super.key,
    required this.api,
    required this.token,
    required this.yearId,
  });

  final LaravelApi api;
  final String token;
  final int yearId;

  @override
  State<AcademicYearEditScreen> createState() => _AcademicYearEditScreenState();
}

class _AcademicYearEditScreenState extends State<AcademicYearEditScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadYear();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  Future<void> _loadYear() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final year = await widget.api.academicYearDetail(
        token: widget.token,
        yearId: widget.yearId,
      );

      if (!mounted) {
        return;
      }

      _nameController.text = year.name;
      _startDateController.text = year.startDate ?? '';
      _endDateController.text = year.endDate ?? '';

      setState(() {
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
        _error = 'Unable to load academic year.';
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

    try {
      await widget.api.updateAcademicYear(
        token: widget.token,
        yearId: widget.yearId,
        payload: {
          'name': name,
          'start_date': _startDateController.text.trim().isEmpty
              ? null
              : _startDateController.text.trim(),
          'end_date': _endDateController.text.trim().isEmpty
              ? null
              : _endDateController.text.trim(),
        },
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Academic year updated.')),
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
        _error = 'Unable to update academic year.';
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
      appBar: AppBar(title: const Text('Edit Academic Year')),
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
