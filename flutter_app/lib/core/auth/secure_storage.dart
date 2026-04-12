import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  static const _storage = FlutterSecureStorage();

  static const _accessTokenKey = 'access_token';
  static const _userJsonKey = 'user_json';

  static Future<void> saveAccessToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
  }

  static Future<String?> getAccessToken() async {
    return _storage.read(key: _accessTokenKey);
  }

  static Future<void> saveUserJson(String json) async {
    await _storage.write(key: _userJsonKey, value: json);
  }

  static Future<String?> getUserJson() async {
    return _storage.read(key: _userJsonKey);
  }

  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
