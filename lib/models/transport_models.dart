class BusItem {
  const BusItem({
    required this.id,
    required this.busNumber,
    required this.capacity,
    required this.route,
    required this.contact,
    required this.driverName,
    required this.driverPhone,
    required this.driverLicence,
  });

  final int id;
  final String busNumber;
  final int? capacity;
  final String? route;
  final String? contact;
  final String? driverName;
  final String? driverPhone;
  final String? driverLicence;

  factory BusItem.fromJson(Map<String, dynamic> json) {
    return BusItem(
      id: _toInt(json['id']),
      busNumber: '${json['bus_number'] ?? ''}'.trim(),
      capacity: _toNullableInt(json['capacity']),
      route: _toNullableString(json['route']),
      contact: _toNullableString(json['contact']),
      driverName: _toNullableString(json['driver_name']),
      driverPhone: _toNullableString(json['driver_phone']),
      driverLicence: _toNullableString(json['driver_licence']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bus_number': busNumber,
      'capacity': capacity,
      'route': route,
      'contact': contact,
      'driver_name': driverName,
      'driver_phone': driverPhone,
      'driver_licence': driverLicence,
    };
  }
}

class BusStudentItem {
  const BusStudentItem({
    required this.id,
    required this.name,
    required this.phone,
    required this.rollNumber,
    required this.levelName,
    required this.className,
    required this.section,
    required this.gender,
  });

  final int id;
  final String name;
  final String? phone;
  final String? rollNumber;
  final String? levelName;
  final String? className;
  final String? section;
  final String? gender;

  factory BusStudentItem.fromJson(Map<String, dynamic> json) {
    final currentYear = json['currentYear'];
    final level = currentYear is Map<String, dynamic> ? currentYear['level'] : null;
    final schoolClass =
        currentYear is Map<String, dynamic> ? currentYear['schoolClass'] : null;

    return BusStudentItem(
      id: _toInt(json['id']),
      name: '${json['name'] ?? ''}'.trim(),
      phone: _toNullableString(json['phone']),
      rollNumber: currentYear is Map<String, dynamic>
          ? _toNullableString(currentYear['roll_number'])
          : _toNullableString(json['roll_number']),
      levelName: level is Map<String, dynamic>
          ? _toNullableString(level['name'])
          : _toNullableString(json['level_name']),
      className: schoolClass is Map<String, dynamic>
          ? _toNullableString(schoolClass['name'])
          : _toNullableString(json['class_name']),
      section: schoolClass is Map<String, dynamic>
          ? _toNullableString(schoolClass['section'])
          : _toNullableString(json['section']),
      gender: _toNullableString(json['gender']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'roll_number': rollNumber,
      'level_name': levelName,
      'class_name': className,
      'section': section,
      'gender': gender,
    };
  }
}

class BusStudentReport {
  const BusStudentReport({
    required this.buses,
    required this.count,
    required this.generatedAt,
  });

  final List<BusStudentReportGroup> buses;
  final int count;
  final String? generatedAt;

  factory BusStudentReport.fromJson(Map<String, dynamic> json) {
    return BusStudentReport(
      buses: (json['buses'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(BusStudentReportGroup.fromJson)
          .toList(),
      count: _toInt(json['count']),
      generatedAt: _toNullableString(json['generated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'buses': buses.map((item) => item.toJson()).toList(),
      'count': count,
      'generated_at': generatedAt,
    };
  }
}

class BusStudentReportGroup {
  const BusStudentReportGroup({
    required this.id,
    required this.name,
    required this.route,
    required this.students,
  });

  final int id;
  final String name;
  final String? route;
  final List<BusStudentItem> students;

  factory BusStudentReportGroup.fromJson(Map<String, dynamic> json) {
    return BusStudentReportGroup(
      id: _toInt(json['id']),
      name: '${json['name'] ?? ''}'.trim(),
      route: _toNullableString(json['route']),
      students: (json['students'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(BusStudentItem.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'route': route,
      'students': students.map((item) => item.toJson()).toList(),
    };
  }
}

class TransportStudentDirectoryItem {
  const TransportStudentDirectoryItem({
    required this.id,
    required this.name,
    required this.rollNumber,
    required this.gender,
    required this.levelName,
    required this.className,
    required this.section,
    required this.phone,
  });

  final int id;
  final String name;
  final String? rollNumber;
  final String? gender;
  final String? levelName;
  final String? className;
  final String? section;
  final String? phone;

  factory TransportStudentDirectoryItem.fromJson(Map<String, dynamic> json) {
    return TransportStudentDirectoryItem(
      id: _toInt(json['id']),
      name: '${json['name'] ?? ''}'.trim(),
      rollNumber: _toNullableString(json['roll_number']),
      gender: _toNullableString(json['gender']),
      levelName: _toNullableString(json['level_name']),
      className: _toNullableString(json['class_name']),
      section: _toNullableString(json['section']),
      phone: _toNullableString(json['phone']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'roll_number': rollNumber,
      'gender': gender,
      'level_name': levelName,
      'class_name': className,
      'section': section,
      'phone': phone,
    };
  }
}

class TransportOfflineSnapshot {
  const TransportOfflineSnapshot({
    required this.buses,
    required this.report,
    required this.studentDirectory,
    required this.assignedStudentsByBus,
    required this.pendingAssignments,
  });

  final List<BusItem> buses;
  final BusStudentReport? report;
  final List<TransportStudentDirectoryItem> studentDirectory;
  final Map<int, List<BusStudentItem>> assignedStudentsByBus;
  final Map<int, List<int>> pendingAssignments;

  factory TransportOfflineSnapshot.fromJson(Map<String, dynamic> json) {
    final assignedJson =
        json['assigned_students_by_bus'] as Map<String, dynamic>? ?? const {};
    final pendingJson =
        json['pending_assignments'] as Map<String, dynamic>? ?? const {};

    return TransportOfflineSnapshot(
      buses: (json['buses'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(BusItem.fromJson)
          .toList(),
      report: json['report'] is Map<String, dynamic>
          ? BusStudentReport.fromJson(json['report'] as Map<String, dynamic>)
          : null,
      studentDirectory: (json['student_directory'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(TransportStudentDirectoryItem.fromJson)
          .toList(),
      assignedStudentsByBus: {
        for (final entry in assignedJson.entries)
          _toInt(entry.key): (entry.value as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(BusStudentItem.fromJson)
              .toList(),
      },
      pendingAssignments: {
        for (final entry in pendingJson.entries)
          _toInt(entry.key): (entry.value as List<dynamic>? ?? const [])
              .map(_toInt)
              .where((value) => value > 0)
              .toList(),
      },
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'buses': buses.map((item) => item.toJson()).toList(),
      'report': report?.toJson(),
      'student_directory': studentDirectory.map((item) => item.toJson()).toList(),
      'assigned_students_by_bus': {
        for (final entry in assignedStudentsByBus.entries)
          '${entry.key}': entry.value.map((item) => item.toJson()).toList(),
      },
      'pending_assignments': {
        for (final entry in pendingAssignments.entries) '${entry.key}': entry.value,
      },
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
