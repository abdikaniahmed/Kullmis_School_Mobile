import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/bootstrap_result.dart';
import '../models/dashboard_data.dart';
import '../services/laravel_api.dart';
import '../services/token_store.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'splash_screen.dart';

class SessionGate extends StatefulWidget {
  const SessionGate({
    super.key,
    required this.api,
    required this.tokenStore,
  });

  final LaravelApi api;
  final TokenStore tokenStore;

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  late Future<BootstrapResult> _bootstrapFuture;
  AuthSession? _session;
  DashboardData? _dashboard;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = _bootstrap();
  }

  Future<BootstrapResult> _bootstrap() async {
    final token = await widget.tokenStore.readToken();

    if (token == null || token.isEmpty) {
      return const BootstrapResult();
    }

    try {
      final session = await widget.api.currentUser(token);
      final dashboard = await _tryLoadDashboard(token);
      _session = session;
      _dashboard = dashboard;

      return BootstrapResult(session: session, dashboard: dashboard);
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await widget.tokenStore.deleteToken();

        return const BootstrapResult(
          error: 'Your session expired. Sign in again.',
        );
      }

      return BootstrapResult(error: error.message);
    } catch (_) {
      return const BootstrapResult(
        error:
            'Unable to reach the Laravel server. Check the API URL and try again.',
      );
    }
  }

  Future<DashboardData?> _tryLoadDashboard(String token) async {
    try {
      return await widget.api.dashboard(token);
    } on ApiException catch (error) {
      if (error.statusCode == 403) {
        return null;
      }

      rethrow;
    }
  }

  Future<void> _handleLogin(String email, String password) async {
    final session = await widget.api.login(email: email, password: password);
    final dashboard = await _tryLoadDashboard(session.token);

    await widget.tokenStore.writeToken(session.token);

    if (!mounted) {
      return;
    }

    setState(() {
      _session = session;
      _dashboard = dashboard;
    });
  }

  Future<void> _refreshDashboard() async {
    final session = _session;

    if (session == null) {
      return;
    }

    final dashboard = await _tryLoadDashboard(session.token);

    if (!mounted) {
      return;
    }

    setState(() {
      _dashboard = dashboard;
    });
  }

  Future<void> _handleLogout() async {
    final token = _session?.token;

    if (token != null) {
      try {
        await widget.api.logout(token);
      } catch (_) {}
    }

    await widget.tokenStore.deleteToken();

    if (!mounted) {
      return;
    }

    setState(() {
      _session = null;
      _dashboard = null;
      _bootstrapFuture = Future.value(
        const BootstrapResult(error: 'You have been signed out.'),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_session != null) {
      return HomeScreen(
        session: _session!,
        dashboard: _dashboard,
        onRefresh: _refreshDashboard,
        onLogout: _handleLogout,
      );
    }

    return FutureBuilder<BootstrapResult>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SplashScreen();
        }

        final result = snapshot.data ?? const BootstrapResult();

        if (result.session != null) {
          return HomeScreen(
            session: result.session!,
            dashboard: result.dashboard,
            onRefresh: _refreshDashboard,
            onLogout: _handleLogout,
          );
        }

        return LoginScreen(
          apiBaseUrl: LaravelApi.baseUrl,
          initialMessage: result.error,
          onLogin: _handleLogin,
        );
      },
    );
  }
}
