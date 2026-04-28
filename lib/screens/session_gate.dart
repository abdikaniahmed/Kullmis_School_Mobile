import 'dart:async';

import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/bootstrap_result.dart';
import '../models/dashboard_data.dart';
import '../services/laravel_api.dart';
import '../services/offline_cache_store.dart';
import '../services/offline_sync_queue.dart';
import '../services/token_store.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'splash_screen.dart';

class SessionGate extends StatefulWidget {
  const SessionGate({
    super.key,
    required this.api,
    required this.tokenStore,
    required this.offlineCacheStore,
  });

  final LaravelApi api;
  final TokenStore tokenStore;
  final OfflineCacheStore offlineCacheStore;

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  final OfflineSyncCoordinator _syncCoordinator = const OfflineSyncCoordinator();
  late Future<BootstrapResult> _bootstrapFuture;
  AuthSession? _session;
  DashboardData? _dashboard;
  bool _usingOfflineData = false;
  bool _isServerReachable = true;
  bool _isSyncing = false;
  String? _statusMessage;
  Timer? _connectivityTimer;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = _bootstrap();
    _connectivityTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _pollConnectivityAndSync(),
    );
  }

  @override
  void dispose() {
    _connectivityTimer?.cancel();
    super.dispose();
  }

  Future<BootstrapResult> _bootstrap() async {
    final token = await widget.tokenStore.readToken();
    final cachedSession = await widget.offlineCacheStore.readSession();
    final cachedDashboard = await widget.offlineCacheStore.readDashboard();

    if (token == null || token.isEmpty) {
      return const BootstrapResult();
    }

    try {
      final session = await widget.api.currentUser(token);
      final dashboard = await _tryLoadDashboard(token);
      await widget.offlineCacheStore.writeSession(session);
      if (dashboard != null) {
        await widget.offlineCacheStore.writeDashboard(dashboard);
      }
      _session = session;
      _dashboard = dashboard;
      _usingOfflineData = false;
      _isServerReachable = true;
      _statusMessage = null;

      await _syncCoordinator.flush(api: widget.api, token: token);

      return BootstrapResult(session: session, dashboard: dashboard);
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await widget.tokenStore.deleteToken();
        await widget.offlineCacheStore.clear();

        return const BootstrapResult(
          error: 'Your session expired. Sign in again.',
        );
      }

      if (cachedSession != null && cachedSession.token == token) {
        _session = cachedSession;
        _dashboard = cachedDashboard;
        _usingOfflineData = true;
        _isServerReachable = false;
        _statusMessage = 'Offline mode: showing last synced data.';

        return BootstrapResult(
          session: cachedSession,
          dashboard: cachedDashboard,
          error: _statusMessage,
          usingOfflineData: true,
        );
      }

      return BootstrapResult(error: error.message);
    } catch (_) {
      if (cachedSession != null && cachedSession.token == token) {
        _session = cachedSession;
        _dashboard = cachedDashboard;
        _usingOfflineData = true;
        _isServerReachable = false;
        _statusMessage = 'Offline mode: showing last synced data.';

        return BootstrapResult(
          session: cachedSession,
          dashboard: cachedDashboard,
          error: _statusMessage,
          usingOfflineData: true,
        );
      }

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
    await widget.offlineCacheStore.writeSession(session);
    if (dashboard != null) {
      await widget.offlineCacheStore.writeDashboard(dashboard);
    }
    final syncResult = await _syncCoordinator.flush(
      api: widget.api,
      token: session.token,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _session = session;
      _dashboard = dashboard;
      _usingOfflineData = false;
      _isServerReachable = true;
      _statusMessage = _syncStatusMessage(
        syncResult: syncResult,
        emptySyncMessage: null,
      );
    });
  }

  Future<void> _refreshDashboard() async {
    await _syncAndRefresh(
      emptySyncMessage: null,
      refreshDashboard: true,
      fallbackMessage: 'Offline mode: showing last synced data.',
    );
  }

  Future<void> _syncNow() async {
    await _syncAndRefresh(
      emptySyncMessage: 'All offline changes are already synced.',
      refreshDashboard: true,
      fallbackMessage:
          'Unable to reach the server. Pending changes are waiting for connection.',
    );
  }

  Future<void> _pollConnectivityAndSync() async {
    final session = _session;
    if (session == null || _isSyncing) {
      return;
    }

    final pendingCount = await _syncCoordinator.queue.count();
    final shouldProbe =
        _usingOfflineData || !_isServerReachable || pendingCount > 0;
    if (!shouldProbe) {
      return;
    }

    try {
      await widget.api.currentUser(session.token);

      if (!mounted) {
        return;
      }

      if (!_isServerReachable) {
        setState(() {
          _isServerReachable = true;
          if (_usingOfflineData) {
            _statusMessage = 'Connection restored. Syncing cached changes...';
          }
        });
      }

      await _syncAndRefresh(
        emptySyncMessage: null,
        refreshDashboard: _usingOfflineData || pendingCount > 0,
        fallbackMessage: 'Offline mode: showing last synced data.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isServerReachable = false;
        if (pendingCount > 0) {
          _statusMessage =
              'Offline changes are queued and will sync when the server is reachable.';
        } else if (_usingOfflineData) {
          _statusMessage = 'Offline mode: showing last synced data.';
        }
      });
    }
  }

  Future<void> _syncAndRefresh({
    required String? emptySyncMessage,
    required bool refreshDashboard,
    required String fallbackMessage,
  }) async {
    final session = _session;
    if (session == null || _isSyncing) {
      return;
    }

    if (mounted) {
      setState(() {
        _isSyncing = true;
      });
    } else {
      _isSyncing = true;
    }

    try {
      final syncResult = await _syncCoordinator.flush(
        api: widget.api,
        token: session.token,
      );
      final dashboard = refreshDashboard
          ? await _tryLoadDashboard(session.token)
          : _dashboard;
      if (dashboard != null) {
        await widget.offlineCacheStore.writeDashboard(dashboard);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _dashboard = dashboard;
        _usingOfflineData = false;
        _isServerReachable = true;
        _statusMessage = _syncStatusMessage(
          syncResult: syncResult,
          emptySyncMessage: emptySyncMessage,
        );
      });
    } on ApiException catch (_) {
      final cachedDashboard = await widget.offlineCacheStore.readDashboard();
      if (!mounted) {
        return;
      }

      setState(() {
        _dashboard = cachedDashboard ?? _dashboard;
        _usingOfflineData = true;
        _isServerReachable = false;
        _statusMessage = fallbackMessage;
      });
    } catch (_) {
      final cachedDashboard = await widget.offlineCacheStore.readDashboard();
      if (!mounted) {
        return;
      }

      setState(() {
        _dashboard = cachedDashboard ?? _dashboard;
        _usingOfflineData = true;
        _isServerReachable = false;
        _statusMessage = fallbackMessage;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      } else {
        _isSyncing = false;
      }
    }
  }

  Future<void> _handleLogout() async {
    final token = _session?.token;

    if (token != null) {
      try {
        await widget.api.logout(token);
      } catch (_) {}
    }

    await widget.tokenStore.deleteToken();
    await widget.offlineCacheStore.clear();

    if (!mounted) {
      return;
    }

    setState(() {
      _session = null;
      _dashboard = null;
      _usingOfflineData = false;
      _statusMessage = null;
      _bootstrapFuture = Future.value(
        const BootstrapResult(error: 'You have been signed out.'),
      );
    });
  }

  String? _syncStatusMessage({
    required OfflineSyncResult syncResult,
    required String? emptySyncMessage,
  }) {
    if (syncResult.issueCount > 0 && syncResult.flushedCount > 0) {
      return 'Synced ${syncResult.flushedCount} changes. ${syncResult.issueCount} need review.';
    }

    if (syncResult.issueCount > 0) {
      return '${syncResult.issueCount} queued changes need review before they can sync.';
    }

    if (syncResult.flushedCount > 0) {
      return 'Synced ${syncResult.flushedCount} pending offline changes.';
    }

    return emptySyncMessage;
  }

  @override
  Widget build(BuildContext context) {
    if (_session != null) {
      return HomeScreen(
        session: _session!,
        dashboard: _dashboard,
        api: widget.api,
        onRefresh: _refreshDashboard,
        onSyncNow: _syncNow,
        onLogout: _handleLogout,
        usingOfflineData: _usingOfflineData,
        isServerReachable: _isServerReachable,
        isSyncing: _isSyncing,
        statusMessage: _statusMessage,
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
          _session = result.session;
          _dashboard = result.dashboard;
          _usingOfflineData = result.usingOfflineData;
          _statusMessage = result.usingOfflineData ? result.error : null;

          return HomeScreen(
            session: result.session!,
            dashboard: result.dashboard,
            api: widget.api,
            onRefresh: _refreshDashboard,
            onSyncNow: _syncNow,
            onLogout: _handleLogout,
            usingOfflineData: result.usingOfflineData,
            isServerReachable: _isServerReachable,
            isSyncing: _isSyncing,
            statusMessage: result.usingOfflineData ? result.error : null,
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
