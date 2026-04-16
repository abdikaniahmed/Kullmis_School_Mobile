import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kullmis_school_mobile/app.dart';
import 'package:kullmis_school_mobile/models/auth_session.dart';
import 'package:kullmis_school_mobile/models/dashboard_data.dart';
import 'package:kullmis_school_mobile/services/laravel_api.dart';
import 'package:kullmis_school_mobile/services/token_store.dart';

void main() {
  testWidgets('submits login and shows the home screen', (tester) async {
    final tokenStore = TestTokenStore();
    final api = FakeLaravelApi(
      loginSession: _session(token: 'login-token'),
      dashboardData: _dashboard(),
    );

    await tester.pumpWidget(
      MyApp(api: api, tokenStore: tokenStore),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byType(TextFormField).at(0), 'admin@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(api.loginEmail, 'admin@example.com');
    expect(api.loginPassword, 'secret123');
    expect(tokenStore.token, 'login-token');
    expect(find.text('Springfield Campus'), findsOneWidget);
    expect(find.text('Principal Skinner'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Revenue this month'), findsOneWidget);
  });

  testWidgets('bootstraps directly to the home screen with a stored token', (
    tester,
  ) async {
    final tokenStore = TestTokenStore(initialToken: 'saved-token');
    final api = FakeLaravelApi(
      currentUserSession: _session(token: 'saved-token'),
      dashboardData: _dashboard(),
    );

    await tester.pumpWidget(
      MyApp(api: api, tokenStore: tokenStore),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(api.currentUserToken, 'saved-token');
    expect(api.dashboardToken, 'saved-token');
    expect(find.text('Sign in'), findsNothing);
    expect(find.text('Springfield Campus'), findsOneWidget);
    expect(find.text('Principal Skinner'), findsOneWidget);
    expect(find.text('admin@example.com'), findsOneWidget);
    expect(find.text('Revenue this month'), findsOneWidget);
  });

  testWidgets('shows the login screen when no token is stored', (tester) async {
    await tester.pumpWidget(
      MyApp(tokenStore: TestTokenStore()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kullmis School'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}

class TestTokenStore implements TokenStore {
  TestTokenStore({this.initialToken}) : token = initialToken;

  final String? initialToken;
  String? token;

  @override
  Future<void> deleteToken() async {
    token = null;
  }

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> writeToken(String value) async {
    token = value;
  }
}

class FakeLaravelApi extends LaravelApi {
  FakeLaravelApi({
    this.loginSession,
    this.currentUserSession,
    this.dashboardData,
  });

  final AuthSession? loginSession;
  final AuthSession? currentUserSession;
  final DashboardData? dashboardData;
  String? loginEmail;
  String? loginPassword;
  String? currentUserToken;
  String? dashboardToken;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    loginEmail = email;
    loginPassword = password;

    final session = loginSession;
    if (session == null) {
      throw const ApiException('Missing login session for test.');
    }

    return session;
  }

  @override
  Future<AuthSession> currentUser(String token) async {
    currentUserToken = token;

    final session = currentUserSession;
    if (session == null) {
      throw const ApiException('Missing current user session for test.');
    }

    return session;
  }

  @override
  Future<DashboardData> dashboard(String token) async {
    dashboardToken = token;

    final dashboard = dashboardData;
    if (dashboard == null) {
      throw const ApiException('Missing dashboard data for test.');
    }

    return dashboard;
  }
}

AuthSession _session({required String token}) {
  return AuthSession(
    token: token,
    name: 'Principal Skinner',
    email: 'admin@example.com',
    roles: const ['Admin'],
    permissions: const [],
    schoolName: 'Springfield Campus',
  );
}

DashboardData _dashboard() {
  return const DashboardData(
    students: 420,
    teachers: 18,
    subjects: 12,
    attendancePercent: 96.5,
    revenueTotal: 12500.75,
    revenueGrowthPercent: 8.4,
    monthTotals: [
      MonthlyTotal(label: 'Jan', total: 4000),
      MonthlyTotal(label: 'Feb', total: 4250.25),
      MonthlyTotal(label: 'Mar', total: 4250.50),
    ],
  );
}
