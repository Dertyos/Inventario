import 'package:dio/dio.dart';
import '../storage/secure_storage.dart';

/// Callback invoked when a 401 response forces a session expiration.
typedef OnSessionExpired = void Function();

class AuthInterceptor extends Interceptor {
  final SecureStorage _storage;
  final OnSessionExpired? onSessionExpired;

  AuthInterceptor(this._storage, {this.onSessionExpired});

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
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      _storage.deleteToken();
      onSessionExpired?.call();
    }
    handler.next(err);
  }
}
