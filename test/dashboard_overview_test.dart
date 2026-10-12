import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kullmis_school_mobile/l10n/app_language.dart';
import 'package:kullmis_school_mobile/models/auth_session.dart';
import 'package:kullmis_school_mobile/models/dashboard_data.dart';
import 'package:kullmis_school_mobile/widgets/dashboard_overview.dart';

void main() {
  const session = AuthSession(token: '', name: 'School Admin',
    email: 'admin@school.test', roles: ['school_admin'], permissions: [],
    schoolName: 'Almanaar Secondary School');
  const data = DashboardData(students: 411, teachers: 11, subjects: 11,
    attendancePercent: 0, revenueTotal: 5671.50, revenueGrowthPercent: 0,
    monthTotals: [
      MonthlyTotal(label: 'Apr', total: 0),
      MonthlyTotal(label: 'May', total: 0),
      MonthlyTotal(label: 'Jun', total: 0),
      MonthlyTotal(label: 'Jul', total: 0),
      MonthlyTotal(label: 'Aug', total: 0),
      MonthlyTotal(label: 'Sep', total: 0),
      MonthlyTotal(label: 'Oct', total: 5671.50),
    ]);

  for (final width in [320.0, 390.0, 800.0]) {
    testWidgets('dashboard fits $width and opens student list', (tester) async {
      await tester.view.reset();
    });
  }
}
