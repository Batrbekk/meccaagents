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
    if (err.response?.statusCode == 401) {
      try {
        final refreshDio = Dio(
          BaseOptions(baseUrl: _baseUrl),
        );
        final res = await refreshDio.post('/auth/refresh');
        final newToken = res.data['accessToken'] as String;
        await AuthStorage.saveAccessToken(newToken);

        final retryOptions = err.requestOptions;
        retryOptions.headers['Authorization'] = 'Bearer $newToken';
        final retryResponse = await dio.fetch(retryOptions);
        return handler.resolve(retryResponse);
      } catch (_) {
        await AuthStorage.clearAll();
      }
    }
    handler.next(err);
  }
}
