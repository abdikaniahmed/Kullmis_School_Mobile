import 'package:flutter/material.dart';

import '../models/academic_management_models.dart';
import '../models/exam_models.dart';
import '../services/laravel_api.dart';

class LevelEditScreen extends StatefulWidget {
  const LevelEditScreen({
    super.key,
    required this.api,
    required this.token,
    required this.levelId,
  });

  final LaravelApi api;
  final String token;
  final int levelId;

  @override
  State<LevelEditScreen> createState() => _LevelEditScreenState();
}

class _LevelEditScreenState extends State<LevelEditScreen> {
  final TextEditingController _orderController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  List<ExamSubjectOption> _subjects = const [];
  final Set<int> _selectedSubjectIds = {};
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
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        widget.api.subjects(token: widget.token),
        widget.api.levelDetail(token: widget.token, levelId: widget.levelId),
      ]);

      final subjects = results[0] as List<ExamSubjectOption>;
      final level = results[1] as LevelListItem;

      if (!mounted) {
        return;
      }

      _selectedSubjectIds
        ..clear()
        ..addAll(level.subjects.map((subject) => subject.id));

      setState(() {
        _subjects = subjects;
        _orderController.text = level.order?.toString() ?? '';
        _nameController.text = level.name;
        _descriptionController.text = level.description ?? '';
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
        _error = 'Unable to load level.';
      });
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      setState(() {
        _error = 'Level name is required.';
      });
      return;
    }

    final order = int.tryParse(_orderController.text.trim());

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.api.updateLevel(
        token: widget.token,
        levelId: widget.levelId,
        payload: {
          'order_n': order,
          'name': name,
          'description': _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          'subject_ids': _selectedSubjectIds.toList(),
        },
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Level updated.')),
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
        _error = 'Unable to update level.';
      });
    }
  }

  void _toggleSubject(int id) {
    setState(() {
      if (_selectedSubjectIds.contains(id)) {
        _selectedSubjectIds.remove(id);
      } else {
        _selectedSubjectIds.add(id);
      }
    });
  }

  Widget _buildSubjects() {
    if (_subjects.isEmpty) {
      return const Text('No subjects available.');
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _subjects
          .map(
            (subject) => FilterChip(
              label: Text(subject.name),
              selected: _selectedSubjectIds.contains(subject.id),
              onSelected: (_) => _toggleSubject(subject.id),
            ),
          )
          .toList(),
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
      appBar: AppBar(title: const Text('Edit Level')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          TextField(
            controller: _orderController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Order (display)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Level Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text('Subjects', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _buildSubjects(),
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
