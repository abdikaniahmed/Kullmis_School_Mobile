import 'package:flutter/material.dart';

import '../models/academic_management_models.dart';
import '../models/auth_session.dart';
import '../services/laravel_api.dart';

class PromotionsScreen extends StatefulWidget {
  const PromotionsScreen({
    super.key,
    required this.api,
    required this.token,
    required this.session,
  });

  final LaravelApi api;
  final String token;
  final AuthSession session;

  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen> {
  bool _loading = true;
  bool _savingSettings = false;
  bool _runningPromotion = false;
  String? _error;

  List<AcademicYearListItem> _academicYears = const [];
  List<PromotionLevel> _levels = const [];
  AcademicYearListItem? _activeYear;
  int? _sourceYearId;
  int? _targetYearId;
  bool _setTargetActive = true;

  final List<_PromotionRuleDraft> _rules = [];

  @override
  void initState() {
    super.initState();
    _loadOverview();
  }

  Future<void> _loadOverview({bool preserveRules = false}) async {
    setState(() {
      _loading = !preserveRules;
      _error = null;
    });

    try {
      final overview = await widget.api.promotionOverview(
        token: widget.token,
        academicYearId: _sourceYearId,
      );

      if (!mounted) {
        return;
      }

      _academicYears = overview.academicYears;
      _levels = overview.levels;
      _activeYear = overview.activeAcademicYear;

      final previewId = overview.previewAcademicYearId ?? _activeYear?.id;
      _sourceYearId ??= previewId;
      final otherYears =
          _academicYears.where((year) => year.id != _sourceYearId).toList();
      _targetYearId ??= otherYears.isNotEmpty ? otherYears.first.id : null;

      if (!preserveRules) {
        _rules
          ..clear()
          ..addAll(
            overview.promotionRules.map(_PromotionRuleDraft.fromRule),
          );
      } else {
        _syncEligibleCounts(overview.promotionRules);
      }

      if (_rules.isEmpty) {
        _rules.add(_PromotionRuleDraft.empty());
      }

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
        _error = 'Unable to load promotion settings.';
      });
    }
  }

  void _syncEligibleCounts(List<PromotionRule> serverRules) {
    final counts = <String, int>{};
    for (final rule in serverRules) {
      counts[_ruleKey(rule.fromLevelId, rule.fromClassId)] = rule.eligibleCount;
    }

    for (final rule in _rules) {
      rule.eligibleCount =
          counts[_ruleKey(rule.fromLevelId, rule.fromClassId)] ?? 0;
    }
  }

  String _ruleKey(int? levelId, int? classId) {
    return '${levelId ?? 'none'}:${classId ?? 'all'}';
  }

  List<PromotionClass> _classesForLevel(int? levelId) {
    if (levelId == null) {
      return const [];
    }

    return _levels
        .firstWhere(
          (level) => level.id == levelId,
          orElse: () => const PromotionLevel(id: 0, name: '', classes: []),
        )
        .classes;
  }

  void _addRule() {
    setState(() {
      _rules.add(_PromotionRuleDraft.empty());
    });
  }

  void _removeRule(int index) {
    setState(() {
      _rules.removeAt(index);
      if (_rules.isEmpty) {
        _rules.add(_PromotionRuleDraft.empty());
      }
    });
  }

  Future<void> _saveSettings() async {
    setState(() {
      _savingSettings = true;
      _error = null;
    });

    final payload = _rules
        .where(
          (rule) =>
              rule.fromLevelId != null ||
              rule.fromClassId != null ||
              rule.toLevelId != null ||
              rule.toClassId != null ||
              rule.isGraduation,
        )
        .map((rule) => rule.toPayload())
        .toList();

    try {
      final updatedRules = await widget.api.updatePromotionSettings(
        token: widget.token,
        rules: payload,
      );

      if (!mounted) {
        return;
      }

      _syncEligibleCounts(updatedRules);

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Promotion settings saved.')),
        );

      setState(() {
        _savingSettings = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _savingSettings = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _savingSettings = false;
        _error = 'Unable to save promotion settings.';
      });
    }
  }

  Future<void> _runPromotion() async {
    if (_sourceYearId == null || _targetYearId == null) {
      setState(() {
        _error = 'Select source and target academic years.';
      });
      return;
    }

    final shouldRun = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Run Promotion'),
        content: Text(
          'Promote active students from ${_yearName(_sourceYearId)} to ${_yearName(_targetYearId)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (shouldRun != true) {
      return;
    }

    setState(() {
      _runningPromotion = true;
      _error = null;
    });

    try {
      final summary = await widget.api.runPromotion(
        token: widget.token,
        sourceAcademicYearId: _sourceYearId!,
        targetAcademicYearId: _targetYearId!,
        setTargetActive: _setTargetActive,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '${summary.processed} processed | ${summary.promoted} promoted | ${summary.graduated} graduated | ${summary.created} created | ${summary.updated} updated',
            ),
          ),
        );

      await _loadOverview();

      setState(() {
        _runningPromotion = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _runningPromotion = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _runningPromotion = false;
        _error = 'Unable to run promotion.';
      });
    }
  }

  String _yearName(int? id) {
    if (id == null) {
      return 'Selected year';
    }

    final match = _academicYears
        .where((year) => year.id == id)
        .map((year) => year.name.trim())
        .firstWhere((name) => name.isNotEmpty, orElse: () => '');

    return match.isEmpty ? 'Selected year' : match;
  }

  List<DropdownMenuItem<int>> _yearItems({int? excludeId}) {
    return _academicYears
        .where((year) => year.id != excludeId)
        .map(
          (year) => DropdownMenuItem<int>(
            value: year.id,
            child: Text(year.name),
          ),
        )
        .toList();
  }

  Widget _buildRuleCard(int index, _PromotionRuleDraft rule) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Rule ${index + 1}',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Text('${rule.eligibleCount} eligible',
                  style: theme.textTheme.bodyMedium),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _removeRule(index),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFB42318),
                ),
                child: const Text('Remove'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: rule.fromLevelId,
            decoration: const InputDecoration(
              labelText: 'From Level',
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
            onChanged: (value) async {
              setState(() {
                rule.fromLevelId = value;
                rule.fromClassId = null;
                rule.eligibleCount = 0;
              });

              await _loadOverview(preserveRules: true);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: rule.fromClassId,
            decoration: const InputDecoration(
              labelText: 'From Class',
              border: OutlineInputBorder(),
            ),
            items: _classesForLevel(rule.fromLevelId)
                .map(
                  (schoolClass) => DropdownMenuItem<int>(
                    value: schoolClass.id,
                    child: Text(schoolClass.name),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                rule.fromClassId = value;
              });
            },
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: rule.isGraduation,
            onChanged: (value) {
              setState(() {
                rule.isGraduation = value;
                if (value) {
                  rule.toLevelId = null;
                  rule.toClassId = null;
                }
              });
            },
            title: const Text('Graduate after source year'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: rule.toLevelId,
            decoration: const InputDecoration(
              labelText: 'To Level',
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
            onChanged: rule.isGraduation
                ? null
                : (value) {
                    setState(() {
                      rule.toLevelId = value;
                      rule.toClassId = null;
                    });
                  },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: rule.toClassId,
            decoration: InputDecoration(
              labelText: rule.isGraduation ? 'Result' : 'To Class',
              border: const OutlineInputBorder(),
            ),
            items: _classesForLevel(rule.toLevelId)
                .map(
                  (schoolClass) => DropdownMenuItem<int>(
                    value: schoolClass.id,
                    child: Text(schoolClass.name),
                  ),
                )
                .toList(),
            onChanged: rule.isGraduation
                ? null
                : (value) {
                    setState(() {
                      rule.toClassId = value;
                    });
                  },
          ),
        ],
      ),
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
      appBar: AppBar(title: const Text('Promotions')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text(
            'Student Promotions',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Map each level and class to the next academic year, including graduation for final classes.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active Academic Year',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  _activeYear?.name ?? 'Not set',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _sourceYearId,
                  decoration: const InputDecoration(
                    labelText: 'Source Academic Year',
                    border: OutlineInputBorder(),
                  ),
                  items: _yearItems(),
                  onChanged: (value) async {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      _sourceYearId = value;
                      if (_targetYearId == value) {
                        final options = _academicYears
                            .where((year) => year.id != value)
                            .toList();
                        _targetYearId =
                            options.isNotEmpty ? options.first.id : null;
                      }
                    });

                    await _loadOverview(preserveRules: true);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _targetYearId,
                  decoration: const InputDecoration(
                    labelText: 'Target Academic Year',
                    border: OutlineInputBorder(),
                  ),
                  items: _yearItems(excludeId: _sourceYearId),
                  onChanged: (value) {
                    setState(() {
                      _targetYearId = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _setTargetActive,
                  onChanged: (value) {
                    setState(() {
                      _setTargetActive = value;
                    });
                  },
                  title: const Text('Set target year active after promotion'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton(
                onPressed: _addRule,
                child: const Text('Add Rule'),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _savingSettings ? null : _saveSettings,
                child: Text(_savingSettings ? 'Saving...' : 'Save Settings'),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _runningPromotion ? null : _runPromotion,
                child: Text(_runningPromotion ? 'Running...' : 'Run Promotion'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFB42318),
                  ),
            ),
          const SizedBox(height: 12),
          ..._rules.asMap().entries.map(
                (entry) => _buildRuleCard(entry.key, entry.value),
              ),
        ],
      ),
    );
  }
}

class _PromotionRuleDraft {
  _PromotionRuleDraft({
    required this.key,
    required this.fromLevelId,
    required this.fromClassId,
    required this.toLevelId,
    required this.toClassId,
    required this.isGraduation,
    required this.eligibleCount,
  });

  final String key;
  int? fromLevelId;
  int? fromClassId;
  int? toLevelId;
  int? toClassId;
  bool isGraduation;
  int eligibleCount;

  factory _PromotionRuleDraft.fromRule(PromotionRule rule) {
    return _PromotionRuleDraft(
      key: DateTime.now().microsecondsSinceEpoch.toString(),
      fromLevelId: rule.fromLevelId,
      fromClassId: rule.fromClassId,
      toLevelId: rule.toLevelId,
      toClassId: rule.toClassId,
      isGraduation: rule.isGraduation,
      eligibleCount: rule.eligibleCount,
    );
  }

  factory _PromotionRuleDraft.empty() {
    return _PromotionRuleDraft(
      key: DateTime.now().microsecondsSinceEpoch.toString(),
      fromLevelId: null,
      fromClassId: null,
      toLevelId: null,
      toClassId: null,
      isGraduation: false,
      eligibleCount: 0,
    );
  }

  Map<String, dynamic> toPayload() {
    return {
      'from_level_id': fromLevelId,
      'from_class_id': fromClassId,
      'to_level_id': isGraduation ? null : toLevelId,
      'to_class_id': isGraduation ? null : toClassId,
      'is_graduation': isGraduation,
    };
  }
}
