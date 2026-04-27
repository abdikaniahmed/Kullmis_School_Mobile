import 'auth_session.dart';
import 'dashboard_data.dart';

class BootstrapResult {
  const BootstrapResult({
    this.session,
    this.dashboard,
    this.error,
    this.usingOfflineData = false,
  });

  final AuthSession? session;
  final DashboardData? dashboard;
  final String? error;
  final bool usingOfflineData;
}
