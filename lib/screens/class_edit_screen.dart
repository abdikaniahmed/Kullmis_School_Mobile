import 'package:flutter/material.dart';

import '../models/academic_management_models.dart';
import '../models/main_attendance_models.dart';
import '../services/laravel_api.dart';

class ClassEditScreen extends StatefulWidget {
  const ClassEditScreen({
    super.key,
    required this.api,
    required this.token,
    required this.classId,
  });

  final LaravelApi api;
  final String token;
  final int classId;

  @override
  State<ClassEditScreen> createState() => _ClassEditScreenState();
}

class _ClassEditScreenState extends State<ClassEditScreen> {
  final TextEditingController _orderController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _sectionController = TextEditingController();

  List<MainAttendanceLevel> _levels = const [];
  int? _levelId;
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
    _orderController.dispose();
    _nameController.dispose();
    _sectionController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        widget.api.attendanceLevels(widget.token),
        widget.api.classDetail(token: widget.token, classId: widget.classId),
      ]);

      final levels = results[0] as List<MainAttendanceLevel>;
      final schoolClass = results[1] as ClassListItem;

      if (!mounted) {
        return;
      }

      setState(() {
        _levels = levels;
        _levelId = schoolClass.levelId;
        _orderController.text = schoolClass.order?.toString() ?? '';
        _nameController.text = schoolClass.name;
        _sectionController.text = schoolClass.section ?? '';
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
        _error = 'Unable to load class.';
      });
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      setState(() {
        _error = 'Class name is required.';
      });
      return;
    }

    if (_levelId == null) {
      setState(() {
        _error = 'Select a level.';
      });
      return;
    }

    final order = int.tryParse(_orderController.text.trim());

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.api.updateClass(
        token: widget.token,
        classId: widget.classId,
        payload: {
          'order_n': order,
          'name': name,
          'level_id': _levelId,
          'section': _sectionController.text.trim().isEmpty
              ? null
              : _sectionController.text.trim(),
        },
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Class updated.')),
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
        _error = 'Unable to update class.';
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
      appBar: AppBar(title: const Text('Edit Class')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          TextField(
            controller: _orderController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Order Number',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Class Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _levelId,
            decoration: const InputDecoration(
              labelText: 'Level',
              border: OutlineInputBorder(),
            ),
            items: _levels
                .map(
                  (level) => DropdownMenuItem<int>(
                    value: level.id,
                    child: Text(level.name),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                _levelId = value;
              });
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sectionController,
            decoration: const InputDecoration(
              labelText: 'Section (Optional)',
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
