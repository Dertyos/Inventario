import 'package:dio/dio.dart';
import '../storage/secure_storage.dart';

/// Callback invoked when a 401 response forces a session expiration.
typedef OnSessionExpired = void Function();

class AuthInterceptor extends QueuedInterceptor {
  final SecureStorage _storage;
  final Dio _dio;
  final OnSessionExpired? onSessionExpired;

  /// Prevents multiple concurrent refresh attempts.
  bool _isRefreshing = false;

  AuthInterceptor(this._storage, this._dio, {this.onSessionExpired});

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.getToken();
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
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    // Don't try to refresh the refresh request itself
    final path = err.requestOptions.path;
    if (path.contains('/auth/refresh') || path.contains('/auth/login') || path.contains('/auth/register')) {
      _forceLogout();
      return handler.next(err);
    }

    if (_isRefreshing) {
      return handler.next(err);
    }

    _isRefreshing = true;
    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null) {
        _forceLogout();
        return handler.next(err);
      }

      // Attempt to refresh tokens
      final response = await _dio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      final data = response.data as Map<String, dynamic>;
      final newAccessToken = data['accessToken'] as String;
      final newRefreshToken = data['refreshToken'] as String?;

      await _storage.saveToken(newAccessToken);
      if (newRefreshToken != null) {
        await _storage.saveRefreshToken(newRefreshToken);
      }

      _isRefreshing = false;

      // Retry the original request with the new token
      final retryOptions = err.requestOptions;
      retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';
      final retryResponse = await _dio.fetch(retryOptions);
      return handler.resolve(retryResponse);
    } catch (_) {
      _isRefreshing = false;
      _forceLogout();
      return handler.next(err);
    }
  }

  void _forceLogout() {
    _storage.deleteToken().then((_) {
      onSessionExpired?.call();
    });
  }
}
