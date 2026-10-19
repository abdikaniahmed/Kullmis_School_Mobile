import 'dart:async';

import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/hr_models.dart';
import '../services/laravel_api.dart';
import '../services/offline_cache_store.dart';
import 'staff_create_screen.dart';
import 'staff_edit_screen.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({
    super.key,
    required this.api,
    required this.token,
    required this.session,
  });

  final LaravelApi api;
  final String token;
  final AuthSession session;

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  final TextEditingController _searchController = TextEditingController();
  final OfflineCacheStore _cacheStore = const FileOfflineCacheStore();

  static const List<String> _types = [
    '',
    'teacher',
    'admin',
    'registrar',
    'accountant',
    'librarian',
    'other',
  ];

  StaffListPage? _page;
  bool _loading = true;
  bool _usingOfflineData = false;
  String? _statusMessage;
  String? _error;
  String _typeFilter = '';
  Timer? _searchDebounce;
  int _requestId = 0;

  bool get _canCreate => widget.session.hasPermission('staff.create');
  bool get _canEdit => widget.session.hasPermission('staff.edit');
  bool get _canDelete => widget.session.hasPermission('staff.delete');
  bool get _canViewTeachers => widget.session.hasPermission('teachers.view');

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _requestId++;
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPage({int page = 1}) async {
    _searchDebounce?.cancel();
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
      _statusMessage = null;
    });

    try {
      final result = await widget.api.staffPage(
        token: widget.token,
        page: page,
        search: _searchController.text.trim(),
        type: _typeFilter,
      );

      if (!mounted || requestId != _requestId) {
        return;
      }

      setState(() {
        _page = result;
        _loading = false;
        _usingOfflineData = false;
      });

      await _writeSnapshot();
    } on ApiException catch (error) {
      if (!mounted || requestId != _requestId) return;
      final restored = await _restoreSnapshot(
        'Offline mode: showing last synced staff list.',
        requestId,
      );
      if (restored) {
        return;
      }

      if (!mounted || requestId != _requestId) {
        return;
      }

      setState(() {
        _page = null;
        _loading = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      final restored = await _restoreSnapshot(
        'Offline mode: showing last synced staff list.',
        requestId,
      );
      if (restored) {
        return;
      }

      if (!mounted || requestId != _requestId) {
        return;
      }

      setState(() {
        _page = null;
        _loading = false;
        _error = 'Unable to load staff list.';
      });
    }
  }

  Future<bool> _restoreSnapshot(String fallbackMessage, int requestId) async {
    final json = await _cacheStore.readCacheDocument(_staffCacheKey);
    if (json == null) {
      return false;
    }

    if (!mounted || requestId != _requestId) return true;
    final snapshot = StaffOfflineSnapshot.fromJson(json);
    _searchController.text = snapshot.search;

    if (!mounted || requestId != _requestId) {
      return true;
    }

    setState(() {
      _page = snapshot.page;
      _typeFilter = snapshot.typeFilter;
      _loading = false;
      _usingOfflineData = true;
      _statusMessage = fallbackMessage;
      _error = null;
    });

    return true;
  }

  Future<void> _writeSnapshot() async {
    await _cacheStore.writeCacheDocument(
      _staffCacheKey,
      StaffOfflineSnapshot(
        page: _page,
        search: _searchController.text.trim(),
        typeFilter: _typeFilter,
      ).toJson(),
    );
  }

  Future<void> _openCreate() async {
    if (_usingOfflineData) {
      _showMessage('Staff changes are only available while online.');
      return;
    }

    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => StaffCreateScreen(
          api: widget.api,
          token: widget.token,
        ),
      ),
    );

    if (created == true) {
      _loadPage();
    }
  }

  Future<void> _openEdit(StaffMember staff) async {
    if (_usingOfflineData) {
      _showMessage('Staff changes are only available while online.');
      return;
    }

    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => StaffEditScreen(
          api: widget.api,
          token: widget.token,
          staffId: staff.id,
        ),
      ),
    );

    if (updated == true) {
      _loadPage(page: _page?.currentPage ?? 1);
    }
  }

  Future<void> _confirmDelete(StaffMember staff) async {
    if (_usingOfflineData) {
      _showMessage('Staff changes are only available while online.');
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Staff'),
        content: Text('Delete ${staff.name}?'),
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

    if (shouldDelete != true) {
      return;
    }

    try {
      await widget.api.deleteStaff(
        token: widget.token,
        staffId: staff.id,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Staff deleted.')),
        );

      await _loadPage(page: _page?.currentPage ?? 1);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = 'Unable to delete staff.';
      });
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

  Future<void> _chooseType() async {
    FocusScope.of(context).unfocus();
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (sheetContext) => ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.55),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Staff type',
                  style: Theme.of(sheetContext).textTheme.titleMedium)),
          Flexible(
              child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            itemCount: _types.length,
            itemBuilder: (context, index) {
              final type = _types[index];
              final selected = type == _typeFilter;
              return ListTile(
                dense: true,
                selected: selected,
                selectedTileColor:
                    Theme.of(context).colorScheme.secondaryContainer,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                title: Text(type.isEmpty ? 'All Types' : type),
                trailing: selected ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(sheetContext, type),
              );
            },
          )),
        ]),
      ),
    );
    if (!mounted || selected == null || selected == _typeFilter) return;
    setState(() => _typeFilter = selected);
    _loadPage();
  }

  Widget _buildFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 50,
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search staff',
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                        _loadPage();
                      },
                    ),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onChanged: (_) {
              _searchDebounce?.cancel();
              // Invalidate in-flight results as soon as the query changes.
              _requestId++;
              setState(() {});
              _searchDebounce =
                  Timer(const Duration(milliseconds: 350), () => _loadPage());
            },
            onSubmitted: (_) => _loadPage(),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          key: const ValueKey('staff-type-filter'),
          height: 50,
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                side: BorderSide(color: Theme.of(context).colorScheme.outline),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16))),
            onPressed: _chooseType,
            child: Row(children: [
              const Icon(Icons.filter_list, size: 20),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(
                      'Type: ${_typeFilter.isEmpty ? 'All Types' : _typeFilter}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)),
              const Icon(Icons.expand_more),
            ]),
          ),
        ),
        if (_statusMessage != null) ...[
          const SizedBox(height: 8),
          _StaffOfflineBanner(
            message: _statusMessage!,
            onRetry: _usingOfflineData ? _loadPage : null,
          ),
        ],
      ],
    );
  }

  Widget _staffDetail(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
            child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: '$label: ',
                      style:
                          TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                  TextSpan(text: value),
                ]),
                style: theme.textTheme.bodyMedium)),
      ]),
    );
  }

  Widget _buildRow(StaffMember staff) {
    final theme = Theme.of(context);
    return Card.outlined(
      margin: const EdgeInsets.only(bottom: 8),
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.outlineVariant)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(staff.name, style: theme.textTheme.titleMedium)),
            if (_canViewTeachers && staff.type == 'teacher')
              Icon(Icons.school_outlined,
                  size: 18, color: theme.colorScheme.primary),
            if (_canEdit || _canDelete)
              PopupMenuButton<String>(
                tooltip: 'Staff actions for ${staff.name}',
                icon: const Icon(Icons.more_vert),
                enabled: !_usingOfflineData,
                onSelected: (action) {
                  if (action == 'edit') _openEdit(staff);
                  if (action == 'delete') _confirmDelete(staff);
                },
                itemBuilder: (_) => [
                  if (_canEdit)
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  if (_canDelete)
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
          ]),
          const SizedBox(height: 4),
          _staffDetail(Icons.badge_outlined, 'Type',
              staff.type.isEmpty ? 'staff' : staff.type),
          if (staff.position?.isNotEmpty == true)
            _staffDetail(Icons.work_outline, 'Position', staff.position!),
          _staffDetail(
              Icons.phone_outlined, 'Phone', staff.phone ?? 'No phone'),
          _staffDetail(
              Icons.email_outlined, 'Email', staff.email ?? 'No email'),
          _staffDetail(Icons.account_circle_outlined, 'User account',
              staff.user != null ? 'Linked' : 'Not linked'),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _page?.items ?? const <StaffMember>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff'),
        actions: [
          if (_canCreate)
            IconButton(
              onPressed: _usingOfflineData ? null : _openCreate,
              icon: const Icon(Icons.add),
              tooltip: 'Add Staff',
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          _buildFilters(),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 32),
              child: Center(child: Text('No staff found.')),
            )
          else
            ...items.map(_buildRow),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFB42318),
                  ),
            ),
          ],
          if (_page != null) ...[
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 8,
              children: [
                Text(
                  'Showing ${_page!.from ?? 0}-${_page!.to ?? 0} of ${_page!.total}',
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
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

class _StaffOfflineBanner extends StatelessWidget {
  const _StaffOfflineBanner({
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

const _staffCacheKey = 'staff_snapshot';
