import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/auth_session.dart';
import '../models/dashboard_data.dart';

abstract class OfflineCacheStore {
  Future<AuthSession?> readSession();

  Future<void> writeSession(AuthSession session);

  Future<void> deleteSession();

  Future<DashboardData?> readDashboard();

  Future<void> writeDashboard(DashboardData dashboard);

  Future<void> deleteDashboard();

  Future<void> clear();
}

class FileOfflineCacheStore implements OfflineCacheStore {
  const FileOfflineCacheStore();

  @override
  Future<AuthSession?> readSession() async {
    final json = await _readJsonFile(_sessionFileName);
    if (json == null) {
      return null;
    }

    return AuthSession.fromJson(json);
  }

  @override
  Future<void> writeSession(AuthSession session) {
    return _writeJsonFile(_sessionFileName, session.toJson());
  }

  @override
  Future<void> deleteSession() {
    return _deleteFile(_sessionFileName);
  }

  @override
  Future<DashboardData?> readDashboard() async {
    final json = await _readJsonFile(_dashboardFileName);
    if (json == null) {
      return null;
    }

    return DashboardData.fromJson(json);
  }

  @override
  Future<void> writeDashboard(DashboardData dashboard) {
    return _writeJsonFile(_dashboardFileName, dashboard.toJson());
  }

  @override
  Future<void> deleteDashboard() {
    return _deleteFile(_dashboardFileName);
  }

  @override
  Future<void> clear() async {
    await deleteSession();
    await deleteDashboard();
  }

  Future<File> _file(String fileName) async {
    final directory = await getApplicationSupportDirectory();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return File('${directory.path}${Platform.pathSeparator}$fileName');
  }

  Future<void> _deleteFile(String fileName) async {
    try {
      final file = await _file(fileName);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _readJsonFile(String fileName) async {
    try {
      final file = await _file(fileName);
      if (!await file.exists()) {
        return null;
      }

      final text = await file.readAsString();
      if (text.trim().isEmpty) {
        return null;
      }

      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}

    return null;
  }

  Future<void> _writeJsonFile(
    String fileName,
    Map<String, dynamic> value,
  ) async {
    try {
      final file = await _file(fileName);
      await file.writeAsString(jsonEncode(value));
    } catch (_) {}
  }
}

class MemoryOfflineCacheStore implements OfflineCacheStore {
  AuthSession? _session;
  DashboardData? _dashboard;

  @override
  Future<void> clear() async {
    _session = null;
    _dashboard = null;
  }

  @override
  Future<void> deleteDashboard() async {
    _dashboard = null;
  }

  @override
  Future<void> deleteSession() async {
    _session = null;
  }

  @override
  Future<DashboardData?> readDashboard() async => _dashboard;

  @override
  Future<AuthSession?> readSession() async => _session;

  @override
  Future<void> writeDashboard(DashboardData dashboard) async {
    _dashboard = dashboard;
  }

  @override
  Future<void> writeSession(AuthSession session) async {
    _session = session;
  }
}

const _sessionFileName = 'auth_session_cache.json';
const _dashboardFileName = 'dashboard_cache.json';
