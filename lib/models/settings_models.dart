class SchoolProfile {
  const SchoolProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.address,
    required this.contact,
    required this.telephone,
    required this.logo,
    required this.logoUrl,
    required this.status,
  });

  final int id;
  final String name;
  final String email;
  final String? address;
  final String? contact;
  final String? telephone;
  final String? logo;
  final String? logoUrl;
  final String? status;

  factory SchoolProfile.fromJson(Map<String, dynamic> json) {
    return SchoolProfile(
      id: _toInt(json['id']),
      name: '${json['name'] ?? ''}'.trim(),
      email: '${json['email'] ?? ''}'.trim(),
      address: _toNullableString(json['address']),
      contact: _toNullableString(json['contact']),
      telephone: _toNullableString(json['telephone']),
      logo: _toNullableString(json['logo']),
      logoUrl: _toNullableString(json['logo_url']),
      status: _toNullableString(json['status']),
    );
  }
}

class SetupConfig {
  const SetupConfig({
    required this.studentRollPrefix,
    required this.studentRollNextNumber,
    required this.invoicePrefix,
    required this.invoiceNextNumber,
    required this.invoiceNumberIncludeDate,
    required this.dateFormat,
    required this.studentRollPreview,
    required this.invoicePreview,
  });

  final String studentRollPrefix;
  final int studentRollNextNumber;
  final String invoicePrefix;
  final int invoiceNextNumber;
  final bool invoiceNumberIncludeDate;
  final String dateFormat;
  final String? studentRollPreview;
  final String? invoicePreview;

  factory SetupConfig.fromJson(Map<String, dynamic> json) {
    return SetupConfig(
      studentRollPrefix: '${json['student_roll_prefix'] ?? ''}'.trim(),
      studentRollNextNumber:
          _toInt(json['student_roll_next_number'], fallback: 1),
      invoicePrefix: '${json['invoice_prefix'] ?? ''}'.trim(),
      invoiceNextNumber: _toInt(json['invoice_next_number'], fallback: 1),
      invoiceNumberIncludeDate:
          _toBool(json['invoice_number_include_date'], fallback: true),
      dateFormat: '${json['date_format'] ?? ''}'.trim(),
      studentRollPreview: _toNullableString(json['student_roll_preview']),
      invoicePreview: _toNullableString(json['invoice_preview']),
    );
  }
}

class GradeRule {
  const GradeRule({
    required this.label,
    required this.minScore,
  });

  final String label;
  final double minScore;

  factory GradeRule.fromJson(Map<String, dynamic> json) {
    return GradeRule(
      label: '${json['label'] ?? ''}'.trim(),
      minScore: _toDouble(json['min_score']),
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'min_score': minScore,
      };
}

class AttendanceSetting {
  const AttendanceSetting({
    required this.lockAfterDays,
    required this.periodsPerDay,
  });

  final int lockAfterDays;
  final int periodsPerDay;

  factory AttendanceSetting.fromJson(Map<String, dynamic> json) {
    return AttendanceSetting(
      lockAfterDays: _toInt(json['lock_after_days']),
      periodsPerDay: _toInt(json['periods_per_day'], fallback: 1),
    );
  }
}

bool _toBool(dynamic value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }

  if (value is num) {
    return value != 0;
  }

  final normalized = '${value ?? ''}'.trim().toLowerCase();
  if (normalized == 'true' || normalized == '1') {
    return true;
  }

  if (normalized == 'false' || normalized == '0') {
    return false;
  }

  return fallback;
}

int _toInt(dynamic value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }

  if (value is double) {
    return value.round();
  }

  return int.tryParse('$value') ?? fallback;
}

double _toDouble(dynamic value, {double fallback = 0}) {
  if (value is double) {
    return value;
  }

  if (value is int) {
    return value.toDouble();
  }

  return double.tryParse('$value') ?? fallback;
}

String? _toNullableString(dynamic value) {
  final normalized = '${value ?? ''}'.trim();
  if (normalized.isEmpty) {
    return null;
  }

  return normalized;
}
