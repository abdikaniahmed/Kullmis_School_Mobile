class DashboardData {
  const DashboardData({
    required this.students,
    required this.teachers,
    required this.subjects,
    required this.attendancePercent,
    required this.revenueTotal,
    required this.revenueGrowthPercent,
    required this.monthTotals,
  });

  final int students;
  final int teachers;
  final int subjects;
  final double? attendancePercent;
  final double revenueTotal;
  final double revenueGrowthPercent;
  final List<MonthlyTotal> monthTotals;

  String get studentsLabel => '$students';
  String get teachersLabel => '$teachers';
  String get subjectsLabel => '$subjects';
  String get attendanceLabel => attendancePercent == null
      ? 'N/A'
      : '${attendancePercent!.toStringAsFixed(1)}%';
  String get revenueLabel => revenueTotal.toStringAsFixed(2);
  String get growthLabel => '${revenueGrowthPercent.toStringAsFixed(1)}%';

  factory DashboardData.fromResponse(Map<String, dynamic> payload) {
    final summary = payload['summary'] as Map<String, dynamic>? ?? const {};
    final revenue = payload['revenue'] as Map<String, dynamic>? ?? const {};
    final months = revenue['months'] as List<dynamic>? ?? const [];

    return DashboardData(
      students: _toInt(summary['students']),
      teachers: _toInt(summary['instructors']),
      subjects: _toInt(summary['subjects']),
      attendancePercent: _toDoubleOrNull(summary['attendance_today_percent']),
      revenueTotal: _toDouble(summary['revenue_total']),
      revenueGrowthPercent: _toDouble(summary['revenue_growth_percent']),
      monthTotals: months
          .whereType<Map<String, dynamic>>()
          .map(MonthlyTotal.fromJson)
          .toList(),
    );
  }
}

class MonthlyTotal {
  const MonthlyTotal({
    required this.label,
    required this.total,
  });

  final String label;
  final double total;

  String get totalLabel => total.toStringAsFixed(2);

  factory MonthlyTotal.fromJson(Map<String, dynamic> json) {
    return MonthlyTotal(
      label: '${json['label'] ?? '--'}',
      total: _toDouble(json['total']),
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

double _toDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse('$value') ?? 0;
}

double? _toDoubleOrNull(dynamic value) {
  if (value == null) {
    return null;
  }

  return _toDouble(value);
}
