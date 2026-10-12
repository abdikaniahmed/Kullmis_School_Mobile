import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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

  static const _teal = Color(0xFF087F79);
  static const _ink = Color(0xFF101A36);

  String _phone(StudentListItem item) {
    final phone = (item.phone ?? '').replaceAll(RegExp(r'[\s().-]'), '');
    return RegExp(r'^\+?[0-9]+$').hasMatch(phone) ? phone : '';
  }

  Future<void> _contact(StudentListItem item, String scheme) async {
    if (_phone(item).isEmpty) return;
    final message = scheme == 'tel'
        ? 'Unable to open the phone dialer.'
        : 'Unable to open the messaging app.';
    try {
      if (!await launchUrl(Uri(scheme: scheme, path: _phone(item)),
          mode: LaunchMode.externalApplication)) {
        _showMessage(message);
      }
    } catch (_) {
      _showMessage(message);
    }
  }

  Future<void> _openEditor([StudentListItem? item]) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => item == null
            ? StudentsCreateScreen(
                api: widget.api, token: widget.token, session: widget.session)
            : StudentsEditScreen(
                api: widget.api,
                token: widget.token,
                session: widget.session,
                studentId: item.id)));
    if (mounted) await _loadStudents(page: _page?.currentPage ?? 1);
  }

  ButtonStyle _buttonStyle(bool filled) => (filled
          ? FilledButton.styleFrom(
              backgroundColor: _teal, foregroundColor: Colors.white)
          : OutlinedButton.styleFrom(
              foregroundColor: _teal, side: const BorderSide(color: _teal)))
      .copyWith(
          minimumSize: const WidgetStatePropertyAll(Size(0, 46)),
          padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 12)),
          shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));

  Widget _panel(Widget child) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: child);

  InputDecoration _input(String label, IconData icon) => InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: _ink),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDFE3E7))));

  @override
  Widget build(BuildContext context) {
    final page = _page;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5EF),
      appBar: AppBar(
          title: const Text('Student List',
              style: TextStyle(fontWeight: FontWeight.w700)),
          backgroundColor: const Color(0xFFEAF5F3),
          foregroundColor: _ink,
          surfaceTintColor: Colors.transparent),
      body: _loadingMeta
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadStudents(page: 1),
              child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                  children: [
                    if (_canCreate) ...[
                      Row(children: [
                        Expanded(
                            child: FilledButton.icon(
                                style: _buttonStyle(true),
                                onPressed: () => _openEditor(),
                                icon: const Icon(Icons.person_add_alt_1),
                                label: const Text('Add Student'))),
                        const SizedBox(width: 10),
                        Expanded(
                            child: OutlinedButton.icon(
                                style: _buttonStyle(false),
                                onPressed: () async {
                                  await Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                          builder: (_) => StudentsUploadScreen(
                                              api: widget.api,
                                              token: widget.token)));
                                  if (mounted) await _loadStudents(page: 1);
                                },
                                icon: const Icon(Icons.upload_file_outlined),
                                label: const Text('Upload'))),
                      ]),
                      const SizedBox(height: 12),
                    ],
                    _panel(Column(children: [
                      TextField(
                          controller: _searchController,
                          textInputAction: TextInputAction.search,
                          decoration: _input('Search students', Icons.search)
                              .copyWith(
                                  hintText:
                                      'Name, phone, email, level, or class...',
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC)),
                          onSubmitted: (_) => _loadStudents(page: 1)),
                      const SizedBox(height: 18),
                      LayoutBuilder(builder: (context, constraints) {
                        final level = DropdownButtonFormField<int>(
                            initialValue: _selectedLevelId,
                            isExpanded: true,
                            decoration: _input('Level', Icons.school_outlined),
                            items: [
                              const DropdownMenuItem<int>(
                                  value: null, child: Text('All Levels')),
                              ..._levels.map((e) => DropdownMenuItem<int>(
                                  value: e.id,
                                  child: Text(e.name,
                                      overflow: TextOverflow.ellipsis)))
                            ],
                            onChanged: _loadingClasses ? null : _applyLevel);
                        final schoolClass = DropdownButtonFormField<int>(
                            initialValue: _selectedClassId,
                            isExpanded: true,
                            decoration: _input('Class', Icons.groups_outlined),
                            items: [
                              const DropdownMenuItem<int>(
                                  value: null, child: Text('All Classes')),
                              ..._classes.map((e) => DropdownMenuItem<int>(
                                  value: e.id,
                                  child: Text(e.name,
                                      overflow: TextOverflow.ellipsis)))
                            ],
                            onChanged: _loadingClasses
                                ? null
                                : (value) async {
                                    setState(() => _selectedClassId = value);
                                    await _loadStudents(page: 1);
                                  });
                        if (constraints.maxWidth < 330 ||
                            MediaQuery.textScalerOf(context).scale(14) > 18) {
                          return Column(children: [
                            level,
                            const SizedBox(height: 14),
                            schoolClass
                          ]);
                        }
                        return Row(children: [
                          Expanded(child: level),
                          const SizedBox(width: 10),
                          Expanded(child: schoolClass)
                        ]);
                      }),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(
                            flex: 2,
                            child: FilledButton.icon(
                                style: _buttonStyle(true),
                                onPressed: _loadingList
                                    ? null
                                    : () => _loadStudents(page: 1),
                                icon: const Icon(Icons.search),
                                label: const Text('Search'))),
                        const SizedBox(width: 10),
                        Expanded(
                            child: OutlinedButton.icon(
                                style: _buttonStyle(false),
                                onPressed: _loadingList ? null : _clearFilters,
                                icon: const Icon(Icons.restart_alt),
                                label: const Text('Clear'))),
                      ]),
                      if (_statusMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(_statusMessage!,
                            style: const TextStyle(color: Color(0xFF7A4F01)))
                      ],
                      if (_usingOfflineData)
                        TextButton.icon(
                            onPressed: _loadingList
                                ? null
                                : () => _loadStudents(page: 1),
                            icon: const Icon(Icons.cloud_sync_outlined),
                            label: const Text('Retry Online')),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!,
                            style: const TextStyle(color: Color(0xFFB42318)))
                      ],
                    ])),
                    const SizedBox(height: 20),
                    Text('Students (${page?.total ?? 0})',
                        style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            color: _ink)),
                    const SizedBox(height: 4),
                    if (page != null)
                      Text(
                          'Showing ${page.from ?? 0} - ${page.to ?? 0} of ${page.total}',
                          style: const TextStyle(color: Color(0xFF77808E))),
                    const SizedBox(height: 12),
                    if (_loadingList)
                      const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()))
                    else if (page == null || page.items.isEmpty)
                      _panel(const Text('No students found.'))
                    else ...[
                      ...page.items.map(_buildStudentCard),
                      const SizedBox(height: 4),
                      Row(children: [
                        Expanded(
                            child: OutlinedButton(
                                style: _buttonStyle(false),
                                onPressed: page.hasPreviousPage
                                    ? () => _loadStudents(
                                        page: page.currentPage - 1)
                                    : null,
                                child: const Text('Prev'))),
                        Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child:
                                Text('${page.currentPage} / ${page.lastPage}')),
                        Expanded(
                            child: FilledButton(
                                style: _buttonStyle(true),
                                onPressed: page.hasNextPage
                                    ? () => _loadStudents(
                                        page: page.currentPage + 1)
                                    : null,
                                child: const Text('Next'))),
                      ]),
                    ],
                  ])),
    );
  }

  Widget _badge(String text, IconData icon, Color color, Color background) =>
      Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
              color: background, borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 5),
            Flexible(
                child: Text(text,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color)))
          ]));

  Widget _buildStudentCard(StudentListItem item) {
    const colors = [
      Color(0xFF2196E5),
      Color(0xFFE6A000),
      Color(0xFFD93670),
      Color(0xFF0D9C86)
    ];
    final color = colors[item.id.abs() % colors.length];
    final hasPhone = _phone(item).isNotEmpty;
    return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _panel(
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(
                radius: 25,
                backgroundColor: color.withValues(alpha: 0.10),
                child: Icon(Icons.school, size: 29, color: color)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(item.name,
                      style: const TextStyle(
                          fontSize: 17,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                          color: _ink)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    _badge(
                        item.currentYear?.levelName ?? 'No level',
                        Icons.menu_book,
                        const Color(0xFF168DDA),
                        const Color(0xFFEAF6FE)),
                    _badge(item.currentYear?.className ?? 'No class',
                        Icons.groups, _teal, const Color(0xFFE6F5F1)),
                  ]),
                ])),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: TextButton.icon(
                    style: TextButton.styleFrom(
                        foregroundColor: _ink,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: const Size(0, 48)),
                    onPressed: hasPhone ? () => _contact(item, 'tel') : null,
                    icon: const Icon(Icons.phone, color: _teal, size: 18),
                    label: Text(
                        item.phone?.trim().isNotEmpty == true
                            ? item.phone!
                            : 'No phone number',
                        overflow: TextOverflow.ellipsis))),
            IconButton.filledTonal(
                tooltip: 'Message ${item.name}',
                style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFEAF6F3),
                    foregroundColor: _teal),
                onPressed: hasPhone ? () => _contact(item, 'sms') : null,
                icon: const Icon(Icons.chat_outlined, size: 21)),
            const SizedBox(width: 6),
            IconButton.filledTonal(
                tooltip: 'Call ${item.name}',
                style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFEAF6F3),
                    foregroundColor: _teal),
                onPressed: hasPhone ? () => _contact(item, 'tel') : null,
                icon: const Icon(Icons.call, size: 21)),
          ]),
          const SizedBox(height: 6),
          LayoutBuilder(builder: (context, constraints) {
            final actions = <Widget>[
              FilledButton.icon(
                  style: _buttonStyle(true),
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => StudentDetailScreen(
                              api: widget.api,
                              token: widget.token,
                              session: widget.session,
                              student: item))),
                  icon: constraints.maxWidth >= 350
                      ? const Icon(Icons.person_outline, size: 18)
                      : null,
                  label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Open Profile', maxLines: 1))),
              if (_canViewMarks)
                OutlinedButton.icon(
                    style: _buttonStyle(false),
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => ExamReportScreen(
                                api: widget.api, token: widget.token))),
                    icon: constraints.maxWidth >= 350
                        ? const Icon(Icons.bar_chart, size: 18)
                        : null,
                    label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Gradebook', maxLines: 1))),
            ];
            return Row(children: [
              Expanded(child: actions.first),
              if (actions.length > 1) ...[
                const SizedBox(width: 8),
                Expanded(child: actions.last)
              ],
              if (_canEdit || _canDelete) ...[
                const SizedBox(width: 8),
                SizedBox(width: 48, height: 48, child: _studentMenu(item))
              ]
            ]);
          }),
        ])));
  }

  Widget _studentMenu(StudentListItem item) => PopupMenuButton<String>(
      tooltip: 'More actions for ${item.name}',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 4),
      useRootNavigator: true,
      style: IconButton.styleFrom(
        side: const BorderSide(color: Color(0xFFDFE3E7)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.more_horiz, color: _ink),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (action) {
        switch (action) {
          case 'edit':
            _openEditor(item);
            break;
          case 'disable':
            _promptDisable(item);
            break;
          case 'delete':
            _confirmDelete(item);
            break;
        }
      },
      itemBuilder: (_) => [
            if (_canEdit) ...[
              const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit'))),
              const PopupMenuItem(
                  value: 'disable',
                  child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.block_outlined),
                      title: Text('Disable'))),
            ],
            if (_canDelete)
              const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading:
                          Icon(Icons.delete_outline, color: Color(0xFFB42318)),
                      title: Text('Delete',
                          style: TextStyle(color: Color(0xFFB42318))))),
          ]);
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

const _studentListCacheKey = 'student_list_snapshot';
