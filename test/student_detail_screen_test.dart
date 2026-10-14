import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kullmis_school_mobile/models/auth_session.dart';
import 'package:kullmis_school_mobile/models/student_list_models.dart';
import 'package:kullmis_school_mobile/models/student_management_models.dart';
import 'package:kullmis_school_mobile/screens/student_detail_screen.dart';
import 'package:kullmis_school_mobile/services/laravel_api.dart';

void main() {
  for (final width in [320.0, 575.0]) {
    testWidgets('profile tabs and readable information fit $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          home: StudentDetailScreen(
        api: _Api(),
        token: 'test',
        session: const AuthSession(
            token: 'test',
            name: 'Admin',
            email: '',
            roles: [],
            permissions: [
              'discipline_incidents.create',
              'discipline_incidents.report.view',
              'students.edit'
            ]),
        student: const StudentListItem(
            id: 1,
            name: 'Maxamed Cabdiraxmaan Jaamac',
            phone: '252634958338',
            currentYear: null),
      )));
      await tester.pumpAndSettle();
      expect(find.text('Full Scholarship'), findsOneWidget);
      expect(find.text('Personal Information'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      await tester.tap(find.text('Academic'));
      await tester.pumpAndSettle();
      expect(find.text('Current Assignment'), findsOneWidget);
      await tester.tap(find.text('Incidents'));
      await tester.pumpAndSettle();
      expect(find.text('No incidents recorded'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('restricted session hides edit and incident controls',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: StudentDetailScreen(
      api: _Api(),
      token: 'test',
      session: const AuthSession(
          token: 'test', name: 'Reader', email: '', roles: [], permissions: []),
      student: const StudentListItem(
          id: 1, name: 'Student', phone: null, currentYear: null),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Incidents'), findsNothing);
    expect(find.text('Record Incident'), findsNothing);
    expect(find.text('Refresh Incident Report'), findsNothing);
  });
}

class _Api extends LaravelApi {
  @override
  Future<StudentProfile> studentDetail(
          {required String token, required int studentId}) async =>
      StudentProfile.fromJson({
        'id': 1,
        'name': 'Maxamed Cabdiraxmaan Jaamac',
        'phone': '252634958338',
        'gender': 'male',
        'student_type': 'normal',
        'fee_type': 'full_scholarship',
      });
}
