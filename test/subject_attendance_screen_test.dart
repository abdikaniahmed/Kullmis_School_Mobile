import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kullmis_school_mobile/models/subject_attendance_models.dart';
import 'package:kullmis_school_mobile/screens/subject_attendance_screen.dart';
import 'package:kullmis_school_mobile/services/laravel_api.dart';
import 'package:kullmis_school_mobile/services/offline_cache_store.dart';

void main() {
  for (final (width, scale) in [
    (320.0, 1.0),
    (390.0, 1.0),
    (720.0, 1.0),
    (390.0, 1.6)
  ]) {
    testWidgets(
        'attendance cards fit $width at scale $scale and save selected status and remarks',
        (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = _Api();
      await tester.pumpWidget(MaterialApp(
        home: SubjectAttendanceScreen(
            api: api, token: 'test', cacheStore: MemoryOfflineCacheStore()),
      ));
      await tester.pumpAndSettle();
      await tester
          .tap(find.widgetWithText(FilledButton, 'Load Subject Session'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Biology'), findsOneWidget);
      final absent = find.byKey(const ValueKey('status-1-absent'));
      await tester.scrollUntilVisible(absent, 200,
          scrollable: find.byType(Scrollable).first);
      expect(absent, findsOneWidget);
      await tester.ensureVisible(absent);
      await tester.pumpAndSettle();
      await tester.tap(absent);
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(absent).selected, isTrue);
      expect(find.bySemanticsLabel('Absent: 1'), findsOneWidget);
      final remarks = find.byKey(const ValueKey('remarks-1'));
      await tester.ensureVisible(remarks);
      await tester.pumpAndSettle();
      await tester.enterText(remarks, 'Sick');
      await tester.pump();
      final save = find.byKey(const ValueKey('save-attendance'));
      expect(tester.getRect(save).bottom, lessThanOrEqualTo(1000));
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(api.saved?.single.status, 'absent');
      expect(api.saved?.single.remarks, 'Sick');
      expect(api.saved?.single.studentId, 10);
      expect(tester.takeException(), isNull);
    });
  }
}

class _Api extends LaravelApi {
  List<SubjectAttendanceRecordDraft>? saved;
  @override
  Future<SubjectAttendanceFilters> subjectAttendanceFilters(
          String token) async =>
      const SubjectAttendanceFilters(
          academicYearId: 1,
          levels: [AttendanceLevel(id: 1, name: 'Form Three')],
          classes: [AttendanceClass(id: 1, name: 'Form 3A', levelId: 1)],
          periods: [AttendancePeriod(value: 3, label: 'Period 3')],
          periodsPerDay: 8);

  @override
  Future<SubjectAttendanceSessionData> subjectAttendanceSession({
    required String token,
    required int academicYearId,
    required int schoolClassId,
    required String date,
    required int periodNumber,
  }) async =>
      SubjectAttendanceSessionData(
          sessionId: 1,
          academicYearId: 1,
          date: date,
          dayLabel: 'Monday',
          periodNumber: 3,
          subject: const AttendanceNamedEntity(id: 1, name: 'Biology'),
          teacher:
              const AttendanceNamedEntity(id: 1, name: 'Abdiqadir Abdilahi'),
          schoolClass: const AttendanceNamedEntity(id: 1, name: 'Form 3A'),
          students: [
            SubjectAttendanceStudent(
                id: 1,
                studentId: 10,
                name: 'Abdale Faysal Abdirahman',
                rollNumber: 'ROLL-0157',
                status: saved?.single.status ?? 'present',
                remarks: saved?.single.remarks ?? '')
          ]);

  @override
  Future<void> saveSubjectAttendanceSession(
      {required String token,
      required int academicYearId,
      required int schoolClassId,
      required String date,
      required int periodNumber,
      required List<SubjectAttendanceRecordDraft> records}) async {
    saved = records;
  }
}
