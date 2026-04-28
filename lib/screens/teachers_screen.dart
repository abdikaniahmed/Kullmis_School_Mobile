import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/hr_models.dart';
import '../services/laravel_api.dart';
import '../services/offline_cache_store.dart';
import 'teacher_detail_screen.dart';

class TeachersScreen extends StatefulWidget {
  const TeachersScreen({
    super.key,
    required this.api,
    required this.token,
    required this.session,
  });

  final LaravelApi api;
  final String token;
  final AuthSession session;

  @override
  State<TeachersScreen> createState() => _TeachersScreenState();
}

class _TeachersScreenState extends State<TeachersScreen> {
  final TextEditingController _searchController = TextEditingController();
  final OfflineCacheStore _cacheStore = const FileOfflineCacheStore();

  TeacherListPage? _page;
  bool _loading = true;
  bool _usingOfflineData = false;
  String? _statusMessage;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPage({int page = 1}) async {
    setState(() {
      _loading = true;
      _error = null;
      _statusMessage = null;
    });

    try {
      final result = await widget.api.teachersPage(
        token: widget.token,
        page: page,
        search: _searchController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _page = result;
        _loading = false;
        _usingOfflineData = false;
      });

      await _cacheStore.writeCacheDocument(
        _teachersCacheKey,
        TeachersOfflineSnapshot(
          page: _page,
          search: _searchController.text.trim(),
        ).toJson(),
      );
    } on ApiException catch (error) {
      final restored = await _restoreSnapshot(
        'Offline mode: showing last synced teachers list.',
      );
      if (restored) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _page = null;
        _loading = false;
        _error = error.message;
      });
    } catch (_) {
      final restored = await _restoreSnapshot(
        'Offline mode: showing last synced teachers list.',
      );
      if (restored) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _page = null;
        _loading = false;
        _error = 'Unable to load teachers.';
      });
    }
  }

  Future<bool> _restoreSnapshot(String fallbackMessage) async {
    final json = await _cacheStore.readCacheDocument(_teachersCacheKey);
    if (json == null) {
      return false;
    }

    final snapshot = TeachersOfflineSnapshot.fromJson(json);
    _searchController.text = snapshot.search;

    if (!mounted) {
      return true;
    }

    setState(() {
      _page = snapshot.page;
      _loading = false;
      _usingOfflineData = true;
      _statusMessage = fallbackMessage;
      _error = null;
    });

    return true;
  }

  Future<void> _openTeacher(TeacherSummary teacher) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TeacherDetailScreen(
          api: widget.api,
          token: widget.token,
          session: widget.session,
          teacherId: teacher.id,
        ),
      ),
    );
  }

  Widget _buildRow(TeacherSummary teacher) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: InkWell(
        onTap: _usingOfflineData ? null : () => _openTeacher(teacher),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              teacher.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _InfoChip(label: teacher.position ?? 'No position'),
                _InfoChip(label: teacher.email ?? 'No email'),
                _InfoChip(label: teacher.phone ?? 'No phone'),
                _InfoChip(
                  label:
                      'Classes: ${teacher.classAssignmentsCount} | Subjects: ${teacher.subjectAssignmentsCount}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _page?.items ?? const <TeacherSummary>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Teachers')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    labelText: 'Search teachers',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _loadPage(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _loading ? null : _loadPage,
                child: const Text('Search'),
              ),
            ],
          ),
          if (_statusMessage != null) ...[
            const SizedBox(height: 12),
            _TeachersOfflineBanner(
              message: _statusMessage!,
              onRetry: _usingOfflineData ? _loadPage : null,
            ),
          ],
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 32),
              child: Center(child: Text('No teachers found.')),
            )
          else
            ...items.map(_buildRow),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFB42318),
                  ),
            ),
          ],
          if (_page != null) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${_page!.from ?? 0}-${_page!.to ?? 0} of ${_page!.total}',
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: _page!.hasPreviousPage
                          ? () => _loadPage(
                                page: (_page!.currentPage - 1).clamp(1, 9999),
                              )
                          : null,
                      child: const Text('Prev'),
                    ),
                    TextButton(
                      onPressed: _page!.hasNextPage
                          ? () => _loadPage(page: _page!.currentPage + 1)
                          : null,
                      child: const Text('Next'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TeachersOfflineBanner extends StatelessWidget {
  const _TeachersOfflineBanner({
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

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

const _teachersCacheKey = 'teachers_snapshot';
