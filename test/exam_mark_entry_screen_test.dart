import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kullmis_school_mobile/services/laravel_api.dart';
import 'package:kullmis_school_mobile/screens/exam_mark_entry_screen.dart';

void main() {
  for (final width in [320.0, 720.0]) {
    testWidgets('compact mark sheet retains drafts and saves at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic>? saved;
      final api = LaravelApi(client: MockClient((request) async {
        if (request.method == 'POST') {
          saved = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response('{}', 200);
        }
        final path = request.url.path;
        if (path.endsWith('/active')) {
          return http.Response('{"id":1,"name":"2026-2027"}', 200);
        }
        final data = path.endsWith('/students')
            ? List.generate(
                20,
                (i) => {
                      'id': i + 1,
                      'name': 'Student ${i + 1}',
                      'current_year': {'roll_number': 'R${i + 1}'}
                    })
            : [
                {
                  'id': 1,
                  'name': 'Option',
                  'level_id': 1,
                  'term_id': 1,
                  'max_mark': 10
                }
              ];
        return http.Response(
            jsonEncode({'data': data, 'current_page': 1, 'last_page': 1}), 200);
      }));
      await tester.pumpWidget(MaterialApp(
          home: ExamMarkEntryScreen(
              api: api, token: 'test', canViewMarks: false)));
      await tester.pumpAndSettle();
      final year = find.byWidgetPredicate((w) =>
          w is DropdownButtonFormField &&
          w.decoration.labelText == 'Academic Year');
      final term = find.byWidgetPredicate((w) =>
          w is DropdownButtonFormField && w.decoration.labelText == 'Term');
      expect(tester.getTopLeft(year).dy, tester.getTopLeft(term).dy);
      await tester.tap(find.widgetWithText(FilledButton, 'Load Mark Sheet'));
      await tester.pumpAndSettle();
      final first = find.byKey(const ValueKey('mark-1'));
      await tester.ensureVisible(first);
      await tester.enterText(first, '11');
      await tester.pump();
      expect(find.text('0 to 10'), findsOneWidget);
      await tester.enterText(first, '8');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('mark-2')))
              .focusNode!
              .hasFocus,
          isTrue);
      if (width < 600) {
        await tester.ensureVisible(find.byTooltip('Add or edit comment').first);
        await tester.tap(find.byTooltip('Add or edit comment').first);
        await tester.pumpAndSettle();
      }
      final comment = find.byKey(const ValueKey('comment-1'));
      await tester.ensureVisible(comment);
      await tester.enterText(comment, 'Good');
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('mark-20')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(first);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(first).controller!.text, '8');
      expect(tester.widget<TextField>(comment).controller!.text, 'Good');
      expect(find.text('1 entered · 19 remaining'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Save Exam Marks'));
      await tester.pumpAndSettle();
      expect((saved!['marks'] as List).single['mark'], 8);
      expect((saved!['marks'] as List).single['comment'], 'Good');
      expect(tester.takeException(), isNull);
    });
  }
}
