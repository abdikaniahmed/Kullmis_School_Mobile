import 'package:flutter/material.dart';

import '../models/academic_management_models.dart';
import '../models/auth_session.dart';
import '../services/laravel_api.dart';
import 'academic_year_create_screen.dart';
import 'academic_year_edit_screen.dart';
import 'promotions_screen.dart';

class AcademicYearsScreen extends StatefulWidget {
  const AcademicYearsScreen({
    super.key,
    required this.api,
    required this.token,
    required this.session,
  });

  final LaravelApi api;
  final String token;
  final AuthSession session;

  @override
  State<AcademicYearsScreen> createState() => _AcademicYearsScreenState();
}

class _AcademicYearsScreenState extends State<AcademicYearsScreen> {
  final TextEditingController _searchController = TextEditingController();

  AcademicYearListPage? _page;
  bool _loading = true;
  String? _error;

  bool get _canCreate => widget.session.hasPermission('academic_years.create');
  bool get _canEdit => widget.session.hasPermission('academic_years.edit');
  bool get _canDelete => widget.session.hasPermission('academic_years.delete');
  bool get _isSchoolAdmin => widget.session.roles.any(
        (role) => role.toLowerCase() == 'school_admin',
      );

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
      final result = await widget.api.academicYearList(
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
        _error = 'Unable to load academic years.';
      });
    }
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AcademicYearCreateScreen(
          api: widget.api,
          token: widget.token,
        ),
      ),
    );

    if (created == true) {
      _loadPage();
    }
  }

  Future<void> _openEdit(AcademicYearListItem year) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AcademicYearEditScreen(
          api: widget.api,
          token: widget.token,
          yearId: year.id,
        ),
      ),
    );

    if (updated == true) {
      _loadPage(page: _page?.currentPage ?? 1);
    }
  }

  Future<void> _openPromotions() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PromotionsScreen(
          api: widget.api,
          token: widget.token,
          session: widget.session,
        ),
      ),
    );
  }

  Future<void> _setActive(AcademicYearListItem year) async {
    setState(() {
      _loading = true;
    });

    try {
      await widget.api.setActiveAcademicYear(
        token: widget.token,
        yearId: year.id,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Active academic year updated.')),
        );

      await _loadPage(page: _page?.currentPage ?? 1);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = 'Unable to update active academic year.';
      });
    }
  }

  Future<void> _confirmDelete(AcademicYearListItem year) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Academic Year'),
        content: Text('Delete "${year.name}"?'),
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
      await widget.api.deleteAcademicYear(
        token: widget.token,
        yearId: year.id,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Academic year deleted.')),
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
        _error = 'Unable to delete academic year.';
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
              labelText: 'Search academic year',
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

  Widget _buildActions() {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        if (_isSchoolAdmin)
          OutlinedButton.icon(
            onPressed: _openPromotions,
            icon: const Icon(Icons.trending_up),
            label: const Text('Promotions'),
          ),
        if (_canCreate)
          FilledButton.icon(
            onPressed: _openCreate,
            icon: const Icon(Icons.add),
            label: const Text('Add Year'),
          ),
      ],
    );
  }

  Widget _buildList(AcademicYearListPage page) {
    if (page.items.isEmpty) {
      return const Center(child: Text('No academic years found.'));
    }

    return Column(
      children: page.items.map(_buildCard).toList(),
    );
  }

  Widget _buildCard(AcademicYearListItem item) {
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
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              _StatusBadge(isActive: item.isActive),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Start: ${item.startDate ?? '-'}',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'End: ${item.endDate ?? '-'}',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!item.isActive && _canEdit)
                FilledButton(
                  onPressed: () => _setActive(item),
                  child: const Text('Set Active'),
                ),
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

  Widget _buildPagination(AcademicYearListPage page) {
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
      appBar: AppBar(title: const Text('Academic Years')),
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
                        'Academic Years',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildActions(),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? const Color(0xFF067647) : const Color(0xFF98A2B3);
    final background =
        isActive ? const Color(0xFFD1FADF) : const Color(0xFFF2F4F7);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
