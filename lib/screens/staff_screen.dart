import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/hr_models.dart';
import '../services/laravel_api.dart';
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
  String? _error;
  String _typeFilter = '';

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
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPage({int page = 1}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await widget.api.staffPage(
        token: widget.token,
        page: page,
        search: _searchController.text.trim(),
        type: _typeFilter,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _page = result;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _page = null;
        _loading = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _page = null;
        _loading = false;
        _error = 'Unable to load staff list.';
      });
    }
  }

  Future<void> _openCreate() async {
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

  Widget _buildFilters() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              labelText: 'Search staff',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _loadPage(),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 150,
          child: DropdownButtonFormField<String>(
            value: _typeFilter,
            items: _types
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(value.isEmpty ? 'All Types' : value),
                  ),
                )
                .toList(),
            decoration: const InputDecoration(
              labelText: 'Type',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _typeFilter = value ?? '';
              });
              _loadPage();
            },
          ),
        ),
        const SizedBox(width: 12),
        FilledButton(
          onPressed: _loading ? null : _loadPage,
          child: const Text('Search'),
        ),
      ],
    );
  }

  Widget _buildRow(StaffMember staff) {
    final hasUser = staff.user != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  staff.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (_canViewTeachers && staff.type == 'teacher')
                const Icon(Icons.school_outlined, size: 18),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _InfoChip(label: staff.position ?? 'No position'),
              _InfoChip(label: staff.type.isEmpty ? 'staff' : staff.type),
              _InfoChip(label: staff.phone ?? 'No phone'),
              _InfoChip(label: staff.email ?? 'No email'),
              _InfoChip(label: hasUser ? 'Has user' : 'No user'),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              if (_canEdit)
                OutlinedButton(
                  onPressed: () => _openEdit(staff),
                  child: const Text('Edit'),
                ),
              if (_canDelete)
                OutlinedButton(
                  onPressed: () => _confirmDelete(staff),
                  child: const Text('Delete'),
                ),
            ],
          ),
        ],
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
              onPressed: _openCreate,
              icon: const Icon(Icons.add),
              tooltip: 'Add Staff',
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          _buildFilters(),
          const SizedBox(height: 16),
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
