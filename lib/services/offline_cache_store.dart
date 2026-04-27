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

  Future<Map<String, dynamic>?> readCacheDocument(String key);

  Future<void> writeCacheDocument(String key, Map<String, dynamic> value);

  Future<void> deleteCacheDocument(String key);

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
  Future<Map<String, dynamic>?> readCacheDocument(String key) {
    return _readJsonFile(_documentFileName(key));
  }

  @override
  Future<void> writeCacheDocument(String key, Map<String, dynamic> value) {
    return _writeJsonFile(_documentFileName(key), value);
  }

  @override
  Future<void> deleteCacheDocument(String key) {
    return _deleteFile(_documentFileName(key));
  }

  @override
  Future<void> clear() async {
    await deleteSession();
    await deleteDashboard();
    try {
      final directory = await getApplicationSupportDirectory();
      if (!await directory.exists()) {
        return;
      }

      final entities = directory.listSync();
      for (final entity in entities) {
        if (entity is! File) {
          continue;
        }

        final name = entity.uri.pathSegments.isEmpty
            ? ''
            : entity.uri.pathSegments.last;
        if (!name.startsWith('cache_') || !name.endsWith('.json')) {
          continue;
        }

        await entity.delete();
      }
    } catch (_) {}
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
  final Map<String, Map<String, dynamic>> _documents = {};

  @override
  Future<void> clear() async {
    _session = null;
    _dashboard = null;
    _documents.clear();
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
  Future<void> deleteCacheDocument(String key) async {
    _documents.remove(key);
  }

  @override
  Future<DashboardData?> readDashboard() async => _dashboard;

  @override
  Future<AuthSession?> readSession() async => _session;

  @override
  Future<Map<String, dynamic>?> readCacheDocument(String key) async {
    return _documents[key];
  }

  @override
  Future<void> writeDashboard(DashboardData dashboard) async {
    _dashboard = dashboard;
  }

  @override
  Future<void> writeSession(AuthSession session) async {
    _session = session;
  }

  @override
  Future<void> writeCacheDocument(String key, Map<String, dynamic> value) async {
    _documents[key] = value;
  }
}

const _sessionFileName = 'auth_session_cache.json';
const _dashboardFileName = 'dashboard_cache.json';

String _documentFileName(String key) => 'cache_$key.json';
