import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    this.api,
    this.tokenStore,
  });

  final LaravelApi? api;
  final TokenStore? tokenStore;

  @override
  Widget build(BuildContext context) {
    const canvas = Color(0xFFF4EFE6);
    const ink = Color(0xFF1F2933);

    return MaterialApp(
      title: 'Kullmis School Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: canvas,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF0F766E),
          secondary: Color(0xFFCB6E17),
          surface: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: ink,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
          headlineMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: ink,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            height: 1.4,
            color: ink,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: Color(0xFF52606D),
          ),
        ),
      ),
      home: SessionGate(
        api: api ?? LaravelApi(),
        tokenStore: tokenStore ?? const SecureTokenStore(),
      ),
    );
  }
}

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

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F766E), Color(0xFFF4EFE6)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.apiBaseUrl,
    required this.onLogin,
    this.initialMessage,
  });

  final String apiBaseUrl;
  final String? initialMessage;
  final Future<void> Function(String email, String password) onLogin;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = widget.initialMessage;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;

    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await widget.onLogin(
        _emailController.text.trim(),
        _passwordController.text,
      );
    } on ApiException catch (error) {
      setState(() {
        _error = error.message;
      });
    } catch (_) {
      setState(() {
        _error =
            'Unable to connect to the API. Check the base URL and network access.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F766E), Color(0xFF134E4A), Color(0xFFF4EFE6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Card(
                  elevation: 12,
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kullmis School',
                            style: theme.textTheme.headlineLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sign in with your Laravel account to open the mobile dashboard.',
                            style: theme.textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 24),
                          if (_error != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF1F2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                _error!,
                                style:
                                    const TextStyle(color: Color(0xFF9F1239)),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Email is required.';
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Password is required.';
                              }

                              return null;
                            },
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _submitting ? null : _submit,
                              style: FilledButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: _submitting
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Sign in'),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'API base URL',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.apiBaseUrl,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.session,
    required this.dashboard,
    required this.onRefresh,
    required this.onLogout,
  });

  final AuthSession session;
  final DashboardData? dashboard;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = <SummaryCardData>[
      SummaryCardData(
        label: 'Students',
        value: dashboard?.studentsLabel ?? '--',
        tone: const Color(0xFFE0F2FE),
      ),
      SummaryCardData(
        label: 'Teachers',
        value: dashboard?.teachersLabel ?? '--',
        tone: const Color(0xFFFEF3C7),
      ),
      SummaryCardData(
        label: 'Subjects',
        value: dashboard?.subjectsLabel ?? '--',
        tone: const Color(0xFFDCFCE7),
      ),
      SummaryCardData(
        label: 'Attendance',
        value: dashboard?.attendanceLabel ?? '--',
        tone: const Color(0xFFFCE7F3),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(session.schoolName ?? 'Kullmis School Mobile'),
        actions: [
          IconButton(
            onPressed: () async => onRefresh(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: () async => onLogout(),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF115E59),
                    Color(0xFF0F766E),
                    Color(0xFFCB6E17)
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.name,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    session.email,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: session.roles
                        .map(
                          (role) => Chip(
                            label: Text(role),
                            backgroundColor: Colors.white.withOpacity(0.18),
                            labelStyle: const TextStyle(color: Colors.white),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Overview', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: cards.map((card) => SummaryCard(card: card)).toList(),
            ),
            const SizedBox(height: 20),
            if (dashboard == null)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'This account authenticated successfully, but the school dashboard endpoint is not available for the current role.',
                  style: theme.textTheme.bodyLarge,
                ),
              )
            else ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Revenue this month',
                        style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      dashboard!.revenueLabel,
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Growth: ${dashboard!.growthLabel}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Monthly revenue', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 12),
                    ...dashboard!.monthTotals.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(child: Text(entry.label)),
                            Text(entry.totalLabel),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.card,
  });

  final SummaryCardData card;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: card.tone,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(card.label, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 8),
              Text(
                card.value,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SummaryCardData {
  const SummaryCardData({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final Color tone;
}

class BootstrapResult {
  const BootstrapResult({
    this.session,
    this.dashboard,
    this.error,
  });

  final AuthSession? session;
  final DashboardData? dashboard;
  final String? error;
}

class AuthSession {
  const AuthSession({
    required this.token,
    required this.name,
    required this.email,
    required this.roles,
    this.schoolName,
  });

  final String token;
  final String name;
  final String email;
  final List<String> roles;
  final String? schoolName;

  factory AuthSession.fromUserResponse({
    required String token,
    required Map<String, dynamic> payload,
  }) {
    final school = payload['school'];
    final roles = payload['roles'];

    return AuthSession(
      token: token,
      name: '${payload['name'] ?? ''}'.trim(),
      email: '${payload['email'] ?? ''}'.trim(),
      roles: _roleNames(roles),
      schoolName: school is Map ? '${school['name'] ?? ''}'.trim() : null,
    );
  }

  static List<String> _roleNames(dynamic roles) {
    if (roles is! List) {
      return const [];
    }

    return roles
        .map((role) {
          if (role is Map) {
            return '${role['name'] ?? ''}'.trim();
          }

          return '$role'.trim();
        })
        .where((role) => role.isNotEmpty)
        .cast<String>()
        .toList();
  }
}

class DashboardData {
  const DashboardData({
    required this.students,
    required this.teachers,
    required this.subjects,
    required this.attendancePercent,
    required this.revenueTotal,
    required this.revenueGrowthPercent,
    required this.monthTotals,
  });

  final int students;
  final int teachers;
  final int subjects;
  final double? attendancePercent;
  final double revenueTotal;
  final double revenueGrowthPercent;
  final List<MonthlyTotal> monthTotals;

  String get studentsLabel => '$students';
  String get teachersLabel => '$teachers';
  String get subjectsLabel => '$subjects';
  String get attendanceLabel => attendancePercent == null
      ? 'N/A'
      : '${attendancePercent!.toStringAsFixed(1)}%';
  String get revenueLabel => revenueTotal.toStringAsFixed(2);
  String get growthLabel => '${revenueGrowthPercent.toStringAsFixed(1)}%';

  factory DashboardData.fromResponse(Map<String, dynamic> payload) {
    final summary = payload['summary'] as Map<String, dynamic>? ?? const {};
    final revenue = payload['revenue'] as Map<String, dynamic>? ?? const {};
    final months = revenue['months'] as List<dynamic>? ?? const [];

    return DashboardData(
      students: _toInt(summary['students']),
      teachers: _toInt(summary['instructors']),
      subjects: _toInt(summary['subjects']),
      attendancePercent: _toDoubleOrNull(summary['attendance_today_percent']),
      revenueTotal: _toDouble(summary['revenue_total']),
      revenueGrowthPercent: _toDouble(summary['revenue_growth_percent']),
      monthTotals: months
          .whereType<Map<String, dynamic>>()
          .map(MonthlyTotal.fromJson)
          .toList(),
    );
  }
}

class MonthlyTotal {
  const MonthlyTotal({
    required this.label,
    required this.total,
  });

  final String label;
  final double total;

  String get totalLabel => total.toStringAsFixed(2);

  factory MonthlyTotal.fromJson(Map<String, dynamic> json) {
    return MonthlyTotal(
      label: '${json['label'] ?? '--'}',
      total: _toDouble(json['total']),
    );
  }
}

abstract class TokenStore {
  Future<String?> readToken();

  Future<void> writeToken(String token);

  Future<void> deleteToken();
}

class SecureTokenStore implements TokenStore {
  const SecureTokenStore();

  static const _key = 'auth_token';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  Future<String?> readToken() {
    return _storage.read(key: _key);
  }

  @override
  Future<void> writeToken(String token) {
    return _storage.write(key: _key, value: token);
  }

  @override
  Future<void> deleteToken() {
    return _storage.delete(key: _key);
  }
}

class MemoryTokenStore implements TokenStore {
  String? _token;

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<void> writeToken(String token) async {
    _token = token;
  }

  @override
  Future<void> deleteToken() async {
    _token = null;
  }
}

class LaravelApi {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );

  LaravelApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/login'),
      headers: _headers(jsonRequest: true),
      body: jsonEncode({
        'email': email,
        'password': password,
        'device_name': 'flutter-mobile',
      }),
    );

    final payload = _decode(response);
    _throwIfNeeded(response, payload);

    final token = '${payload['token'] ?? ''}'.trim();

    if (token.isEmpty) {
      throw const ApiException(
        'Login succeeded but no API token was returned.',
      );
    }

    return currentUser(token);
  }

  Future<AuthSession> currentUser(String token) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/user'),
      headers: _headers(token: token),
    );

    final payload = _decode(response);
    _throwIfNeeded(response, payload);

    return AuthSession.fromUserResponse(token: token, payload: payload);
  }

  Future<DashboardData> dashboard(String token) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/school/dashboard'),
      headers: _headers(token: token),
    );

    final payload = _decode(response);
    _throwIfNeeded(response, payload);

    return DashboardData.fromResponse(payload);
  }

  Future<void> logout(String token) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/logout'),
      headers: _headers(token: token),
    );

    final payload = _decode(response);
    _throwIfNeeded(response, payload);
  }

  Map<String, String> _headers({String? token, bool jsonRequest = false}) {
    final headers = <String, String>{
      'Accept': 'application/json',
    };

    if (jsonRequest) {
      headers['Content-Type'] = 'application/json';
    }

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.body.isEmpty) {
      return const {};
    }

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } on FormatException {
      return const {};
    }

    return const {};
  }

  void _throwIfNeeded(http.Response response, Map<String, dynamic> payload) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    final message = _extractMessage(payload) ??
        'Request failed with status ${response.statusCode}.';

    throw ApiException(message, statusCode: response.statusCode);
  }

  String? _extractMessage(Map<String, dynamic> payload) {
    final errors = payload['errors'];

    if (errors is Map) {
      for (final value in errors.values) {
        if (value is List && value.isNotEmpty) {
          return '${value.first}';
        }

        if (value is String && value.isNotEmpty) {
          return value;
        }
      }
    }

    final message = payload['message'];
    if (message is String && message.isNotEmpty) {
      return message;
    }

    return null;
  }
}

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

int _toInt(dynamic value) {
  if (value is int) {
    return value;
  }

  if (value is double) {
    return value.round();
  }

  return int.tryParse('$value') ?? 0;
}

double _toDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse('$value') ?? 0;
}

double? _toDoubleOrNull(dynamic value) {
  if (value == null) {
    return null;
  }

  return _toDouble(value);
}
