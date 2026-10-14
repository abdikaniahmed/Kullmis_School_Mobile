import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kullmis_school_mobile/widgets/student_edit_design.dart';

void main() {
  testWidgets('footer stays compact and both actions work on a narrow phone',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var back = 0;
    var save = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Align(
                alignment: Alignment.bottomCenter,
                child: StudentFooter(
                    backLabel: 'Back to Profile',
                    nextLabel: 'Save Assignment',
                    onBack: () => back++,
                    onNext: () => save++)))));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(StudentFooter)).height, lessThan(160));
    expect(tester.getSize(find.byType(OutlinedButton)).height, 56);
    expect(tester.getSize(find.byType(FilledButton)).height, 56);
    await tester.tap(find.text('Back to Profile'));
    await tester.tap(find.text('Save Assignment'));
    expect(back, 1);
    expect(save, 1);
    expect(tester.takeException(), isNull);
  });
}
