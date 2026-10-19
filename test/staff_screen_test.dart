import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kullmis_school_mobile/models/auth_session.dart';
import 'package:kullmis_school_mobile/screens/staff_screen.dart';
import 'package:kullmis_school_mobile/services/laravel_api.dart';

void main() {
  testWidgets('staff search debounces, clears, submits and filters immediately',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <Uri>[];
    final api = LaravelApi(client: MockClient((request) async {
      requests.add(request.url);
      return http.Response(
          jsonEncode(
              {'data': [], 'current_page': 1, 'last_page': 1, 'total': 0}),
          200);
    }));
    await tester.pumpWidget(MaterialApp(
        home: StaffScreen(
            api: api,
            token: 'test',
            session: const AuthSession(
                token: 'test',
                name: 'Test',
                email: '',
                roles: [],
                permissions: []))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(FilledButton, 'Search'), findsNothing);
    final search = find.byType(TextField);
    expect(tester.getSize(search).width, 280);
    expect(tester.getSize(search).height, 50);
    expect(
        tester.getSize(find.byKey(const ValueKey('staff-type-filter'))).height,
        50);
    expect(
        tester.getTopLeft(find.byKey(const ValueKey('staff-type-filter'))).dy,
        greaterThan(tester.getBottomLeft(search).dy));
    await tester.enterText(search, 'A');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(search, 'Ali');
    await tester.pump(const Duration(milliseconds: 349));
    expect(requests.length, 1);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(requests.length, 2);
    expect(requests.last.queryParameters['search'], 'Ali');
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(search).controller!.text, isEmpty);
    expect(requests.last.queryParameters['search'] ?? '', isEmpty);
    expect(find.byTooltip('Clear search'), findsNothing);
    await tester.enterText(search, 'Hassan');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(requests.last.queryParameters['search'], 'Hassan');
    final beforeFilter = requests.length;
    await tester.tap(find.byKey(const ValueKey('staff-type-filter')));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, 'All Types'))
            .selected,
        isTrue);
    expect(find.byIcon(Icons.check), findsOneWidget);
    await tester.tap(find.text('teacher').last);
    await tester.pumpAndSettle();
    expect(requests.length, beforeFilter + 1);
    expect(requests.last.queryParameters['type'], 'teacher');
    expect(requests.last.queryParameters['search'], 'Hassan');
    await tester.pump(const Duration(milliseconds: 400));
    expect(requests.length, beforeFilter + 1);
    await tester.enterText(search, 'pending');
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump(const Duration(milliseconds: 400));
    expect(requests.length, beforeFilter + 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('older staff responses do not replace newer search results',
      (tester) async {
    final older = Completer<http.Response>();
    http.Response response(String name) => http.Response(
        jsonEncode({
          'data': [
            {'id': 1, 'name': name, 'type': 'teacher'}
          ],
          'current_page': 1,
          'last_page': 1,
          'total': 1,
        }),
        200);
    final api = LaravelApi(client: MockClient((request) async {
      if (request.url.queryParameters['search'] == 'old') return older.future;
      return response(request.url.queryParameters['search'] == 'new'
          ? 'New result'
          : 'Initial result');
    }));
    await tester.pumpWidget(MaterialApp(
        home: StaffScreen(
            api: api,
            token: 'test',
            session: const AuthSession(
                token: 'test',
                name: 'Test',
                email: '',
                roles: [],
                permissions: ['staff.edit', 'staff.delete']))));
    await tester.pumpAndSettle();
    expect(find.text('Phone: No phone', findRichText: true), findsOneWidget);
    expect(find.text('Email: No email', findRichText: true), findsOneWidget);
    expect(find.text('User account: Not linked', findRichText: true),
        findsOneWidget);
    expect(find.byType(Chip), findsNothing);
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Delete'), findsNothing);
    await tester.tap(find.byTooltip('Staff actions for Initial result'));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Staff'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'old');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'new');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('New result'), findsOneWidget);
    older.complete(response('Old result'));
    await tester.pumpAndSettle();
    expect(find.text('New result'), findsOneWidget);
    expect(find.text('Old result'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
