import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/discipline_incident_models.dart';
import '../models/main_attendance_models.dart';
import '../models/student_list_models.dart';
import '../services/laravel_api.dart';
import '../services/offline_cache_store.dart';
import 'student_detail_screen.dart';

class DisciplineIncidentsScreen extends StatefulWidget {
  const DisciplineIncidentsScreen({
    super.key,
    required this.api,
    required this.token,
    required this.session,
  });

  final LaravelApi api;
  final String token;
  final AuthSession session;

  @override
  State<DisciplineIncidentsScreen> createState() =>
      _DisciplineIncidentsScreenState();
}

class _DisciplineIncidentsScreenState extends State<DisciplineIncidentsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final OfflineCacheStore _cacheStore = const FileOfflineCacheStore();

  List<MainAttendanceLevel> _levels = const [];
  List<MainAttendanceClass> _classes = const [];
  DisciplineIncidentPage? _page;
  int? _selectedLevelId;
  int? _selectedClassId;
  bool _loadingMeta = true;
  bool _loadingClasses = false;
  bool _loadingList = false;
  bool _usingOfflineData = false;
  String? _statusMessage;
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

      await _loadIncidents(page: 1);
    } on ApiException catch (error) {
      final restored = await _restoreSnapshot(
        'Offline mode: showing last synced discipline incidents.',
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
      final restored = await _restoreSnapshot(
        'Offline mode: showing last synced discipline incidents.',
      );
      if (restored) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _loadingMeta = false;
        _error = 'Unable to load discipline incidents setup.';
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
      await _writeSnapshot();
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
      await _writeSnapshot();
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

  Future<void> _loadIncidents({int page = 1}) async {
    setState(() {
      _loadingList = true;
      _error = null;
      _statusMessage = null;
    });

    try {
      final result = await widget.api.studentDisciplineIncidents(
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
        _usingOfflineData = false;
      });
      await _writeSnapshot();
    } on ApiException catch (error) {
      final restored = await _restoreSnapshot(
        'Offline mode: showing last synced discipline incidents.',
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
      final restored = await _restoreSnapshot(
        'Offline mode: showing last synced discipline incidents.',
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
        _error = 'Unable to load discipline incidents.';
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
    await _loadIncidents(page: 1);
  }

  Future<void> _clearFilters() async {
    _searchController.clear();

    setState(() {
      _selectedLevelId = null;
      _selectedClassId = null;
      _classes = const [];
    });

    await _loadIncidents(page: 1);
  }

  Future<bool> _restoreSnapshot(String fallbackMessage) async {
    final json = await _cacheStore.readCacheDocument(_disciplineCacheKey);
    if (json == null) {
      return false;
    }

    final snapshot = DisciplineIncidentsOfflineSnapshot.fromJson(json);
    _searchController.text = snapshot.search;

    final restoredLevels = snapshot.levels
        .map((entry) => MainAttendanceLevel.fromJson(entry as Map<String, dynamic>))
        .toList();
    final restoredClasses = snapshot.classes
        .map((entry) => MainAttendanceClass.fromJson(entry as Map<String, dynamic>))
        .toList();

    if (!mounted) {
      return true;
    }

    setState(() {
      _levels = restoredLevels;
      _classes = restoredClasses;
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

  Future<void> _writeSnapshot() async {
    await _cacheStore.writeCacheDocument(
      _disciplineCacheKey,
      DisciplineIncidentsOfflineSnapshot(
        levels: _levels.map((entry) => entry.toJson()).toList(),
        classes: _classes.map((entry) => entry.toJson()).toList(),
        page: _page,
        selectedLevelId: _selectedLevelId,
        selectedClassId: _selectedClassId,
        search: _searchController.text.trim(),
      ).toJson(
        levels: _levels.map((entry) => entry.toJson()).toList(),
        classes: _classes.map((entry) => entry.toJson()).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final page = _page;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discipline Incidents'),
      ),
      body: _loadingMeta
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadIncidents(page: 1),
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
                        Text('Filter incidents', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text(
                          'Search students, incidents, or reporters, and filter by level or class.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: _searchController,
                          textInputAction: TextInputAction.search,
                          decoration: const InputDecoration(
                            labelText: 'Search incidents',
                            hintText: 'Student, incident, or reporter',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.search),
                          ),
                          onSubmitted: (_) => _loadIncidents(page: 1),
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
                                  await _loadIncidents(page: 1);
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
                                  : () => _loadIncidents(page: 1),
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
                        if (_statusMessage != null) ...[
                          const SizedBox(height: 14),
                          _DisciplineOfflineBanner(
                            message: _statusMessage!,
                            onRetry: _usingOfflineData ? () => _loadMeta() : null,
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
                        'No discipline incidents found.',
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
                      child: Text(
                        'Showing ${page.from ?? 0} - ${page.to ?? 0} of ${page.total}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...page.items.map(_buildIncidentCard),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: page.hasPreviousPage && !_loadingList
                                ? () => _loadIncidents(page: page.currentPage - 1)
                                : null,
                            child: const Text('Prev'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: page.hasNextPage && !_loadingList
                                ? () => _loadIncidents(page: page.currentPage + 1)
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

  Widget _buildIncidentCard(DisciplineIncidentItem item) {
    final student = item.student;

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
              student?.name ?? 'Unknown student',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2933),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${student?.levelName ?? '—'} • ${student?.className ?? '—'}',
              style: const TextStyle(color: Color(0xFF52606D)),
            ),
            const SizedBox(height: 10),
            Text(item.whatHappened),
            const SizedBox(height: 8),
            Text(
              'Reported by: ${item.reportedBy ?? '—'}',
              style: const TextStyle(color: Color(0xFF52606D)),
            ),
            Text(
              'When: ${_formatIncidentDate(item.happenedAt ?? item.createdAt)}',
              style: const TextStyle(color: Color(0xFF52606D)),
            ),
            if (item.actionTaken != null && item.actionTaken!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Action: ${item.actionTaken}',
                  style: const TextStyle(color: Color(0xFF52606D)),
                ),
              ),
            if (student != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: FilledButton.icon(
                  onPressed: _usingOfflineData
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => StudentDetailScreen(
                                api: widget.api,
                                token: widget.token,
                                session: widget.session,
                                student: _studentSummaryToListItem(student),
                              ),
                            ),
                          );
                        },
                  icon: const Icon(Icons.person_outline),
                  label: const Text('Open Student Profile'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DisciplineOfflineBanner extends StatelessWidget {
  const _DisciplineOfflineBanner({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBEAE9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: Color(0xFFB42318)),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
          if (onRetry != null)
            TextButton(
              onPressed: () {
                onRetry!();
              },
              child: const Text('Retry Online'),
            ),
        ],
      ),
    );
  }
}

StudentListItem _studentSummaryToListItem(
  DisciplineIncidentStudentSummary student,
) {
  return StudentListItem(
    id: student.id,
    name: student.name,
    phone: student.phone,
    currentYear: StudentCurrentYear(
      levelId: student.levelId,
      classId: student.classId,
      rollNumber: student.rollNumber,
      levelName: student.levelName,
      className: student.className,
    ),
  );
}

String _formatIncidentDate(String? value) {
  if (value == null || value.isEmpty) {
    return '—';
  }

  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return value;
  }

  final month = parsed.month.toString().padLeft(2, '0');
  final day = parsed.day.toString().padLeft(2, '0');
  final hour = parsed.hour.toString().padLeft(2, '0');
  final minute = parsed.minute.toString().padLeft(2, '0');
  return '${parsed.year}-$month-$day $hour:$minute';
}

const _disciplineCacheKey = 'discipline_incidents_snapshot';
