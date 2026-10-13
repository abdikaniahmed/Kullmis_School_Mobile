import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kullmis_school_mobile/models/auth_session.dart';
import 'package:kullmis_school_mobile/models/hr_models.dart';
import 'package:kullmis_school_mobile/screens/teachers_screen.dart';
import 'package:kullmis_school_mobile/services/laravel_api.dart';

void main() {
  for (final width in [320.0, 390.0, 720.0]) {
    testWidgets('teacher contacts fit width $width', (tester) async {
      tester.view.physicalSize = Size(width, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        home: TeachersScreen(
          api: _Api(),
          token: 'test',
          session: const AuthSession(
              token: 'test',
              name: 'Admin',
              email: '',
              roles: [],
              permissions: ['staff.create']),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Adam Hussein'), findsOneWidget);
      expect(find.byTooltip('Call Adam Hussein'), findsOneWidget);
      expect(find.byTooltip('Message Adam Hussein'), findsOneWidget);
      expect(find.text('+252634296679'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

class _Api extends LaravelApi {
  @override
  Future<TeacherListPage> teachersPage(
          {required String token, int page = 1, String? search}) async =>
      const TeacherListPage(
        items: [
          TeacherSummary(
              id: 1,
              name: 'Adam Hussein',
              email: 'very.long.teacher.email@school.example.com',
              phone: '+252634296679',
              position: 'Teacher',
              classAssignmentsCount: 1,
              subjectAssignmentsCount: 9)
        ],
        currentPage: 1,
        lastPage: 1,
        total: 1,
        from: 1,
        to: 1,
        hasPreviousPage: false,
        hasNextPage: false,
      );
}
