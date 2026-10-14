import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kullmis_school_mobile/models/auth_session.dart';
import 'package:kullmis_school_mobile/models/fee_models.dart';
import 'package:kullmis_school_mobile/models/main_attendance_models.dart';
import 'package:kullmis_school_mobile/models/student_management_models.dart';
import 'package:kullmis_school_mobile/screens/students_edit_screen.dart';
import 'package:kullmis_school_mobile/services/laravel_api.dart';

void main() {
  testWidgets(
      'short phone keeps fields usable with keyboard and resets blood dropdown',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(MaterialApp(
        home: StudentsEditScreen(
            api: _Api(),
            token: 'test',
            studentId: 1,
            session: const AuthSession(
                token: 'test',
                name: 'Admin',
                email: '',
                roles: [],
                permissions: []))));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('O+').last);
    await tester.pumpAndSettle();
    expect(find.text('O+'), findsOneWidget);
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(find.text('Not Specified'), findsOneWidget);
    expect(find.text('O+'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 600.0]) {
    testWidgets('saved profile advances and assignment saves at width $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = _SuccessApi();
      await tester.pumpWidget(MaterialApp(
          home: StudentsEditScreen(
              api: api,
              token: 'test',
              studentId: 1,
              session: const AuthSession(
                  token: 'test',
                  name: 'Admin',
                  email: '',
                  roles: [],
                  permissions: []))));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Updated Student');
      await tester
          .tap(find.widgetWithText(FilledButton, 'Academic Assignment'));
      await tester.pumpAndSettle();
      expect(api.savedProfile?['name'], 'Updated Student');
      expect(find.text('Back to Profile'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Save Assignment'));
      await tester.pumpAndSettle();
      expect(find.text('Select an academic year, level, and class first.'),
          findsOneWidget);
      for (final entry in ['2026 - 2027', 'Form Two', 'Form 2A']) {
        final index = ['2026 - 2027', 'Form Two', 'Form 2A'].indexOf(entry);
        await tester
            .ensureVisible(find.byType(DropdownButtonFormField<int>).at(index));
        await tester.tap(find.byType(DropdownButtonFormField<int>).at(index));
        await tester.pumpAndSettle();
        await tester.tap(find.text(entry).last);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.widgetWithText(FilledButton, 'Save Assignment'));
      await tester.pumpAndSettle();
      expect(api.savedAssignment?['student_id'], 1);
      expect(api.savedAssignment?['academic_year_id'], 1);
      expect(api.savedAssignment?['school_class_id'], 3);
      await tester.tap(find.text('Back to Profile'));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .controller!
              .text,
          'Updated Student');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('reset restores loaded profile and failed save stays on profile',
      (tester) async {
    tester.view.physicalSize = const Size(360, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: StudentsEditScreen(
      api: _Api(),
      token: 'test',
      studentId: 1,
      session: const AuthSession(
          token: 'test', name: 'Admin', email: '', roles: [], permissions: []),
    )));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Changed name');
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'Xamse Maxamed Axmed');
    await tester.tap(find.widgetWithText(FilledButton, 'Academic Assignment'));
    await tester.pumpAndSettle();
    expect(find.text('Unable to update student profile.'), findsOneWidget);
    expect(find.text('Student Profile'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _Api extends LaravelApi {
  @override
  Future<StudentProfile> studentDetail(
          {required String token, required int studentId}) async =>
      StudentProfile.fromJson({
        'id': 1,
        'name': 'Xamse Maxamed Axmed',
        'phone': '252634488009',
        'gender': 'male',
        'student_type': 'normal',
        'fee_type': 'normal',
      });
  @override
  Future<void> updateStudent(
          {required String token,
          required int studentId,
          required Map<String, dynamic> payload}) async =>
      throw Exception('offline');
}

class _SuccessApi extends _Api {
  Map<String, dynamic>? savedProfile;
  Map<String, dynamic>? savedAssignment;
  @override
  Future<void> updateStudent(
      {required String token,
      required int studentId,
      required Map<String, dynamic> payload}) async {
    savedProfile = payload;
  }

  @override
  Future<List<AcademicYearOption>> academicYears(String token) async =>
      [const AcademicYearOption(id: 1, name: '2026 - 2027', isActive: true)];
  @override
  Future<List<MainAttendanceLevel>> attendanceLevels(String token) async =>
      [const MainAttendanceLevel(id: 2, name: 'Form Two')];
  @override
  Future<List<MainAttendanceClass>> schoolClasses(
          {required String token,
          int? levelId,
          bool includeAll = false}) async =>
      [const MainAttendanceClass(id: 3, name: 'Form 2A', levelId: 2)];
  @override
  Future<StudentAcademicAssignment> createStudentAssignment(
      {required String token, required Map<String, dynamic> payload}) async {
    savedAssignment = payload;
    return const StudentAcademicAssignment(
        id: 4,
        academicYearId: 1,
        levelId: 2,
        classId: 3,
        rollNumber: 'ROLL-0153',
        status: 'active',
        levelName: 'Form Two',
        className: 'Form 2A');
  }

  @override
  Future<StudentOptionalFeesResponse> studentOptionalFees(
          {required String token, required int assignmentId}) async =>
      const StudentOptionalFeesResponse(fees: [], assignedFeeIds: []);
}
