import 'package:flutter/material.dart';

import '../services/offline_sync_queue.dart';

class SyncIssuesScreen extends StatefulWidget {
  const SyncIssuesScreen({super.key});

  @override
  State<SyncIssuesScreen> createState() => _SyncIssuesScreenState();
}

class _SyncIssuesScreenState extends State<SyncIssuesScreen> {
  final OfflineSyncQueue _syncQueue = const OfflineSyncQueue();
  List<OfflineSyncIssue> _issues = const [];
  bool _loading = true;
  bool _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadIssues();
  }

  Future<void> _loadIssues() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final issues = await _syncQueue.readIssues();
      if (!mounted) {
        return;
      }

      setState(() {
        _issues = issues;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = 'Unable to load sync issues.';
      });
    }
  }

  Future<void> _retryIssue(OfflineSyncIssue issue) async {
    setState(() {
      _working = true;
    });

    try {
      await _syncQueue.requeueIssue(issue.key);
      await _loadIssues();
      _showMessage('Issue moved back to the sync queue.');
    } catch (_) {
      _showMessage('Unable to retry this issue yet.');
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  Future<void> _discardIssue(OfflineSyncIssue issue) async {
    setState(() {
      _working = true;
    });

    try {
      await _syncQueue.clearIssue(issue.key);
      await _loadIssues();
      _showMessage('Issue discarded.');
    } catch (_) {
      _showMessage('Unable to discard this issue.');
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  Future<void> _clearAllIssues() async {
    setState(() {
      _working = true;
    });

    try {
      await _syncQueue.clearAllIssues();
      await _loadIssues();
      _showMessage('All sync issues cleared.');
    } catch (_) {
      _showMessage('Unable to clear sync issues.');
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  String _labelizeType(String value) {
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String _issueTitle(OfflineSyncIssue issue) {
    final payload = issue.payload;
    switch (issue.type) {
      case 'task_create':
      case 'task_update':
        {
          final task = payload['task'];
          if (task is Map<String, dynamic>) {
            final title = '${task['title'] ?? ''}'.trim();
            if (title.isNotEmpty) {
              return title;
            }
          }

          final request = payload['payload'];
          if (request is Map<String, dynamic>) {
            final title = '${request['title'] ?? ''}'.trim();
            if (title.isNotEmpty) {
              return title;
            }
          }

          return 'Task change';
        }
      case 'task_delete':
        return 'Task deletion';
      case 'expense_create':
      case 'expense_update':
        {
          final expense = payload['expense'];
          if (expense is Map<String, dynamic>) {
            final title = '${expense['title'] ?? ''}'.trim();
            if (title.isNotEmpty) {
              return title;
            }
          }

          final request = payload['payload'];
          if (request is Map<String, dynamic>) {
            final title = '${request['title'] ?? ''}'.trim();
            if (title.isNotEmpty) {
              return title;
            }
          }

          return 'Expense change';
        }
      case 'expense_delete':
        return 'Expense deletion';
      case 'petty_cash_create':
      case 'petty_cash_update':
        {
          final budget = payload['budget'];
          if (budget is Map<String, dynamic>) {
            final name = '${budget['name'] ?? ''}'.trim();
            if (name.isNotEmpty) {
              return name;
            }
          }

          final request = payload['payload'];
          if (request is Map<String, dynamic>) {
            final name = '${request['name'] ?? ''}'.trim();
            if (name.isNotEmpty) {
              return name;
            }
          }

          return 'Petty cash budget';
        }
      case 'petty_cash_delete':
        return 'Petty cash deletion';
      case 'petty_cash_topup':
        return 'Petty cash top up';
      case 'subject_timetable_save':
        return 'Subject timetable';
      case 'incident_create':
        return 'Discipline incident';
      case 'main_attendance_save':
        return 'Daily attendance';
      case 'subject_attendance_save':
        return 'Subject attendance';
      case 'exam_marks_save':
        return 'Exam marks';
      case 'bus_assign':
        return 'Bus assignment';
      default:
        return _labelizeType(issue.type);
    }
  }

  List<String> _issueDetails(OfflineSyncIssue issue) {
    final payload = issue.payload;
    switch (issue.type) {
      case 'task_create':
      case 'task_update':
        {
          final request =
              payload['payload'] as Map<String, dynamic>? ?? const {};
          return _compact([
            _named('Status', request['status']),
            _named('Priority', request['priority']),
            _named('Visibility', request['visibility']),
          ]);
        }
      case 'expense_create':
      case 'expense_update':
        {
          final request =
              payload['payload'] as Map<String, dynamic>? ?? const {};
          return _compact([
            _named('Amount', request['amount']),
            _named('Method', request['payment_method']),
            _named('Date', request['expense_date']),
          ]);
        }
      case 'petty_cash_create':
      case 'petty_cash_update':
        {
          final request =
              payload['payload'] as Map<String, dynamic>? ?? const {};
          return _compact([
            _named('Status', request['status']),
            _named('Start', request['period_start']),
            _named('End', request['period_end']),
          ]);
        }
      case 'petty_cash_topup':
        {
          final request =
              payload['payload'] as Map<String, dynamic>? ?? const {};
          return _compact([
            _named('Amount', request['amount']),
            _named('Date', request['transaction_date']),
            _named('Reference', request['reference_no']),
          ]);
        }
      case 'subject_timetable_save':
        return _compact([
          _named('Class ID', payload['school_class_id']),
          _named('Day', payload['day_of_week']),
          _named(
            'Entries',
            (payload['entries'] as List<dynamic>? ?? const []).length,
          ),
        ]);
      case 'incident_create':
        return _compact([
          _named('Student ID', payload['student_id']),
          _named('When', payload['happened_at']),
          _named('Reporter', payload['reported_by_name']),
        ]);
      case 'main_attendance_save':
      case 'subject_attendance_save':
        return _compact([
          _named('Class ID', payload['school_class_id']),
          _named('Date', payload['date']),
          _named(
            'Records',
            (payload['records'] as List<dynamic>? ?? const []).length,
          ),
        ]);
      case 'exam_marks_save':
        return _compact([
          _named('Class ID', payload['class_id']),
          _named(
            'Marks',
            (payload['marks'] as List<dynamic>? ?? const []).length,
          ),
        ]);
      case 'bus_assign':
        return _compact([
          _named('Bus ID', payload['bus_id']),
          _named(
            'Students',
            (payload['student_ids'] as List<dynamic>? ?? const []).length,
          ),
        ]);
      default:
        return const [];
    }
  }

  String? _named(String label, dynamic value) {
    final text = '${value ?? ''}'.trim();
    if (text.isEmpty) {
      return null;
    }

    return '$label: $text';
  }

  List<String> _compact(List<String?> values) {
    return values.whereType<String>().toList();
  }

  Widget _buildIssueCard(BuildContext context, OfflineSyncIssue issue) {
    final details = _issueDetails(issue);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _IssueChip(label: _labelizeType(issue.type)),
                if (issue.statusCode != null)
                  _IssueChip(label: 'HTTP ${issue.statusCode}'),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _issueTitle(issue),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              issue.message,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...details.map(
                (detail) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    detail,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Key: ${issue.key}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _working ? null : () => _retryIssue(issue),
                  icon: const Icon(Icons.sync),
                  label: const Text('Retry'),
                ),
                OutlinedButton.icon(
                  onPressed: _working ? null : () => _discardIssue(issue),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Discard'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Issues'),
        actions: [
          IconButton(
            onPressed: _loading || _working ? null : _loadIssues,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          if (_issues.isNotEmpty)
            TextButton(
              onPressed: _working ? null : _clearAllIssues,
              child: const Text('Clear All'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadIssues,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            if (_error != null)
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFFB42318),
                    ),
              ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_issues.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('No sync issues need review right now.'),
              )
            else
              ..._issues.map((issue) => _buildIssueCard(context, issue)),
          ],
        ),
      ),
    );
  }
}

class _IssueChip extends StatelessWidget {
  const _IssueChip({required this.label});

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
