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

  Map<String, dynamic> toJson() {
    return {
      'data': items.map((item) => item.toJson()).toList(),
      'filters': filters.toJson(),
    };
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

  TaskItem copyWith({
    int? id,
    String? title,
    String? description,
    String? type,
    String? status,
    String? priority,
    String? visibility,
    String? dueAt,
    String? completedAt,
    String? createdAt,
    UserSummary? creator,
    UserSummary? assignee,
    String? relatedKind,
    TaskRelatedTarget? related,
  }) {
    return TaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      visibility: visibility ?? this.visibility,
      dueAt: dueAt ?? this.dueAt,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      creator: creator ?? this.creator,
      assignee: assignee ?? this.assignee,
      relatedKind: relatedKind ?? this.relatedKind,
      related: related ?? this.related,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type,
      'status': status,
      'priority': priority,
      'visibility': visibility,
      'due_at': dueAt,
      'completed_at': completedAt,
      'created_at': createdAt,
      'creator': creator?.toJson(),
      'assignee': assignee?.toJson(),
      'related_kind': relatedKind,
      'related': related?.toJson(),
    };
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
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

  Map<String, dynamic> toJson() {
    return {
      'types': types.map((option) => option.toJson()).toList(),
      'statuses': statuses.map((option) => option.toJson()).toList(),
      'priorities': priorities.map((option) => option.toJson()).toList(),
      'assignees': assignees.map((user) => user.toJson()).toList(),
      'related': {
        'students': students.map((item) => item.toJson()).toList(),
        'staffs': staffs.map((item) => item.toJson()).toList(),
      },
    };
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

  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'label': label,
    };
  }
}

class TaskOfflineSnapshot {
  const TaskOfflineSnapshot({
    required this.payload,
    required this.statusFilter,
    required this.typeFilter,
    required this.priorityFilter,
    required this.visibilityFilter,
    required this.relatedTypeFilter,
    required this.assignedToFilter,
    required this.search,
    required this.pendingCompletes,
  });

  final TaskIndexPayload payload;
  final String statusFilter;
  final String typeFilter;
  final String priorityFilter;
  final String visibilityFilter;
  final String relatedTypeFilter;
  final int? assignedToFilter;
  final String search;
  final List<int> pendingCompletes;

  factory TaskOfflineSnapshot.fromJson(Map<String, dynamic> json) {
    return TaskOfflineSnapshot(
      payload: TaskIndexPayload.fromJson(
        json['payload'] as Map<String, dynamic>? ?? const {},
      ),
      statusFilter: '${json['status_filter'] ?? ''}'.trim(),
      typeFilter: '${json['type_filter'] ?? ''}'.trim(),
      priorityFilter: '${json['priority_filter'] ?? ''}'.trim(),
      visibilityFilter: '${json['visibility_filter'] ?? ''}'.trim(),
      relatedTypeFilter: '${json['related_type_filter'] ?? ''}'.trim(),
      assignedToFilter: _toNullableInt(json['assigned_to_filter']),
      search: '${json['search'] ?? ''}'.trim(),
      pendingCompletes: (json['pending_completes'] as List<dynamic>? ?? const [])
          .map((value) => _toInt(value))
          .where((value) => value > 0)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'payload': payload.toJson(),
      'status_filter': statusFilter,
      'type_filter': typeFilter,
      'priority_filter': priorityFilter,
      'visibility_filter': visibilityFilter,
      'related_type_filter': relatedTypeFilter,
      'assigned_to_filter': assignedToFilter,
      'search': search,
      'pending_completes': pendingCompletes,
    };
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

int? _toNullableInt(dynamic value) {
  if (value == null) {
    return null;
  }

  return int.tryParse('$value');
}

String? _toNullableString(dynamic value) {
  final normalized = '${value ?? ''}'.trim();
  if (normalized.isEmpty) {
    return null;
  }

  return normalized;
}
