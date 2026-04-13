import 'package:dio/dio.dart';
import 'package:agentteam/core/auth/secure_storage.dart';

const String _baseUrl = 'http://localhost:3000';

final dio = Dio(
  BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ),
)..interceptors.add(_AuthInterceptor());

class _AuthInterceptor extends Interceptor {
  bool _isRefreshing = false;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await AuthStorage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      // Token expired — clear and let UI redirect to login
      _isRefreshing = true;
      await AuthStorage.clearAll();
      _isRefreshing = false;
    }
    handler.next(err);
  }
}
