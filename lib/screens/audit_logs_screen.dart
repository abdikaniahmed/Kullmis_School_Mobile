import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/hr_models.dart';
import '../services/laravel_api.dart';
import 'audit_detail_screen.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({
    super.key,
    required this.api,
    required this.token,
    required this.session,
  });

  final LaravelApi api;
  final String token;
  final AuthSession session;

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  final TextEditingController _searchController = TextEditingController();

  AuditFilterOptions? _filters;
  AuditLogPage? _page;
  bool _loading = true;
  String? _error;

  String _actionFilter = '';
  int? _userFilter;
  String _modelFilter = '';

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
      _loading = true;
      _error = null;
    });

    try {
      final filters = await widget.api.auditFilters(token: widget.token);

      if (!mounted) {
        return;
      }

      setState(() {
        _filters = filters;
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
        _error = 'Unable to load audit filters.';
      });
    }
  }

  Future<void> _loadPage({int page = 1}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await widget.api.auditLogs(
        token: widget.token,
        page: page,
        search: _searchController.text.trim(),
        action: _actionFilter,
        userId: _userFilter,
        model: _modelFilter,
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
        _error = 'Unable to load audit logs.';
      });
    }
  }

  Future<void> _openDetail(AuditLogItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AuditDetailScreen(
          api: widget.api,
          token: widget.token,
          auditId: item.id,
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final filters = _filters;
    final actions = filters?.actions ?? const <String>[];
    final users = filters?.users ?? const <UserSummary>[];
    final models = filters?.models ?? const <AuditModelOption>[];

    return Column(
      children: [
        TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            labelText: 'Search audits',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _loadPage(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _actionFilter,
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('All actions'),
                  ),
                  ...actions.map(
                    (action) => DropdownMenuItem(
                      value: action,
                      child: Text(action),
                    ),
                  ),
                ],
                decoration: const InputDecoration(
                  labelText: 'Action',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _actionFilter = value ?? '';
                  });
                  _loadPage();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _userFilter,
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All users'),
                  ),
                  ...users.map(
                    (user) => DropdownMenuItem(
                      value: user.id,
                      child: Text(user.name),
                    ),
                  ),
                ],
                decoration: const InputDecoration(
                  labelText: 'User',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _userFilter = value;
                  });
                  _loadPage();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _modelFilter,
          items: [
            const DropdownMenuItem(
              value: '',
              child: Text('All models'),
            ),
            ...models.map(
              (model) => DropdownMenuItem(
                value: model.value,
                child: Text(model.label),
              ),
            ),
          ],
          decoration: const InputDecoration(
            labelText: 'Model',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() {
              _modelFilter = value ?? '';
            });
            _loadPage();
          },
        ),
      ],
    );
  }

  Widget _buildRow(AuditLogItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: InkWell(
        onTap: () => _openDetail(item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.description ?? item.event ?? 'Audit event',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text('User: ${item.causer?.name ?? 'System'}'),
            Text('Model: ${item.subjectType ?? '-'}'),
            Text('When: ${item.createdAt ?? '-'}'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _page?.items ?? const <AuditLogItem>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Audit Logs')),
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
              child: Center(child: Text('No audit logs found.')),
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
