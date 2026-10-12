import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kullmis_school_mobile/models/auth_session.dart';
import 'package:kullmis_school_mobile/models/main_attendance_models.dart';
import 'package:kullmis_school_mobile/models/student_list_models.dart';
import 'package:kullmis_school_mobile/screens/student_list_screen.dart';
import 'package:kullmis_school_mobile/services/laravel_api.dart';

void main() {
  const session = AuthSession(
      token: 'test',
      name: 'Admin',
      email: '',
      roles: [],
      permissions: [
        'students.create',
        'students.edit',
        'students.delete',
        'marks.view'
      ]);
  for (final width in [320.0, 390.0, 720.0]) {
    testWidgets('student actions fit $width and hand formatted phone to dialer',
        (tester) async {
      tester.view.physicalSize = Size(width, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final calls = <MethodCall>[];
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
          (call) async {
        calls.add(call);
        return true;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null));
      await tester.runAsync(() async {
        await tester.pumpWidget(MaterialApp(
            home: StudentListScreen(
                api: _Api(), token: 'test', session: session)));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Add Student'), findsOneWidget);
      expect(find.text('Upload'), findsOneWidget);
      expect(find.text('Gradebook'), findsNWidgets(2));
      await tester.tap(find.byTooltip('Call Aamin Cabdi'));
      await tester.pumpAndSettle();
      expect(calls.single.arguments['url'], 'tel:+252634453076');
      expect(calls.single.arguments['useWebView'], isFalse);
      await tester.tap(find.byTooltip('Message Aamin Cabdi'));
      await tester.pumpAndSettle();
      expect(calls.last.arguments['url'], 'sms:+252634453076');
      final noPhone = tester.widget<IconButton>(find.byWidgetPredicate(
          (widget) =>
              widget is IconButton && widget.tooltip == 'Call No Phone'));
      expect(noPhone.onPressed, isNull);
      final profile = find.ancestor(
          of: find.text('Open Profile').first,
          matching: find.byType(FilledButton));
      final gradebook = find.ancestor(
          of: find.text('Gradebook').first,
          matching: find.byType(OutlinedButton));
      final menu = find.byType(PopupMenuButton<String>).first;
      final menuRect = tester.getRect(menu);
      expect(tester.getCenter(profile).dy, closeTo(menuRect.center.dy, 1));
      expect(tester.getCenter(gradebook).dy, closeTo(menuRect.center.dy, 1));
      expect(menuRect.left, greaterThan(tester.getRect(gradebook).right));
      await tester.tap(menu);
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);
      final popup = tester.getRect(find.byType(PopupMenuItem<String>).first);
      expect(popup.top, greaterThanOrEqualTo(menuRect.bottom));
      expect(popup.right, lessThanOrEqualTo(width));
      expect(find.text('Disable'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Student'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

class _Api extends LaravelApi {
  @override
  Future<List<MainAttendanceLevel>> attendanceLevels(String token) async => [];
  @override
  Future<StudentListPage> studentList(
          {required String token,
          required int page,
          String? search,
          int? levelId,
          int? classId}) async =>
      const StudentListPage(
          items: [
            StudentListItem(
                id: 1,
                name: 'Aamin Cabdi',
                phone: '+252 (63) 445-3076',
                currentYear: StudentCurrentYear(
                    levelId: 1,
                    classId: 1,
                    rollNumber: null,
                    levelName: 'Form One',
                    className: 'Form 1C')),
            StudentListItem(
                id: 2, name: 'No Phone', phone: null, currentYear: null),
          ],
          currentPage: 1,
          lastPage: 1,
          total: 2,
          from: 1,
          to: 2,
          hasPreviousPage: false,
          hasNextPage: false);
}
