import 'package:flutter/material.dart';

import '../models/academic_management_models.dart';
import '../models/auth_session.dart';
import '../services/laravel_api.dart';
import 'subject_create_screen.dart';
import 'subject_edit_screen.dart';

class SubjectsScreen extends StatefulWidget {
  const SubjectsScreen({
    super.key,
    required this.api,
    required this.token,
    required this.session,
  });

  final LaravelApi api;
  final String token;
  final AuthSession session;

  @override
  State<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends State<SubjectsScreen> {
  final TextEditingController _searchController = TextEditingController();

  SubjectListPage? _page;
  bool _loading = true;
  String? _error;

  bool get _canCreate => widget.session.hasPermission('subjects.create');
  bool get _canEdit => widget.session.hasPermission('subjects.edit');
  bool get _canDelete => widget.session.hasPermission('subjects.delete');

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
      final result = await widget.api.subjectsPage(
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
        _error = 'Unable to load subjects.';
      });
    }
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SubjectCreateScreen(
          api: widget.api,
          token: widget.token,
        ),
      ),
    );

    if (created == true) {
      _loadPage();
    }
  }

  Future<void> _openEdit(SubjectListItem subject) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SubjectEditScreen(
          api: widget.api,
          token: widget.token,
          subjectId: subject.id,
        ),
      ),
    );

    if (updated == true) {
      _loadPage(page: _page?.currentPage ?? 1);
    }
  }

  Future<void> _confirmDelete(SubjectListItem subject) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Subject'),
        content: Text('Delete "${subject.name}"?'),
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
      await widget.api.deleteSubject(
        token: widget.token,
        subjectId: subject.id,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Subject deleted.')),
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
        _error = 'Unable to delete subject.';
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
            decoration: InputDecoration(
              hintText: 'Search subjects...',
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

  Widget _buildList(SubjectListPage page) {
    if (page.items.isEmpty) {
      return const Center(child: Text('No subjects found.'));
    }

    return Column(
      children: page.items.map(_buildCard).toList(),
    );
  }

  Widget _buildCard(SubjectListItem item) {
    final theme = Theme.of(context);
    final typeColor = item.type == 'essential'
        ? const Color(0xFF067647)
        : const Color(0xFF175CD3);
    final iconColor = _subjectColors[item.id.abs() % _subjectColors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 27,
            backgroundColor: iconColor.withValues(alpha: 0.12),
            child: Icon(
              _subjectIcon(item.name),
              color: iconColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Order: ${item.orderNumber ?? '-'}',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              item.type,
              style: theme.textTheme.labelSmall?.copyWith(
                color: typeColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (_canEdit || _canDelete)
            PopupMenuButton<String>(
              tooltip: 'Subject options',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF0F2F5),
                shape: const CircleBorder(),
              ),
              icon: const Icon(Icons.more_horiz),
              onSelected: (value) {
                if (value == 'edit') {
                  _openEdit(item);
                } else {
                  _confirmDelete(item);
                }
              },
              itemBuilder: (context) => [
                if (_canEdit)
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit'),
                    ),
                  ),
                if (_canDelete)
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.delete_outline, color: Colors.red),
                      title: Text('Delete'),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  static const _subjectColors = <Color>[
    Color(0xFF0F8B78),
    Color(0xFF1788C9),
    Color(0xFFC79800),
    Color(0xFFE04475),
    Color(0xFF7652D6),
  ];

  IconData _subjectIcon(String name) {
    switch (name.toLowerCase()) {
      case 'islamic':
        return Icons.mosque_outlined;
      case 'arabic':
      case 'somali':
        return Icons.menu_book;
      case 'maths':
      case 'mathematics':
        return Icons.calculate_outlined;
      case 'physics':
        return Icons.science_outlined;
      case 'history':
        return Icons.account_balance_outlined;
      case 'geography':
        return Icons.public_outlined;
      case 'computer':
        return Icons.computer_outlined;
      case 'english':
        return Icons.text_fields_outlined;
      default:
        return Icons.menu_book_outlined;
    }
  }

  Widget _buildPagination(SubjectListPage page) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            'Showing ${page.from ?? 0} - ${page.to ?? 0} of ${page.total}',
            style: theme.textTheme.bodyMedium,
          ),
        ),
        OutlinedButton.icon(
          onPressed: page.hasPreviousPage
              ? () => _loadPage(page: page.currentPage - 1)
              : null,
          icon: const Icon(Icons.chevron_left),
          label: const Text('Prev'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: page.hasNextPage
              ? () => _loadPage(page: page.currentPage + 1)
              : null,
          icon: const Icon(Icons.chevron_right),
          label: const Text('Next'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subjects'),
        backgroundColor: const Color(0xFFE8F5F4),
        actions: [
          if (_canCreate)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: FilledButton.icon(
                  onPressed: _openCreate,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Subject'),
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadPage(page: _page?.currentPage ?? 1),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _buildSearchRow(),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Text(
                      _error!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFFB42318),
                          ),
                    ),
                  if (_page != null) _buildList(_page!),
                  if (_page != null) const SizedBox(height: 8),
                  if (_page != null) _buildPagination(_page!),
                ],
              ),
            ),
    );
  }
}
