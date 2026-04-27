import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/main_attendance_models.dart';
import '../models/student_list_models.dart';
import '../services/laravel_api.dart';
import '../services/offline_cache_store.dart';
import 'exam_report_screen.dart';
import 'student_detail_screen.dart';
import 'students_create_screen.dart';
import 'students_edit_screen.dart';
import 'students_upload_screen.dart';

class StudentListScreen extends StatefulWidget {
  const StudentListScreen({
    super.key,
    required this.api,
    required this.token,
    required this.session,
  });

  final LaravelApi api;
  final String token;
  final AuthSession session;

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final OfflineCacheStore _cacheStore = const FileOfflineCacheStore();

  List<MainAttendanceLevel> _levels = const [];
  List<MainAttendanceClass> _classes = const [];
  StudentListPage? _page;
  int? _selectedLevelId;
  int? _selectedClassId;
  bool _loadingMeta = true;
  bool _loadingClasses = false;
  bool _loadingList = false;
  bool _usingOfflineData = false;
  String? _statusMessage;
  String? _error;

  bool get _canCreate => widget.session.hasPermission('students.create');
  bool get _canEdit => widget.session.hasPermission('students.edit');
  bool get _canDelete => widget.session.hasPermission('students.delete');
  bool get _canViewMarks => widget.session.hasPermission('marks.view');

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
      _statusMessage = null;
    });

    try {
      final levels = await widget.api.attendanceLevels(widget.token);

      if (!mounted) {
        return;
      }

      setState(() {
        _levels = levels;
        _loadingMeta = false;
        _usingOfflineData = false;
      });

      await _loadStudents(page: 1);
    } on ApiException catch (error) {
      final restored = await _restoreCachedSnapshot(
        fallbackMessage: 'Offline mode: showing last synced student list.',
      );
      if (restored) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _loadingMeta = false;
        _error = error.message;
      });
    } catch (_) {
      final restored = await _restoreCachedSnapshot(
        fallbackMessage: 'Offline mode: showing last synced student list.',
      );
      if (restored) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _loadingMeta = false;
        _error = 'Unable to load student list setup.';
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

  Future<void> _loadStudents({int page = 1}) async {
    setState(() {
      _loadingList = true;
      _error = null;
      _statusMessage = null;
    });

    try {
      final studentPage = await widget.api.studentList(
        token: widget.token,
        page: page,
        search: _searchController.text.trim(),
        levelId: _selectedLevelId,
        classId: _selectedClassId,
      );

      if (!mounted) {
        return;
      }

      await _writeSnapshot(studentPage);

      setState(() {
        _page = studentPage;
        _loadingList = false;
        _usingOfflineData = false;
      });
    } on ApiException catch (error) {
      final restored = await _restoreCachedSnapshot(
        fallbackMessage: 'Offline mode: showing last synced student list.',
      );
      if (restored) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _page = null;
        _loadingList = false;
        _error = error.message;
      });
    } catch (_) {
      final restored = await _restoreCachedSnapshot(
        fallbackMessage: 'Offline mode: showing last synced student list.',
      );
      if (restored) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _page = null;
        _loadingList = false;
        _error = 'Unable to load students.';
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
    await _loadStudents(page: 1);
  }

  Future<void> _clearFilters() async {
    _searchController.clear();

    setState(() {
      _selectedLevelId = null;
      _selectedClassId = null;
      _classes = const [];
    });

    await _loadStudents(page: 1);
  }

  Future<bool> _restoreCachedSnapshot({
    required String fallbackMessage,
  }) async {
    final json = await _cacheStore.readCacheDocument(_studentListCacheKey);
    if (json == null) {
      return false;
    }

    final snapshot = StudentListCacheSnapshot.fromJson(
      json,
      levelDecoder: (items) => items
          .whereType<Map<String, dynamic>>()
          .map(MainAttendanceLevel.fromJson)
          .toList(),
      classDecoder: (items) => items
          .whereType<Map<String, dynamic>>()
          .map(MainAttendanceClass.fromJson)
          .toList(),
    );

    final currentSearch = _searchController.text.trim();
    final filtersMatch = snapshot.search == currentSearch &&
        snapshot.selectedLevelId == _selectedLevelId &&
        snapshot.selectedClassId == _selectedClassId;

    if (!filtersMatch && _page != null) {
      return false;
    }

    if (!mounted) {
      return true;
    }

    _searchController.text = snapshot.search;

    setState(() {
      _levels = snapshot.levels.cast<MainAttendanceLevel>();
      _classes = snapshot.classes.cast<MainAttendanceClass>();
      _page = snapshot.page;
      _selectedLevelId = snapshot.selectedLevelId;
      _selectedClassId = snapshot.selectedClassId;
      _loadingMeta = false;
      _loadingClasses = false;
      _loadingList = false;
      _usingOfflineData = true;
      _statusMessage = fallbackMessage;
      _error = null;
    });

    return true;
  }

  Future<void> _writeSnapshot(StudentListPage page) async {
    await _cacheStore.writeCacheDocument(
      _studentListCacheKey,
      StudentListCacheSnapshot(
        page: page,
        levels: _levels,
        classes: _classes,
        search: _searchController.text.trim(),
        selectedLevelId: _selectedLevelId,
        selectedClassId: _selectedClassId,
      ).toJson(
        levels: _levels.map((level) => level.toJson()).toList(),
        classes: _classes.map((schoolClass) => schoolClass.toJson()).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final page = _page;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student List'),
      ),
      body: _loadingMeta
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadStudents(page: 1),
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
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Students',
                                style: theme.textTheme.titleLarge,
                              ),
                            ),
                            if (_canCreate)
                              Wrap(
                                spacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => StudentsUploadScreen(
                                            api: widget.api,
                                            token: widget.token,
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.upload_file),
                                    label: const Text('Upload'),
                                  ),
                                  FilledButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => StudentsCreateScreen(
                                            api: widget.api,
                                            token: widget.token,
                                            session: widget.session,
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.person_add_alt_1),
                                    label: const Text('Add Student'),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Search by student name, phone, email, level, or class.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (_statusMessage != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF4CE),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.cloud_off_outlined,
                                  size: 18,
                                  color: Color(0xFF7A4F01),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _statusMessage!,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: const Color(0xFF7A4F01),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Find Students', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text(
                          'Search by student name, phone, email, level, or class.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: _searchController,
                          textInputAction: TextInputAction.search,
                          decoration: const InputDecoration(
                            labelText: 'Search students',
                            hintText: 'Name, phone, or email',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.search),
                          ),
                          onSubmitted: (_) => _loadStudents(page: 1),
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
                                  await _loadStudents(page: 1);
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
                                  : () => _loadStudents(page: 1),
                              icon: const Icon(Icons.search),
                              label: const Text('Search'),
                            ),
                            if (_usingOfflineData)
                              OutlinedButton.icon(
                                onPressed: _loadingList
                                    ? null
                                    : () => _loadStudents(page: 1),
                                icon: const Icon(Icons.cloud_sync_outlined),
                                label: const Text('Retry Online'),
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
                        'No students found.',
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
                          Text('Students', style: theme.textTheme.titleLarge),
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
                                ? () => _loadStudents(page: page.currentPage - 1)
                                : null,
                            child: const Text('Prev'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: page.hasNextPage && !_loadingList
                                ? () => _loadStudents(page: page.currentPage + 1)
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

  Widget _buildStudentCard(StudentListItem item) {
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
              value: item.currentYear?.levelName ?? '-',
            ),
            _DetailRow(
              label: 'Class',
              value: item.currentYear?.className ?? '-',
            ),
            _DetailRow(
              label: 'Phone',
              value: item.phone ?? '-',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => StudentDetailScreen(
                          api: widget.api,
                          token: widget.token,
                          session: widget.session,
                          student: item,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.person_outline),
                  label: const Text('Open Profile'),
                ),
                if (_canViewMarks)
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ExamReportScreen(
                            api: widget.api,
                            token: widget.token,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.assessment_outlined),
                    label: const Text('Gradebook'),
                  ),
                if (_canEdit)
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => StudentsEditScreen(
                            api: widget.api,
                            token: widget.token,
                            session: widget.session,
                            studentId: item.id,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                if (_canEdit)
                  OutlinedButton.icon(
                    onPressed: () => _promptDisable(item),
                    icon: const Icon(Icons.block_outlined),
                    label: const Text('Disable'),
                  ),
                if (_canDelete)
                  OutlinedButton.icon(
                    onPressed: () => _confirmDelete(item),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

extension on _StudentListScreenState {
  Future<void> _promptDisable(StudentListItem item) async {
    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disable Student'),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Reason for disabling',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Disable'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    final reason = controller.text.trim();
    if (reason.isEmpty) {
      _showMessage('Provide a disable reason.');
      return;
    }

    try {
      await widget.api.disableStudent(
        token: widget.token,
        studentId: item.id,
        reason: reason,
      );

      if (!mounted) {
        return;
      }

      _showMessage('Student disabled.');
      await _loadStudents(page: _page?.currentPage ?? 1);
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Unable to disable student.');
    }
  }

  Future<void> _confirmDelete(StudentListItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Student'),
        content: Text('Delete ${item.name}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await widget.api.deleteStudent(
        token: widget.token,
        studentId: item.id,
      );

      if (!mounted) {
        return;
      }

      _showMessage('Student deleted.');
      await _loadStudents(page: _page?.currentPage ?? 1);
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Unable to delete student.');
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

const _studentListCacheKey = 'student_list_snapshot';
