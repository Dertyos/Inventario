import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

extension CacheForExtension on AutoDisposeRef {
  /// Keeps the provider alive for [duration] after losing all listeners.
  ///
  /// This is the standard production pattern: data stays in memory for a while
  /// so tab switches are instant, but eventually frees memory.
  void cacheFor(Duration duration) {
    final link = keepAlive();
    final timer = Timer(duration, link.close);
    onDispose(timer.cancel);
  }
}
