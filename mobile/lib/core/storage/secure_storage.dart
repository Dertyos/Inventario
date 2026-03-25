import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _tokenKey = 'access_token';
  static const _teamIdKey = 'active_team_id';

  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  Future<void> deleteToken() => _storage.delete(key: _tokenKey);

  Future<void> saveActiveTeamId(String teamId) =>
      _storage.write(key: _teamIdKey, value: teamId);

  Future<String?> getActiveTeamId() => _storage.read(key: _teamIdKey);

  Future<void> clearAll() => _storage.deleteAll();
}
