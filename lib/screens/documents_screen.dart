import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/auth_session.dart';
import '../models/hr_models.dart';
import '../services/laravel_api.dart';
import 'document_form_screen.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({
    super.key,
    required this.api,
    required this.token,
    required this.session,
  });

  final LaravelApi api;
  final String token;
  final AuthSession session;

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _staffIdController = TextEditingController();

  DocumentCategoryOptions? _options;
  DocumentPage? _page;
  bool _loading = true;
  String? _error;

  String _scopeFilter = '';
  String _categoryFilter = '';
  String _statusFilter = '';

  bool get _canCreate => widget.session.hasPermission('documents.create');
  bool get _canEdit => widget.session.hasPermission('documents.edit');
  bool get _canDelete => widget.session.hasPermission('documents.delete');

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _staffIdController.dispose();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final options = await widget.api.documentCategories(
        token: widget.token,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _options = options;
      });

      await _loadPage();
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
        _error = 'Unable to load document categories.';
      });
    }
  }

  Future<void> _loadPage({int page = 1}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final staffId = int.tryParse(_staffIdController.text.trim());

    try {
      final result = await widget.api.documentsPage(
        token: widget.token,
        page: page,
        scope: _scopeFilter,
        staffId: staffId,
        category: _categoryFilter,
        status: _statusFilter,
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
        _error = 'Unable to load documents.';
      });
    }
  }

  Future<void> _openForm({DocumentItem? document}) async {
    final options = _options;
    if (options == null) {
      return;
    }

    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DocumentFormScreen(
          api: widget.api,
          token: widget.token,
          categories: options.categories,
          statuses: options.statuses,
          document: document,
        ),
      ),
    );

    if (updated == true) {
      _loadPage(page: _page?.currentPage ?? 1);
    }
  }

  Future<void> _confirmDelete(DocumentItem document) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Delete ${document.title}?'),
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
      await widget.api.deleteDocument(
        token: widget.token,
        documentId: document.id,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Document deleted.')),
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
        _error = 'Unable to delete document.';
      });
    }
  }

  String? _resolveLink(String? path) {
    if (path == null || path.isEmpty) {
      return null;
    }

    if (path.startsWith('http')) {
      return path;
    }

    final base = LaravelApi.baseUrl.replaceAll('/api', '');
    if (path.startsWith('/')) {
      return '$base$path';
    }

    return '$base/$path';
  }

  Future<void> _openLink(String? url) async {
    final resolved = _resolveLink(url);
    if (resolved == null) {
      return;
    }

    final uri = Uri.parse(resolved);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Unable to open link.')),
      );
  }

  Widget _buildFilters() {
    final options = _options;
    final categories = options?.categories ?? const <String>[];
    final statuses = options?.statuses ?? const <String>[];

    return Column(
      children: [
        TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            labelText: 'Search title, file, or staff',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _loadPage(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _scopeFilter,
                items: const [
                  DropdownMenuItem(value: '', child: Text('All scopes')),
                  DropdownMenuItem(value: 'school', child: Text('School')),
                  DropdownMenuItem(value: 'staff', child: Text('Staff')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Scope',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _scopeFilter = value ?? '';
                  });
                  _loadPage();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _categoryFilter,
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('All categories'),
                  ),
                  ...categories.map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  ),
                ],
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _categoryFilter = value ?? '';
                  });
                  _loadPage();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _statusFilter,
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('All statuses'),
                  ),
                  ...statuses.map(
                    (status) => DropdownMenuItem(
                      value: status,
                      child: Text(status),
                    ),
                  ),
                ],
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _statusFilter = value ?? '';
                  });
                  _loadPage();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _staffIdController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Staff ID (optional)',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _loadPage(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRow(DocumentItem document) {
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
          Text(
            document.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(document.fileName),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _InfoChip(label: document.category),
              _InfoChip(label: document.status),
              _InfoChip(label: document.scope),
              _InfoChip(label: document.staff?.name ?? 'No staff'),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              if (document.viewUrl != null)
                OutlinedButton(
                  onPressed: () => _openLink(document.viewUrl),
                  child: const Text('View PDF'),
                ),
              if (document.downloadUrl != null)
                OutlinedButton(
                  onPressed: () => _openLink(document.downloadUrl),
                  child: const Text('Download'),
                ),
              if (_canEdit)
                OutlinedButton(
                  onPressed: () => _openForm(document: document),
                  child: const Text('Edit'),
                ),
              if (_canDelete)
                OutlinedButton(
                  onPressed: () => _confirmDelete(document),
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
    final items = _page?.items ?? const <DocumentItem>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents'),
        actions: [
          if (_canCreate)
            IconButton(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              tooltip: 'Add Document',
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
              child: Center(child: Text('No documents found.')),
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
