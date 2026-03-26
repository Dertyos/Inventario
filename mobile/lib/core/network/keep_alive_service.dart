import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';

/// Pings the backend /health endpoint periodically to prevent
/// Render free-tier instances from spinning down after inactivity.
class KeepAliveService {
  final Dio _dio;
  Timer? _timer;

  static const _interval = Duration(minutes: 10);

  KeepAliveService(this._dio);

  void start() {
    _timer?.cancel();
    // Fire immediately, then repeat every interval
    _ping();
    _timer = Timer.periodic(_interval, (_) => _ping());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _ping() async {
    try {
      await _dio.get('/health');
    } catch (_) {
      // Silently ignore — the retry interceptor handles transient failures
      debugPrint('[KeepAlive] health ping failed');
    }
  }
}

final keepAliveServiceProvider = Provider<KeepAliveService>((ref) {
  final dio = ref.read(dioProvider);
  final service = KeepAliveService(dio);
  ref.onDispose(() => service.stop());
  return service;
});
