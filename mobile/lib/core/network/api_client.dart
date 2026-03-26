import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../storage/secure_storage.dart';
import 'api_interceptor.dart';
import 'retry_interceptor.dart';

/// Set by AuthNotifier on init so the interceptor can force logout on 401.
void Function()? _onSessionExpired;

void setSessionExpiredCallback(void Function() callback) {
  _onSessionExpired = callback;
}

final dioProvider = Provider<Dio>((ref) {
  final serverUrl = ref.watch(serverUrlProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: serverUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: {'Content-Type': 'application/json'},
    ),
  );
  dio.interceptors.add(AuthInterceptor(
    ref.read(secureStorageProvider),
    onSessionExpired: () => _onSessionExpired?.call(),
  ));
  dio.interceptors.add(RetryInterceptor(dio: dio));
  dio.interceptors.add(LogInterceptor(
    requestBody: true,
    responseBody: true,
    logPrint: (o) {},
  ));
  return dio;
});

final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage());
