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
