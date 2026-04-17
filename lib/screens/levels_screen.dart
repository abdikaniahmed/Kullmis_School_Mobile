import 'package:flutter/material.dart';

import '../models/academic_management_models.dart';
import '../models/auth_session.dart';
import '../services/laravel_api.dart';
import 'level_create_screen.dart';
import 'level_edit_screen.dart';

class LevelsScreen extends StatefulWidget {
  const LevelsScreen({
    super.key,
    required this.api,
    required this.token,
    required this.session,
  });

  final LaravelApi api;
  final String token;
  final AuthSession session;

  @override
  State<LevelsScreen> createState() => _LevelsScreenState();
}

class _LevelsScreenState extends State<LevelsScreen> {
  final TextEditingController _searchController = TextEditingController();

  LevelListPage? _page;
  bool _loading = true;
  String? _error;

  bool get _canCreate => widget.session.hasPermission('levels.create');
  bool get _canEdit => widget.session.hasPermission('levels.edit');
  bool get _canDelete => widget.session.hasPermission('levels.delete');

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
      final result = await widget.api.levelsPage(
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
        _error = 'Unable to load levels.';
      });
    }
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LevelCreateScreen(
          api: widget.api,
          token: widget.token,
        ),
      ),
    );

    if (created == true) {
      _loadPage();
    }
  }

  Future<void> _openEdit(LevelListItem level) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LevelEditScreen(
          api: widget.api,
          token: widget.token,
          levelId: level.id,
        ),
      ),
    );

    if (updated == true) {
      _loadPage(page: _page?.currentPage ?? 1);
    }
  }

  Future<void> _confirmDelete(LevelListItem level) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Level'),
        content: Text('Delete "${level.name}"?'),
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
      await widget.api.deleteLevel(
        token: widget.token,
        levelId: level.id,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Level deleted.')),
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
        _error = 'Unable to delete level.';
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
              labelText: 'Search levels',
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

  Widget _buildList(LevelListPage page) {
    if (page.items.isEmpty) {
      return const Center(child: Text('No levels found.'));
    }

    return Column(
      children: page.items.map(_buildCard).toList(),
    );
  }

  Widget _buildCard(LevelListItem item) {
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
          if (item.subjects.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: item.subjects
                  .map(
                    (subject) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F4F7),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        subject.name,
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
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

  Widget _buildPagination(LevelListPage page) {
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
      appBar: AppBar(title: const Text('Levels')),
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
                        'Levels',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      if (_canCreate)
                        FilledButton.icon(
                          onPressed: _openCreate,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Level'),
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
