import 'package:dio/dio.dart';

/// Retries requests on timeout/connection errors and 502/503 responses
/// (handles Render free tier cold starts, which can take up to 30s).
class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;
  final Duration retryDelay;

  RetryInterceptor({
    required this.dio,
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 4),
  });

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final retryCount = err.requestOptions.extra['retryCount'] ?? 0;

    if (_shouldRetry(err) && retryCount < maxRetries) {
      // Exponential backoff: 4s, 8s, 16s
      final delay = retryDelay * (1 << retryCount);
      await Future.delayed(delay);

      err.requestOptions.extra['retryCount'] = retryCount + 1;

      try {
        final response = await dio.fetch(err.requestOptions);
        handler.resolve(response);
        return;
      } on DioException catch (e) {
        // If we still have retries left, the next onError will handle it
        handler.next(e);
        return;
      }
    }

    handler.next(err);
  }

  bool _shouldRetry(DioException err) {
    // Retry on network-level errors
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError) {
      return true;
    }
    // Retry on 502/503 — Render returns these during cold starts
    final statusCode = err.response?.statusCode;
    if (statusCode == 502 || statusCode == 503) {
      return true;
    }
    return false;
  }
}
