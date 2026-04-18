import 'package:flutter/material.dart';

import '../models/settings_models.dart';
import '../services/laravel_api.dart';

class GradeSetupScreen extends StatefulWidget {
  const GradeSetupScreen({
    super.key,
    required this.api,
    required this.token,
  });

  final LaravelApi api;
  final String token;

  @override
  State<GradeSetupScreen> createState() => _GradeSetupScreenState();
}

class _GradeSetupScreenState extends State<GradeSetupScreen> {
  final List<_GradeRuleDraft> _rules = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  @override
  void dispose() {
    for (final rule in _rules) {
      rule.dispose();
    }
    super.dispose();
  }

  Future<void> _loadRules() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rules = await widget.api.gradeSetup(token: widget.token);

      if (!mounted) {
        return;
      }

      setState(() {
        _rules
          ..clear()
          ..addAll(
            rules.map(
              (rule) => _GradeRuleDraft(
                label: rule.label,
                minScore: rule.minScore.toString(),
              ),
            ),
          );
        if (_rules.isEmpty) {
          _rules.add(_GradeRuleDraft());
        }
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
        _error = 'Unable to load grade setup.';
      });
    }
  }

  void _addRule() {
    setState(() {
      _rules.add(_GradeRuleDraft());
    });
  }

  void _removeRule(int index) {
    setState(() {
      _rules[index].dispose();
      _rules.removeAt(index);
    });
  }

  Future<void> _saveRules() async {
    final normalized = <GradeRule>[];

    for (final rule in _rules) {
      final label = rule.labelController.text.trim();
      if (label.isEmpty) {
        continue;
      }

      final score = double.tryParse(rule.minScoreController.text.trim());
      if (score == null || score < 0 || score > 100) {
        setState(() {
          _error = 'Each rule must have a score between 0 and 100.';
        });
        return;
      }

      normalized.add(GradeRule(label: label, minScore: score));
    }

    if (normalized.isEmpty) {
      setState(() {
        _error = 'Add at least one grade rule.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final updated = await widget.api.updateGradeSetup(
        token: widget.token,
        rules: normalized,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _rules
          ..clear()
          ..addAll(
            updated.map(
              (rule) => _GradeRuleDraft(
                label: rule.label,
                minScore: rule.minScore.toString(),
              ),
            ),
          );
        _saving = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Grade setup updated.')),
        );
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
        _error = 'Unable to update grade setup.';
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

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Grade Setup')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          ..._rules.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: entry.value.labelController,
                          decoration: const InputDecoration(
                            labelText: 'Grade',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: entry.value.minScoreController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Min score',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _rules.length <= 1 || _saving
                            ? null
                            : () => _removeRule(entry.key),
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Remove rule',
                      ),
                    ],
                  ),
                ),
              ),
          TextButton.icon(
            onPressed: _saving ? null : _addRule,
            icon: const Icon(Icons.add),
            label: const Text('Add rule'),
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
          FilledButton(
            onPressed: _saving ? null : _saveRules,
            child: Text(_saving ? 'Saving...' : 'Save changes'),
          ),
        ],
      ),
    );
  }
}

class _GradeRuleDraft {
  _GradeRuleDraft({String? label, String? minScore})
      : labelController = TextEditingController(text: label),
        minScoreController = TextEditingController(text: minScore);

  final TextEditingController labelController;
  final TextEditingController minScoreController;

  void dispose() {
    labelController.dispose();
    minScoreController.dispose();
  }
}
