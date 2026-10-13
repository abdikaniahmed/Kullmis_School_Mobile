import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/auth_session.dart';
import '../models/hr_models.dart';
import '../services/laravel_api.dart';
import '../services/offline_cache_store.dart';
import 'staff_create_screen.dart';
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

  bool get _canCreate => widget.session.hasPermission('staff.create');

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

  Future<void> _openCreateTeacher() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => StaffCreateScreen(
          api: widget.api,
          token: widget.token,
        ),
      ),
    );
    if (created == true && mounted) {
      await _loadPage();
    }
  }

  static const _avatarColors = <Color>[
    Color(0xFFE5F1FF),
    Color(0xFFDDF7F1),
    Color(0xFFFFE4EE),
    Color(0xFFFFF3CF),
    Color(0xFFF0E6FF),
  ];

  String _initials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2)
        .toList();
    if (words.isEmpty) return '?';
    return words.map((word) => word.substring(0, 1).toUpperCase()).join();
  }

  String _phone(TeacherSummary teacher) {
    final phone = (teacher.phone ?? '').replaceAll(RegExp(r'[\s().-]'), '');
    return RegExp(r'^\+?[0-9]+$').hasMatch(phone) ? phone : '';
  }

  Future<void> _contactTeacher(TeacherSummary teacher, String scheme) async {
    final phone = _phone(teacher);
    if (phone.isEmpty) return;

    final failureMessage = scheme == 'tel'
        ? 'Unable to open the phone dialer.'
        : 'Unable to open the messaging app.';
    try {
      if (!await launchUrl(
        Uri(scheme: scheme, path: phone),
        mode: LaunchMode.externalApplication,
      )) {
        _showContactError(failureMessage);
      }
    } catch (_) {
      _showContactError(failureMessage);
    }
  }

  void _showContactError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildContactChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(TeacherSummary teacher) {
    final theme = Theme.of(context);
    final hasPhone = !_usingOfflineData && _phone(teacher).isNotEmpty;
    final avatarColor = _avatarColors[teacher.id.abs() % _avatarColors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: avatarColor,
                child: Text(
                  _initials(teacher.name),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF174C69),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _usingOfflineData ? null : () => _openTeacher(teacher),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          teacher.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _buildContactChip(
                              icon: Icons.person,
                              label: teacher.position ?? 'Teacher',
                              color: const Color(0xFF087F79),
                            ),
                            _buildContactChip(
                              icon: Icons.mail,
                              label: teacher.email ?? 'No email',
                              color: const Color(0xFF42566F),
                            ),
                            _buildContactChip(
                              icon: Icons.phone,
                              label: teacher.phone ?? 'No phone',
                              color: const Color(0xFF42566F),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 4,
            children: [
              if (hasPhone) ...[
                _TeacherContactButton(
                  icon: Icons.chat_bubble,
                  tooltip: 'Message ${teacher.name}',
                  onPressed: () => _contactTeacher(teacher, 'sms'),
                ),
                const SizedBox(width: 4),
                _TeacherContactButton(
                  icon: Icons.call,
                  tooltip: 'Call ${teacher.name}',
                  onPressed: () => _contactTeacher(teacher, 'tel'),
                ),
              ],
              PopupMenuButton<String>(
                tooltip: 'Teacher options',
                enabled: !_usingOfflineData,
                onSelected: (_) => _openTeacher(teacher),
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'details',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.person_outline),
                      title: Text('Open details'),
                    ),
                  ),
                ],
                icon: const Icon(Icons.more_horiz),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: Colors.black.withValues(alpha: 0.06)),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.groups, size: 19, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Classes: ${teacher.classAssignmentsCount}'),
              ]),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.menu_book,
                    size: 19, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Subjects: ${teacher.subjectAssignmentsCount}'),
              ]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search by name, phone, or email...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: Colors.black.withValues(alpha: 0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: Colors.black.withValues(alpha: 0.08)),
              ),
            ),
            onSubmitted: (_) => _loadPage(),
          ),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          onPressed: _loading ? null : _loadPage,
          icon: const Icon(Icons.search),
          label: const Text('Search'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 54),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _page?.items ?? const <TeacherSummary>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teachers'),
        backgroundColor: const Color(0xFFE8F5F4),
        actions: [
          if (_canCreate)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: FilledButton.icon(
                  onPressed: _openCreateTeacher,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Teacher'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _buildSearchRow(),
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
                Expanded(
                  child: Text(
                    'Showing ${_page!.from ?? 0} - ${_page!.to ?? 0} of ${_page!.total}',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _page!.hasPreviousPage
                      ? () => _loadPage(
                            page: (_page!.currentPage - 1).clamp(1, 9999),
                          )
                      : null,
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Prev'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _page!.hasNextPage
                      ? () => _loadPage(page: _page!.currentPage + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('Next'),
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

class _TeacherContactButton extends StatelessWidget {
  const _TeacherContactButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xFFE8F5F4),
        foregroundColor: const Color(0xFF087F79),
      ),
      icon: Icon(icon, size: 19),
    );
  }
}

const _teachersCacheKey = 'teachers_snapshot';
