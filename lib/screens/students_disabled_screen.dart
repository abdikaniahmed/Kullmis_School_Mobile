import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/main_attendance_models.dart';
import '../models/student_management_models.dart';
import '../services/laravel_api.dart';

class StudentsDisabledScreen extends StatefulWidget {
  const StudentsDisabledScreen({
    super.key,
    required this.api,
    required this.token,
    required this.session,
  });

  final LaravelApi api;
  final String token;
  final AuthSession session;

  @override
  State<StudentsDisabledScreen> createState() => _StudentsDisabledScreenState();
}

class _StudentsDisabledScreenState extends State<StudentsDisabledScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<MainAttendanceLevel> _levels = const [];
  List<MainAttendanceClass> _classes = const [];
  DisabledStudentPage? _page;
  int? _selectedLevelId;
  int? _selectedClassId;
  bool _loadingMeta = true;
  bool _loadingClasses = false;
  bool _loadingList = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    setState(() {
      _loadingMeta = true;
      _error = null;
    });

    try {
      final levels = await widget.api.attendanceLevels(widget.token);

      if (!mounted) {
        return;
      }

      setState(() {
        _levels = levels;
        _loadingMeta = false;
      });

      await _loadDisabledStudents(page: 1);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingMeta = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingMeta = false;
        _error = 'Unable to load disabled student setup.';
      });
    }
  }

  Future<void> _loadClasses() async {
    final levelId = _selectedLevelId;

    if (levelId == null) {
      setState(() {
        _classes = const [];
        _selectedClassId = null;
      });
      return;
    }

    setState(() {
      _loadingClasses = true;
    });

    try {
      final classes = await widget.api.attendanceClasses(
        token: widget.token,
        levelId: levelId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _classes = classes;
        _selectedClassId = classes.any((entry) => entry.id == _selectedClassId)
            ? _selectedClassId
            : null;
        _loadingClasses = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _classes = const [];
        _selectedClassId = null;
        _loadingClasses = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _classes = const [];
        _selectedClassId = null;
        _loadingClasses = false;
        _error = 'Unable to load classes for the selected level.';
      });
    }
  }

  Future<void> _loadDisabledStudents({int page = 1}) async {
    setState(() {
      _loadingList = true;
      _error = null;
    });

    try {
      final result = await widget.api.disabledStudents(
        token: widget.token,
        page: page,
        search: _searchController.text.trim(),
        levelId: _selectedLevelId,
        classId: _selectedClassId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _page = result;
        _loadingList = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _page = null;
        _loadingList = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _page = null;
        _loadingList = false;
        _error = 'Unable to load disabled students.';
      });
    }
  }

  Future<void> _applyLevel(int? value) async {
    setState(() {
      _selectedLevelId = value;
      _selectedClassId = null;
      _classes = const [];
    });

    await _loadClasses();
    await _loadDisabledStudents(page: 1);
  }

  Future<void> _clearFilters() async {
    _searchController.clear();

    setState(() {
      _selectedLevelId = null;
      _selectedClassId = null;
      _classes = const [];
    });

    await _loadDisabledStudents(page: 1);
  }

  Future<void> _openActivateDialog(DisabledStudentItem item) async {
    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Activate Student'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Reason for activation',
              border: OutlineInputBorder(),
            ),
            minLines: 2,
            maxLines: 4,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Activate'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final reason = controller.text.trim();
    if (reason.isEmpty) {
      _showMessage('Provide an activation reason.');
      return;
    }

    try {
      await widget.api.activateStudent(
        token: widget.token,
        studentId: item.id,
        reason: reason,
      );

      if (!mounted) {
        return;
      }

      _showMessage('Student activated successfully.');
      await _loadDisabledStudents(page: _page?.currentPage ?? 1);
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Unable to activate student.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final page = _page;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Disabled Students'),
      ),
      body: _loadingMeta
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadDisabledStudents(page: 1),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Find disabled students',
                            style: theme.textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text(
                          'Search by name, phone, level, or class.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: _searchController,
                          textInputAction: TextInputAction.search,
                          decoration: const InputDecoration(
                            labelText: 'Search disabled students',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.search),
                          ),
                          onSubmitted: (_) => _loadDisabledStudents(page: 1),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<int>(
                          value: _selectedLevelId,
                          decoration: const InputDecoration(
                            labelText: 'Level',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<int>(
                              value: null,
                              child: Text('All Levels'),
                            ),
                            ..._levels.map(
                              (level) => DropdownMenuItem<int>(
                                value: level.id,
                                child: Text(level.name),
                              ),
                            ),
                          ],
                          onChanged: _loadingClasses
                              ? null
                              : (value) async {
                                  await _applyLevel(value);
                                },
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<int>(
                          value: _selectedClassId,
                          decoration: const InputDecoration(
                            labelText: 'Class',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<int>(
                              value: null,
                              child: Text('All Classes'),
                            ),
                            ..._classes.map(
                              (schoolClass) => DropdownMenuItem<int>(
                                value: schoolClass.id,
                                child: Text(schoolClass.name),
                              ),
                            ),
                          ],
                          onChanged: _loadingClasses
                              ? null
                              : (value) async {
                                  setState(() {
                                    _selectedClassId = value;
                                  });
                                  await _loadDisabledStudents(page: 1);
                                },
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            FilledButton.icon(
                              onPressed: _loadingList
                                  ? null
                                  : () => _loadDisabledStudents(page: 1),
                              icon: const Icon(Icons.search),
                              label: const Text('Search'),
                            ),
                            OutlinedButton(
                              onPressed: _loadingList ? null : _clearFilters,
                              child: const Text('Clear'),
                            ),
                          ],
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _error!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFFB42318),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_loadingList)
                    const Center(child: CircularProgressIndicator())
                  else if (page == null || page.items.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(
                        'No disabled students found.',
                        style: theme.textTheme.bodyLarge,
                      ),
                    )
                  else ...[
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Disabled Students',
                              style: theme.textTheme.titleLarge),
                          const SizedBox(height: 4),
                          Text(
                            'Showing ${page.from ?? 0} - ${page.to ?? 0} of ${page.total}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...page.items.map(_buildStudentCard),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: page.hasPreviousPage && !_loadingList
                                ? () => _loadDisabledStudents(
                                    page: page.currentPage - 1)
                                : null,
                            child: const Text('Prev'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: page.hasNextPage && !_loadingList
                                ? () => _loadDisabledStudents(
                                    page: page.currentPage + 1)
                                : null,
                            child: const Text('Next'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildStudentCard(DisabledStudentItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2933),
              ),
            ),
            const SizedBox(height: 10),
            _DetailRow(
              label: 'Level',
              value: item.currentYear?.levelName ?? '—',
            ),
            _DetailRow(
              label: 'Class',
              value: item.currentYear?.className ?? '—',
            ),
            _DetailRow(label: 'Phone', value: item.phone ?? '-'),
            _DetailRow(label: 'Reason', value: item.disableReason ?? '-'),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: () => _openActivateDialog(item),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Activate'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}
