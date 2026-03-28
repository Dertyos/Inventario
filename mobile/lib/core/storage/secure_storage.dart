import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _tokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _teamIdKey = 'active_team_id';
  static const _serverUrlKey = 'server_url';

  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  Future<void> saveRefreshToken(String token) =>
      _storage.write(key: _refreshTokenKey, value: token);

  Future<String?> getRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> saveActiveTeamId(String teamId) =>
      _storage.write(key: _teamIdKey, value: teamId);

  Future<String?> getActiveTeamId() => _storage.read(key: _teamIdKey);

  Future<void> saveServerUrl(String url) =>
      _storage.write(key: _serverUrlKey, value: url);

  Future<String?> getServerUrl() => _storage.read(key: _serverUrlKey);

  Future<void> clearAll() => _storage.deleteAll();
}
