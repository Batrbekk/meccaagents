import 'package:agentteam/core/api/dio_client.dart';
import 'package:agentteam/core/auth/secure_storage.dart';
import 'package:agentteam/features/auth/domain/user.dart';

class AuthRepository {
  Future<User> login(String email, String password) async {
    final response = await dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });

    final data = response.data as Map<String, dynamic>;
    final token = data['accessToken'] as String;
    final user = User.fromJson(data['user'] as Map<String, dynamic>);

    await AuthStorage.saveAccessToken(token);
    await AuthStorage.saveUserJson(user.toJsonString());

    return user;
  }

  Future<void> refresh() async {
    final response = await dio.post('/auth/refresh');
    final data = response.data as Map<String, dynamic>;
    final token = data['accessToken'] as String;
    await AuthStorage.saveAccessToken(token);
  }

  Future<void> logout() async {
    try {
      await dio.post('/auth/logout');
    } catch (_) {
      // Ignore logout errors — clear local state regardless
    }
    await AuthStorage.clearAll();
  }

  Future<User?> getCurrentUser() async {
    final json = await AuthStorage.getUserJson();
    if (json == null) return null;
    try {
      return User.fromJsonString(json);
    } catch (_) {
      return null;
    }
  }
}
