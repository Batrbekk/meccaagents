import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  static const _accessTokenKey = 'access_token';
  static const _userJsonKey = 'user_json';

  // In-memory cache — instantly available after write
  static String? _cachedToken;
  static String? _cachedUserJson;
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  static Future<void> saveAccessToken(String token) async {
    _cachedToken = token;
    final prefs = await _getPrefs();
    await prefs.setString(_accessTokenKey, token);
  }

  static Future<String?> getAccessToken() async {
    if (_cachedToken != null) return _cachedToken;
    final prefs = await _getPrefs();
    _cachedToken = prefs.getString(_accessTokenKey);
    return _cachedToken;
  }

  static Future<void> saveUserJson(String json) async {
    _cachedUserJson = json;
    final prefs = await _getPrefs();
    await prefs.setString(_userJsonKey, json);
  }

  static Future<String?> getUserJson() async {
    if (_cachedUserJson != null) return _cachedUserJson;
    final prefs = await _getPrefs();
    _cachedUserJson = prefs.getString(_userJsonKey);
    return _cachedUserJson;
  }

  static Future<void> clearAll() async {
    _cachedToken = null;
    _cachedUserJson = null;
    final prefs = await _getPrefs();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_userJsonKey);
  }
}
