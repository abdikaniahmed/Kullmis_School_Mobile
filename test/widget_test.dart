import 'package:flutter_test/flutter_test.dart';

import 'package:kullmis_school_mobile/main.dart';

void main() {
  testWidgets('shows the login screen when no token is stored', (tester) async {
    await tester.pumpWidget(
      MyApp(tokenStore: MemoryTokenStore()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kullmis School'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
