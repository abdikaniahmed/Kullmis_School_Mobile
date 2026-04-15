import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
