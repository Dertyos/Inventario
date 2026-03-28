import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/biometric_service.dart';

final biometricServiceProvider = Provider<BiometricService>(
  (_) => BiometricService(),
);

/// Whether the app is currently showing the biometric lock screen.
final appLockProvider = NotifierProvider<AppLockNotifier, bool>(
  AppLockNotifier.new,
);

class AppLockNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void lock() => state = true;

  void unlock() => state = false;

  /// Triggers the biometric prompt. Returns true if the user authenticated.
  Future<bool> attemptBiometric() async {
    final service = ref.read(biometricServiceProvider);
    final success = await service.authenticate();
    if (success) state = false;
    return success;
  }
}
