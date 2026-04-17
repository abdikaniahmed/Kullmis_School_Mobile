import 'package:flutter/material.dart';

import '../models/academic_management_models.dart';
import '../models/auth_session.dart';
import '../services/laravel_api.dart';
import 'class_create_screen.dart';
import 'class_edit_screen.dart';

class ClassesScreen extends StatefulWidget {
  const ClassesScreen({
    super.key,
    required this.api,
    required this.token,
    required this.session,
  });

  final LaravelApi api;
  final String token;
  final AuthSession session;

  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> {
  final TextEditingController _searchController = TextEditingController();

  ClassListPage? _page;
  bool _loading = true;
  String? _error;

  bool get _canCreate => widget.session.hasPermission('classes.create');
  bool get _canEdit => widget.session.hasPermission('classes.edit');
  bool get _canDelete => widget.session.hasPermission('classes.delete');

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
      final result = await widget.api.classesPage(
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
        _error = 'Unable to load classes.';
      });
    }
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ClassCreateScreen(
          api: widget.api,
          token: widget.token,
        ),
      ),
    );

    if (created == true) {
      _loadPage();
    }
  }

  Future<void> _openEdit(ClassListItem schoolClass) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ClassEditScreen(
          api: widget.api,
          token: widget.token,
          classId: schoolClass.id,
        ),
      ),
    );

    if (updated == true) {
      _loadPage(page: _page?.currentPage ?? 1);
    }
  }

  Future<void> _confirmDelete(ClassListItem schoolClass) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Class'),
        content: Text('Delete "${schoolClass.name}"?'),
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
      await widget.api.deleteClass(
        token: widget.token,
        classId: schoolClass.id,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Class deleted.')),
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
        _error = 'Unable to delete class.';
      });
    }
  }

  Widget _buildSearchRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              labelText: 'Search classes',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _loadPage(),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton(
          onPressed: _loadPage,
          child: const Text('Search'),
        ),
      ],
    );
  }

  Widget _buildList(ClassListPage page) {
    if (page.items.isEmpty) {
      return const Center(child: Text('No classes found.'));
    }

    return Column(
      children: page.items.map(_buildCard).toList(),
    );
  }

  Widget _buildCard(ClassListItem item) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.name, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Order: ${item.order ?? '-'}',
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text('Level: ${item.levelName ?? '-'}',
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text('Section: ${item.section ?? '-'}',
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_canEdit)
                OutlinedButton(
                  onPressed: () => _openEdit(item),
                  child: const Text('Edit'),
                ),
              if (_canDelete)
                TextButton(
                  onPressed: () => _confirmDelete(item),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFB42318),
                  ),
                  child: const Text('Delete'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPagination(ClassListPage page) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            'Showing ${page.from ?? 0} - ${page.to ?? 0} of ${page.total}',
            style: theme.textTheme.bodyMedium,
          ),
        ),
        if (page.hasPreviousPage)
          OutlinedButton(
            onPressed: () => _loadPage(page: page.currentPage - 1),
            child: const Text('Prev'),
          ),
        const SizedBox(width: 8),
        if (page.hasNextPage)
          OutlinedButton(
            onPressed: () => _loadPage(page: page.currentPage + 1),
            child: const Text('Next'),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Classes')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadPage(page: _page?.currentPage ?? 1),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Classes',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      if (_canCreate)
                        FilledButton.icon(
                          onPressed: _openCreate,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Class'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSearchRow(),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Text(
                      _error!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFFB42318),
                          ),
                    ),
                  const SizedBox(height: 12),
                  if (_page != null) _buildList(_page!),
                  if (_page != null) const SizedBox(height: 8),
                  if (_page != null) _buildPagination(_page!),
                ],
              ),
            ),
    );
  }
}
