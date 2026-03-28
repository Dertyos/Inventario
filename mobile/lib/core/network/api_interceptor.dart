import 'package:dio/dio.dart';
import '../storage/secure_storage.dart';

/// Callback invoked when a 401 response forces a session expiration.
typedef OnSessionExpired = void Function();

class AuthInterceptor extends Interceptor {
  final SecureStorage _storage;
  final OnSessionExpired? onSessionExpired;

  /// Prevents multiple concurrent 401 responses from triggering
  /// session expiration logic more than once.
  bool _isHandlingExpiration = false;

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
    if (err.response?.statusCode == 401 && !_isHandlingExpiration) {
      _isHandlingExpiration = true;
      _storage.deleteToken().then((_) {
        onSessionExpired?.call();
        // Reset after a short delay to allow re-login flow to complete
        Future.delayed(const Duration(seconds: 2), () {
          _isHandlingExpiration = false;
        });
      });
    }
    handler.next(err);
  }
}
