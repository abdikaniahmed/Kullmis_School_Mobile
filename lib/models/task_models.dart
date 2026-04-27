import 'hr_models.dart';

class TaskIndexPayload {
  const TaskIndexPayload({
    required this.items,
    required this.filters,
  });

  final List<TaskItem> items;
  final TaskFilterOptions filters;

  factory TaskIndexPayload.fromJson(Map<String, dynamic> json) {
    final items = (json['data'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(TaskItem.fromJson)
        .toList();

    return TaskIndexPayload(
      items: items,
      filters: TaskFilterOptions.fromJson(
        (json['filters'] as Map<String, dynamic>? ?? const {}),
      ),
    );
  }
}

class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.status,
    required this.priority,
    required this.visibility,
    required this.dueAt,
    required this.completedAt,
    required this.createdAt,
    required this.creator,
    required this.assignee,
    required this.relatedKind,
    required this.related,
  });

  final int id;
  final String title;
  final String? description;
  final String type;
  final String status;
  final String priority;
  final String visibility;
  final String? dueAt;
  final String? completedAt;
  final String? createdAt;
  final UserSummary? creator;
  final UserSummary? assignee;
  final String? relatedKind;
  final TaskRelatedTarget? related;

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      id: _toInt(json['id']),
      title: '${json['title'] ?? ''}'.trim(),
      description: _toNullableString(json['description']),
      type: '${json['type'] ?? ''}'.trim(),
      status: '${json['status'] ?? ''}'.trim(),
      priority: '${json['priority'] ?? ''}'.trim(),
      visibility: '${json['visibility'] ?? ''}'.trim(),
      dueAt: _toNullableString(json['due_at']),
      completedAt: _toNullableString(json['completed_at']),
      createdAt: _toNullableString(json['created_at']),
      creator: UserSummary.fromDynamic(json['creator']),
      assignee: UserSummary.fromDynamic(json['assignee']),
      relatedKind: _toNullableString(json['related_kind']),
      related: TaskRelatedTarget.fromDynamic(json['related']),
    );
  }
}

class TaskRelatedTarget {
  const TaskRelatedTarget({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  static TaskRelatedTarget? fromDynamic(dynamic value) {
    if (value is! Map<String, dynamic>) {
      return null;
    }

    return TaskRelatedTarget(
      id: _toInt(value['id']),
      name: '${value['name'] ?? ''}'.trim(),
    );
  }
}

class TaskFilterOptions {
  const TaskFilterOptions({
    required this.types,
    required this.statuses,
    required this.priorities,
    required this.assignees,
    required this.students,
    required this.staffs,
  });

  final List<TaskOption> types;
  final List<TaskOption> statuses;
  final List<TaskOption> priorities;
  final List<UserSummary> assignees;
  final List<TaskRelatedTarget> students;
  final List<TaskRelatedTarget> staffs;

  factory TaskFilterOptions.fromJson(Map<String, dynamic> json) {
    final related = json['related'];
    final relatedMap = related is Map<String, dynamic> ? related : const {};

    return TaskFilterOptions(
      types: _optionsFromList(json['types']),
      statuses: _optionsFromList(json['statuses']),
      priorities: _optionsFromList(json['priorities']),
      assignees: (json['assignees'] as List<dynamic>? ?? const [])
          .map(UserSummary.fromDynamic)
          .whereType<UserSummary>()
          .toList(),
      students: (relatedMap['students'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(TaskRelatedTarget.fromDynamic)
          .whereType<TaskRelatedTarget>()
          .toList(),
      staffs: (relatedMap['staffs'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(TaskRelatedTarget.fromDynamic)
          .whereType<TaskRelatedTarget>()
          .toList(),
    );
  }

  static List<TaskOption> _optionsFromList(dynamic values) {
    if (values is! List) {
      return const [];
    }

    return values
        .whereType<Map<String, dynamic>>()
        .map(TaskOption.fromJson)
        .toList();
  }
}

class TaskOption {
  const TaskOption({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  factory TaskOption.fromJson(Map<String, dynamic> json) {
    return TaskOption(
      value: '${json['value'] ?? ''}'.trim(),
      label: '${json['label'] ?? ''}'.trim(),
    );
  }
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

String? _toNullableString(dynamic value) {
  final normalized = '${value ?? ''}'.trim();
  if (normalized.isEmpty) {
    return null;
  }

  return normalized;
}
