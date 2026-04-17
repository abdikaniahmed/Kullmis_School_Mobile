class AcademicYearListPage {
  const AcademicYearListPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.from,
    required this.to,
    required this.hasPreviousPage,
    required this.hasNextPage,
  });

  final List<AcademicYearListItem> items;
  final int currentPage;
  final int lastPage;
  final int total;
  final int? from;
  final int? to;
  final bool hasPreviousPage;
  final bool hasNextPage;

  factory AcademicYearListPage.fromJson(Map<String, dynamic> json) {
    final items = (json['data'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(AcademicYearListItem.fromJson)
        .toList();

    return AcademicYearListPage(
      items: items,
      currentPage: _toInt(json['current_page']),
      lastPage: _toInt(json['last_page']),
      total: _toInt(json['total']),
      from: _toNullableInt(json['from']),
      to: _toNullableInt(json['to']),
      hasPreviousPage: json['prev_page_url'] != null,
      hasNextPage: json['next_page_url'] != null,
    );
  }
}

class AcademicYearListItem {
  const AcademicYearListItem({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.isActive,
  });

  final int id;
  final String name;
  final String? startDate;
  final String? endDate;
  final bool isActive;

  factory AcademicYearListItem.fromJson(Map<String, dynamic> json) {
    return AcademicYearListItem(
      id: _toInt(json['id']),
      name: '${json['name'] ?? ''}'.trim(),
      startDate: _toNullableString(json['start_date']),
      endDate: _toNullableString(json['end_date']),
      isActive: json['is_active'] == true,
    );
  }
}

class TermListPage {
  const TermListPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.from,
    required this.to,
    required this.hasPreviousPage,
    required this.hasNextPage,
  });

  final List<TermListItem> items;
  final int currentPage;
  final int lastPage;
  final int total;
  final int? from;
  final int? to;
  final bool hasPreviousPage;
  final bool hasNextPage;

  factory TermListPage.fromJson(Map<String, dynamic> json) {
    final items = (json['data'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(TermListItem.fromJson)
        .toList();

    return TermListPage(
      items: items,
      currentPage: _toInt(json['current_page']),
      lastPage: _toInt(json['last_page']),
      total: _toInt(json['total']),
      from: _toNullableInt(json['from']),
      to: _toNullableInt(json['to']),
      hasPreviousPage: json['prev_page_url'] != null,
      hasNextPage: json['next_page_url'] != null,
    );
  }
}

class TermListItem {
  const TermListItem({
    required this.id,
    required this.name,
    required this.academicYearId,
    required this.academicYearName,
    required this.startDate,
    required this.endDate,
    required this.isActive,
  });

  final int id;
  final String name;
  final int? academicYearId;
  final String? academicYearName;
  final String? startDate;
  final String? endDate;
  final bool isActive;

  factory TermListItem.fromJson(Map<String, dynamic> json) {
    final academicYear = json['academic_year'];
    return TermListItem(
      id: _toInt(json['id']),
      name: '${json['name'] ?? ''}'.trim(),
      academicYearId: _toNullableInt(json['academic_year_id']),
      academicYearName: academicYear is Map<String, dynamic>
          ? _toNullableString(academicYear['name'])
          : null,
      startDate: _toNullableString(json['start_date']),
      endDate: _toNullableString(json['end_date']),
      isActive: json['is_active'] == true,
    );
  }
}

class SubjectListPage {
  const SubjectListPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.from,
    required this.to,
    required this.hasPreviousPage,
    required this.hasNextPage,
  });

  final List<SubjectListItem> items;
  final int currentPage;
  final int lastPage;
  final int total;
  final int? from;
  final int? to;
  final bool hasPreviousPage;
  final bool hasNextPage;

  factory SubjectListPage.fromJson(Map<String, dynamic> json) {
    final items = (json['data'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(SubjectListItem.fromJson)
        .toList();

    return SubjectListPage(
      items: items,
      currentPage: _toInt(json['current_page']),
      lastPage: _toInt(json['last_page']),
      total: _toInt(json['total']),
      from: _toNullableInt(json['from']),
      to: _toNullableInt(json['to']),
      hasPreviousPage: json['prev_page_url'] != null,
      hasNextPage: json['next_page_url'] != null,
    );
  }
}

class SubjectListItem {
  const SubjectListItem({
    required this.id,
    required this.orderNumber,
    required this.name,
    required this.type,
  });

  final int id;
  final int? orderNumber;
  final String name;
  final String type;

  factory SubjectListItem.fromJson(Map<String, dynamic> json) {
    return SubjectListItem(
      id: _toInt(json['id']),
      orderNumber: _toNullableInt(json['order_number']),
      name: '${json['name'] ?? ''}'.trim(),
      type: '${json['type'] ?? ''}'.trim(),
    );
  }
}

class LevelListPage {
  const LevelListPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.from,
    required this.to,
    required this.hasPreviousPage,
    required this.hasNextPage,
  });

  final List<LevelListItem> items;
  final int currentPage;
  final int lastPage;
  final int total;
  final int? from;
  final int? to;
  final bool hasPreviousPage;
  final bool hasNextPage;

  factory LevelListPage.fromJson(Map<String, dynamic> json) {
    final items = (json['data'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(LevelListItem.fromJson)
        .toList();

    return LevelListPage(
      items: items,
      currentPage: _toInt(json['current_page']),
      lastPage: _toInt(json['last_page']),
      total: _toInt(json['total']),
      from: _toNullableInt(json['from']),
      to: _toNullableInt(json['to']),
      hasPreviousPage: json['prev_page_url'] != null,
      hasNextPage: json['next_page_url'] != null,
    );
  }
}

class LevelListItem {
  const LevelListItem({
    required this.id,
    required this.order,
    required this.name,
    required this.description,
    required this.subjects,
  });

  final int id;
  final int? order;
  final String name;
  final String? description;
  final List<SubjectListItem> subjects;

  factory LevelListItem.fromJson(Map<String, dynamic> json) {
    final subjects = (json['subjects'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(SubjectListItem.fromJson)
        .toList();

    return LevelListItem(
      id: _toInt(json['id']),
      order: _toNullableInt(json['order_n']),
      name: '${json['name'] ?? ''}'.trim(),
      description: _toNullableString(json['description']),
      subjects: subjects,
    );
  }
}

class ClassListPage {
  const ClassListPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.from,
    required this.to,
    required this.hasPreviousPage,
    required this.hasNextPage,
  });

  final List<ClassListItem> items;
  final int currentPage;
  final int lastPage;
  final int total;
  final int? from;
  final int? to;
  final bool hasPreviousPage;
  final bool hasNextPage;

  factory ClassListPage.fromJson(Map<String, dynamic> json) {
    final items = (json['data'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ClassListItem.fromJson)
        .toList();

    return ClassListPage(
      items: items,
      currentPage: _toInt(json['current_page']),
      lastPage: _toInt(json['last_page']),
      total: _toInt(json['total']),
      from: _toNullableInt(json['from']),
      to: _toNullableInt(json['to']),
      hasPreviousPage: json['prev_page_url'] != null,
      hasNextPage: json['next_page_url'] != null,
    );
  }
}

class ClassListItem {
  const ClassListItem({
    required this.id,
    required this.order,
    required this.name,
    required this.levelId,
    required this.levelName,
    required this.section,
  });

  final int id;
  final int? order;
  final String name;
  final int? levelId;
  final String? levelName;
  final String? section;

  factory ClassListItem.fromJson(Map<String, dynamic> json) {
    final level = json['level'];
    return ClassListItem(
      id: _toInt(json['id']),
      order: _toNullableInt(json['order_n']),
      name: '${json['name'] ?? ''}'.trim(),
      levelId: _toNullableInt(json['level_id']),
      levelName: level is Map<String, dynamic>
          ? _toNullableString(level['name'])
          : null,
      section: _toNullableString(json['section']),
    );
  }
}

class PromotionOverview {
  const PromotionOverview({
    required this.activeAcademicYear,
    required this.previewAcademicYearId,
    required this.academicYears,
    required this.levels,
    required this.promotionRules,
  });

  final AcademicYearListItem? activeAcademicYear;
  final int? previewAcademicYearId;
  final List<AcademicYearListItem> academicYears;
  final List<PromotionLevel> levels;
  final List<PromotionRule> promotionRules;

  factory PromotionOverview.fromJson(Map<String, dynamic> json) {
    final activeYear = json['active_academic_year'];
    return PromotionOverview(
      activeAcademicYear: activeYear is Map<String, dynamic>
          ? AcademicYearListItem.fromJson(activeYear)
          : null,
      previewAcademicYearId: _toNullableInt(json['preview_academic_year_id']),
      academicYears: (json['academic_years'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AcademicYearListItem.fromJson)
          .toList(),
      levels: (json['levels'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PromotionLevel.fromJson)
          .toList(),
      promotionRules: (json['promotion_rules'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PromotionRule.fromJson)
          .toList(),
    );
  }
}

class PromotionLevel {
  const PromotionLevel({
    required this.id,
    required this.name,
    required this.classes,
  });

  final int id;
  final String name;
  final List<PromotionClass> classes;

  factory PromotionLevel.fromJson(Map<String, dynamic> json) {
    return PromotionLevel(
      id: _toInt(json['id']),
      name: '${json['name'] ?? ''}'.trim(),
      classes: (json['classes'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PromotionClass.fromJson)
          .toList(),
    );
  }
}

class PromotionClass {
  const PromotionClass({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  factory PromotionClass.fromJson(Map<String, dynamic> json) {
    return PromotionClass(
      id: _toInt(json['id']),
      name: '${json['name'] ?? ''}'.trim(),
    );
  }
}

class PromotionRule {
  const PromotionRule({
    required this.fromLevelId,
    required this.fromClassId,
    required this.toLevelId,
    required this.toClassId,
    required this.isGraduation,
    required this.eligibleCount,
  });

  final int? fromLevelId;
  final int? fromClassId;
  final int? toLevelId;
  final int? toClassId;
  final bool isGraduation;
  final int eligibleCount;

  factory PromotionRule.fromJson(Map<String, dynamic> json) {
    return PromotionRule(
      fromLevelId: _toNullableInt(json['from_level_id']),
      fromClassId: _toNullableInt(json['from_class_id']),
      toLevelId: _toNullableInt(json['to_level_id']),
      toClassId: _toNullableInt(json['to_class_id']),
      isGraduation: json['is_graduation'] == true,
      eligibleCount: _toInt(json['eligible_count']),
    );
  }
}

class PromotionSummary {
  const PromotionSummary({
    required this.processed,
    required this.promoted,
    required this.graduated,
    required this.created,
    required this.updated,
    required this.unmatchedActiveStudents,
  });

  final int processed;
  final int promoted;
  final int graduated;
  final int created;
  final int updated;
  final int unmatchedActiveStudents;

  factory PromotionSummary.fromJson(Map<String, dynamic> json) {
    return PromotionSummary(
      processed: _toInt(json['processed']),
      promoted: _toInt(json['promoted']),
      graduated: _toInt(json['graduated']),
      created: _toInt(json['created']),
      updated: _toInt(json['updated']),
      unmatchedActiveStudents: _toInt(json['unmatched_active_students']),
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
