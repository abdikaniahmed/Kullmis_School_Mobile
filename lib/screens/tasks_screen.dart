import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/hr_models.dart';
import '../models/task_models.dart';
import '../services/laravel_api.dart';
import '../services/offline_cache_store.dart';
import '../services/offline_sync_queue.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({
    super.key,
    required this.api,
    required this.token,
    required this.session,
  });

  final LaravelApi api;
  final String token;
  final AuthSession session;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final TextEditingController _searchController = TextEditingController();
  final OfflineCacheStore _cacheStore = const FileOfflineCacheStore();
  final OfflineSyncQueue _syncQueue = const OfflineSyncQueue();

  TaskIndexPayload? _payload;
  bool _loading = true;
  bool _saving = false;
  bool _usingOfflineData = false;
  String? _statusMessage;
  String? _error;

  String _statusFilter = '';
  String _typeFilter = '';
  String _priorityFilter = '';
  String _visibilityFilter = '';
  String _relatedTypeFilter = '';
  int? _assignedToFilter;
  List<int> _pendingCompleteIds = const [];

  bool get _canCreate => widget.session.hasPermission('tasks.create');
  bool get _canEdit => widget.session.hasPermission('tasks.edit');
  bool get _canDelete => widget.session.hasPermission('tasks.delete');
  bool get _canComplete => widget.session.hasPermission('tasks.complete');

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _loading = true;
      _error = null;
      _statusMessage = null;
    });

    try {
      final payload = await widget.api.tasks(
        token: widget.token,
        status: _statusFilter,
        type: _typeFilter,
        priority: _priorityFilter,
        assignedTo: _assignedToFilter,
        relatedType: _relatedTypeFilter == 'none' ? null : _relatedTypeFilter,
        visibility: _visibilityFilter,
        search: _searchController.text.trim(),
      );

      final pendingCompletes = await _loadPendingCompleteIds();

      if (!mounted) {
        return;
      }

      setState(() {
        _payload = _applyPendingCompletesToPayload(payload, pendingCompletes);
        _pendingCompleteIds = pendingCompletes;
        _loading = false;
        _usingOfflineData = false;
        _statusMessage = pendingCompletes.isEmpty
            ? null
            : 'Some task completions are still queued for sync.';
      });

      await _writeSnapshot();
    } on ApiException catch (error) {
      final restored = await _restoreSnapshot(
        'Offline mode: showing last synced tasks and local updates.',
      );
      if (restored) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = error.message;
      });
    } catch (_) {
      final restored = await _restoreSnapshot(
        'Offline mode: showing last synced tasks and local updates.',
      );
      if (restored) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = 'Unable to load tasks.';
      });
    }
  }

  Future<List<int>> _loadPendingCompleteIds() async {
    final queued = await _syncQueue.readQueue();
    return queued
        .where((item) => item.key.startsWith(taskCompleteQueuePrefix))
        .map((item) => _toInt(item.payload['task_id']))
        .where((id) => id > 0)
        .toList()
      ..sort();
  }

  TaskIndexPayload _applyPendingCompletesToPayload(
    TaskIndexPayload payload,
    List<int> pendingCompletes,
  ) {
    if (pendingCompletes.isEmpty) {
      return payload;
    }

    return TaskIndexPayload(
      items: payload.items.map((task) {
        if (!pendingCompletes.contains(task.id)) {
          return task;
        }

        return task.copyWith(status: 'completed');
      }).toList(),
      filters: payload.filters,
    );
  }

  Future<bool> _restoreSnapshot(String fallbackMessage) async {
    final json = await _cacheStore.readCacheDocument(_tasksCacheKey);
    if (json == null) {
      return false;
    }

    final snapshot = TaskOfflineSnapshot.fromJson(json);
    final matchesFilters = snapshot.statusFilter == _statusFilter &&
        snapshot.typeFilter == _typeFilter &&
        snapshot.priorityFilter == _priorityFilter &&
        snapshot.visibilityFilter == _visibilityFilter &&
        snapshot.relatedTypeFilter == _relatedTypeFilter &&
        snapshot.assignedToFilter == _assignedToFilter &&
        snapshot.search == _searchController.text.trim();

    if (!matchesFilters && _payload != null) {
      return false;
    }

    if (!mounted) {
      return true;
    }

    _searchController.text = snapshot.search;

    setState(() {
      _payload = _applyPendingCompletesToPayload(
        snapshot.payload,
        snapshot.pendingCompletes,
      );
      _pendingCompleteIds = snapshot.pendingCompletes;
      _statusFilter = snapshot.statusFilter;
      _typeFilter = snapshot.typeFilter;
      _priorityFilter = snapshot.priorityFilter;
      _visibilityFilter = snapshot.visibilityFilter;
      _relatedTypeFilter = snapshot.relatedTypeFilter;
      _assignedToFilter = snapshot.assignedToFilter;
      _loading = false;
      _usingOfflineData = true;
      _statusMessage = snapshot.pendingCompletes.isEmpty
          ? fallbackMessage
          : 'Offline mode: showing cached tasks with queued completions.';
      _error = null;
    });

    return true;
  }

  Future<void> _writeSnapshot() async {
    final payload = _payload;
    if (payload == null) {
      return;
    }

    await _cacheStore.writeCacheDocument(
      _tasksCacheKey,
      TaskOfflineSnapshot(
        payload: payload,
        statusFilter: _statusFilter,
        typeFilter: _typeFilter,
        priorityFilter: _priorityFilter,
        visibilityFilter: _visibilityFilter,
        relatedTypeFilter: _relatedTypeFilter,
        assignedToFilter: _assignedToFilter,
        search: _searchController.text.trim(),
        pendingCompletes: _pendingCompleteIds,
      ).toJson(),
    );
  }

  List<TaskItem> get _visibleItems {
    final items = _payload?.items ?? const <TaskItem>[];

    if (_relatedTypeFilter != 'none') {
      return items;
    }

    return items.where((task) => task.relatedKind == null).toList();
  }

  int get _pendingCount =>
      _visibleItems.where((task) => task.status == 'pending').length;

  int get _inProgressCount =>
      _visibleItems.where((task) => task.status == 'in_progress').length;

  String _labelize(String value) {
    if (value.trim().isEmpty) {
      return 'General';
    }

    return value
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) {
      return '-';
    }

    final date = DateTime.tryParse(value);
    if (date == null) {
      return value;
    }

    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '${date.year}-$month-$day $hour:$minute';
  }

  Future<void> _completeTask(TaskItem task) async {
    if (!_canComplete) {
      return;
    }

    try {
      await widget.api.completeTask(
        token: widget.token,
        taskId: task.id,
      );
      await _syncQueue.remove('$taskCompleteQueuePrefix${task.id}');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Task marked as completed.')),
        );

      await _loadTasks();
    } on ApiException catch (_) {
      await _queueOfflineComplete(task);
    } catch (_) {
      await _queueOfflineComplete(task);
    }
  }

  Future<void> _queueOfflineComplete(TaskItem task) async {
    final payload = _payload;
    if (payload == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = 'Unable to queue task completion offline.';
      });
      return;
    }

    final pending = {
      ..._pendingCompleteIds,
      task.id,
    }.toList()
      ..sort();

    if (!mounted) {
      return;
    }

    setState(() {
      _payload = _applyPendingCompletesToPayload(payload, pending);
      _pendingCompleteIds = pending;
      _usingOfflineData = true;
      _statusMessage = 'Task completion saved locally and queued for sync.';
      _error = null;
    });

    await _syncQueue.upsert(
      OfflineSyncOperation(
        key: '$taskCompleteQueuePrefix${task.id}',
        type: 'task_complete',
        payload: {
          'task_id': task.id,
        },
        createdAt: DateTime.now().toIso8601String(),
      ),
    );

    await _writeSnapshot();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Task completion saved locally for later sync.'),
        ),
      );
  }

  Future<void> _deleteTask(TaskItem task) async {
    if (!_canDelete) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Delete "${task.title}"?'),
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

    if (confirmed != true) {
      return;
    }

    try {
      await widget.api.deleteTask(
        token: widget.token,
        taskId: task.id,
      );

      if (!mounted) {
        return;
      }

      await _loadTasks();
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
        _error = 'Unable to delete task.';
      });
    }
  }

  Future<void> _openTaskDialog({TaskItem? task}) async {
    if (task == null && !_canCreate) {
      return;
    }

    if (task != null && !_canEdit) {
      return;
    }

    final filters = _payload?.filters;
    if (filters == null) {
      return;
    }

    final titleController = TextEditingController(text: task?.title ?? '');
    final descriptionController =
        TextEditingController(text: task?.description ?? '');
    final dueAtController = TextEditingController(
      text: task?.dueAt != null ? _formatDate(task!.dueAt) : '',
    );

    String type = task?.type ?? 'general';
    String status = task?.status ?? 'pending';
    String priority = task?.priority ?? 'medium';
    String visibility = task?.visibility ?? 'school';
    String relatedKind = task?.relatedKind ?? '';
    int? assignedTo = task?.assignee?.id;
    int? relatedId = task?.related?.id;
    bool localSaving = false;
    String? dialogError;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final relatedOptions = relatedKind == 'student'
                ? filters.students
                : relatedKind == 'staff'
                    ? filters.staffs
                    : const <TaskRelatedTarget>[];

            return AlertDialog(
              title: Text(task == null ? 'Create Task' : 'Edit Task'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: type,
                      items: filters.types
                          .map(
                            (option) => DropdownMenuItem(
                              value: option.value,
                              child: Text(option.label),
                            ),
                          )
                          .toList(),
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: localSaving
                          ? null
                          : (value) {
                              if (value == null) {
                                return;
                              }
                              setDialogState(() {
                                type = value;
                              });
                            },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: status,
                      items: filters.statuses
                          .map(
                            (option) => DropdownMenuItem(
                              value: option.value,
                              child: Text(option.label),
                            ),
                          )
                          .toList(),
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: localSaving
                          ? null
                          : (value) {
                              if (value == null) {
                                return;
                              }
                              setDialogState(() {
                                status = value;
                              });
                            },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: priority,
                      items: filters.priorities
                          .map(
                            (option) => DropdownMenuItem(
                              value: option.value,
                              child: Text(option.label),
                            ),
                          )
                          .toList(),
                      decoration: const InputDecoration(
                        labelText: 'Priority',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: localSaving
                          ? null
                          : (value) {
                              if (value == null) {
                                return;
                              }
                              setDialogState(() {
                                priority = value;
                              });
                            },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: dueAtController,
                      decoration: const InputDecoration(
                        labelText: 'Due at (YYYY-MM-DD HH:MM)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int?>(
                      value: assignedTo,
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Unassigned'),
                        ),
                        ...filters.assignees.map(
                          (option) => DropdownMenuItem<int?>(
                            value: option.id,
                            child: Text(option.name),
                          ),
                        ),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Assign to',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: localSaving
                          ? null
                          : (value) {
                              setDialogState(() {
                                assignedTo = value;
                              });
                            },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: visibility,
                      items: const [
                        DropdownMenuItem(
                          value: 'school',
                          child: Text('School'),
                        ),
                        DropdownMenuItem(
                          value: 'assigned',
                          child: Text('Assigned'),
                        ),
                        DropdownMenuItem(
                          value: 'private',
                          child: Text('Private'),
                        ),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Visibility',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: localSaving
                          ? null
                          : (value) {
                              if (value == null) {
                                return;
                              }
                              setDialogState(() {
                                visibility = value;
                              });
                            },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: relatedKind,
                      items: const [
                        DropdownMenuItem(
                          value: '',
                          child: Text('General task'),
                        ),
                        DropdownMenuItem(
                          value: 'student',
                          child: Text('Student'),
                        ),
                        DropdownMenuItem(
                          value: 'staff',
                          child: Text('Staff'),
                        ),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Related to',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: localSaving
                          ? null
                          : (value) {
                              setDialogState(() {
                                relatedKind = value ?? '';
                                relatedId = null;
                              });
                            },
                    ),
                    if (relatedKind.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int?>(
                        value: relatedId,
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Select related record'),
                          ),
                          ...relatedOptions.map(
                            (option) => DropdownMenuItem<int?>(
                              value: option.id,
                              child: Text(option.name),
                            ),
                          ),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Related record',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: localSaving
                            ? null
                            : (value) {
                                setDialogState(() {
                                  relatedId = value;
                                });
                              },
                      ),
                    ],
                    if (dialogError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        dialogError!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFFB42318),
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      localSaving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: localSaving
                      ? null
                      : () async {
                          final title = titleController.text.trim();
                          if (title.isEmpty) {
                            setDialogState(() {
                              dialogError = 'Task title is required.';
                            });
                            return;
                          }

                          if (visibility == 'assigned' && assignedTo == null) {
                            setDialogState(() {
                              dialogError =
                                  'Assigned visibility requires an assignee.';
                            });
                            return;
                          }

                          if (relatedKind.isNotEmpty && relatedId == null) {
                            setDialogState(() {
                              dialogError =
                                  'Select a related ${_labelize(relatedKind).toLowerCase()}.';
                            });
                            return;
                          }

                          setDialogState(() {
                            localSaving = true;
                            dialogError = null;
                          });

                          setState(() {
                            _saving = true;
                          });

                          try {
                            final payload = <String, dynamic>{
                              'title': title,
                              'description':
                                  descriptionController.text.trim().isEmpty
                                      ? null
                                      : descriptionController.text.trim(),
                              'type': type,
                              'status': status,
                              'priority': priority,
                              'due_at': dueAtController.text.trim().isEmpty
                                  ? null
                                  : dueAtController.text.trim().replaceFirst(
                                        ' ',
                                        'T',
                                      ),
                              'assigned_to': assignedTo,
                              'visibility': visibility,
                              'related_kind':
                                  relatedKind.isEmpty ? null : relatedKind,
                              'related_id': relatedId,
                            };

                            if (task == null) {
                              await widget.api.createTask(
                                token: widget.token,
                                payload: payload,
                              );
                            } else {
                              await widget.api.updateTask(
                                token: widget.token,
                                taskId: task.id,
                                payload: payload,
                              );
                            }

                            if (!mounted || !context.mounted) {
                              return;
                            }

                            Navigator.of(context).pop();
                            await _loadTasks();
                          } on ApiException catch (error) {
                            setDialogState(() {
                              localSaving = false;
                              dialogError = error.message;
                            });
                          } catch (_) {
                            setDialogState(() {
                              localSaving = false;
                              dialogError = 'Unable to save task.';
                            });
                          } finally {
                            if (mounted) {
                              setState(() {
                                _saving = false;
                              });
                            }
                          }
                        },
                  child: Text(localSaving ? 'Saving...' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();
    dueAtController.dispose();
  }

  Widget _buildFilters() {
    final filters = _payload?.filters;
    final assignees = filters?.assignees ?? const <UserSummary>[];

    return Column(
      children: [
        if (_statusMessage != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4CE),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  _usingOfflineData
                      ? Icons.cloud_off_outlined
                      : Icons.sync_problem_outlined,
                  size: 18,
                  color: const Color(0xFF7A4F01),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _statusMessage!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF7A4F01),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
          ),
        TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            labelText: 'Search tasks',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _loadTasks(),
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
                  ...(filters?.statuses ?? const <TaskOption>[]).map(
                    (option) => DropdownMenuItem(
                      value: option.value,
                      child: Text(option.label),
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
                  _loadTasks();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _typeFilter,
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('All types'),
                  ),
                  ...(filters?.types ?? const <TaskOption>[]).map(
                    (option) => DropdownMenuItem(
                      value: option.value,
                      child: Text(option.label),
                    ),
                  ),
                ],
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _typeFilter = value ?? '';
                  });
                  _loadTasks();
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
                value: _priorityFilter,
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('All priorities'),
                  ),
                  ...(filters?.priorities ?? const <TaskOption>[]).map(
                    (option) => DropdownMenuItem(
                      value: option.value,
                      child: Text(option.label),
                    ),
                  ),
                ],
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _priorityFilter = value ?? '';
                  });
                  _loadTasks();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<int?>(
                value: _assignedToFilter,
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('All assignees'),
                  ),
                  ...assignees.map(
                    (user) => DropdownMenuItem<int?>(
                      value: user.id,
                      child: Text(user.name),
                    ),
                  ),
                ],
                decoration: const InputDecoration(
                  labelText: 'Assigned to',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _assignedToFilter = value;
                  });
                  _loadTasks();
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
                value: _relatedTypeFilter,
                items: const [
                  DropdownMenuItem(value: '', child: Text('All related')),
                  DropdownMenuItem(
                    value: 'student',
                    child: Text('Student tasks'),
                  ),
                  DropdownMenuItem(value: 'staff', child: Text('Staff tasks')),
                  DropdownMenuItem(value: 'none', child: Text('General tasks')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Related',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _relatedTypeFilter = value ?? '';
                  });
                  _loadTasks();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _visibilityFilter,
                items: const [
                  DropdownMenuItem(
                    value: '',
                    child: Text('All visibility'),
                  ),
                  DropdownMenuItem(value: 'school', child: Text('School')),
                  DropdownMenuItem(value: 'assigned', child: Text('Assigned')),
                  DropdownMenuItem(value: 'private', child: Text('Private')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Visibility',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _visibilityFilter = value ?? '';
                  });
                  _loadTasks();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTaskRow(TaskItem task) {
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
            task.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (task.description != null && task.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(task.description!),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(label: _labelize(task.type)),
              _InfoChip(label: _labelize(task.status)),
              _InfoChip(label: _labelize(task.priority)),
              _InfoChip(label: _labelize(task.visibility)),
              _InfoChip(
                label: task.related != null
                    ? '${task.related!.name} (${_labelize(task.relatedKind ?? '')})'
                    : 'General',
              ),
              if (_pendingCompleteIds.contains(task.id))
                const _InfoChip(label: 'Pending Sync'),
            ],
          ),
          const SizedBox(height: 10),
          Text('Assigned to: ${task.assignee?.name ?? '-'}'),
          Text('Due: ${_formatDate(task.dueAt)}'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_canEdit)
                OutlinedButton(
                  onPressed: _saving ? null : () => _openTaskDialog(task: task),
                  child: const Text('Edit'),
                ),
              if (_canComplete && task.status != 'completed')
                OutlinedButton(
                  onPressed: _saving ? null : () => _completeTask(task),
                  child: const Text('Complete'),
                ),
              if (_canDelete)
                OutlinedButton(
                  onPressed: _saving ? null : () => _deleteTask(task),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          IconButton(
            onPressed: _loading ? null : () => _loadTasks(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          if (_canCreate)
            IconButton(
              onPressed: _loading || _saving ? null : () => _openTaskDialog(),
              icon: const Icon(Icons.add),
              tooltip: 'Add task',
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          _buildFilters(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: 'Pending',
                  value: '$_pendingCount',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  label: 'In Progress',
                  value: '$_inProgressCount',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_visibleItems.isEmpty)
            const Text('No tasks found for the selected filters.')
          else
            ..._visibleItems.map(_buildTaskRow),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFB42318),
                  ),
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
        ],
      ),
    );
  }
}

const _tasksCacheKey = 'tasks_snapshot';

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

int _toInt(dynamic value) {
  if (value is int) {
    return value;
  }

  if (value is double) {
    return value.round();
  }

  return int.tryParse('$value') ?? 0;
}
