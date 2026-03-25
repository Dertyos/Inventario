import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/secure_storage.dart';
import '../network/api_client.dart';

class AppConfig {
  AppConfig._();

  static const String appName = 'Inventario';
  static const String appVersion = '1.1.0';

  /// Default API URL. Override at build time with --dart-define=API_BASE_URL=...
  /// or change at runtime via Settings > Servidor.
  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}

/// Holds the current server URL. Initialized from storage, updated from settings.
final serverUrlProvider = StateProvider<String>((ref) => AppConfig.defaultBaseUrl);

/// Loads the saved server URL from storage on app start.
Future<String> loadServerUrl(SecureStorage storage) async {
  final saved = await storage.getServerUrl();
  return saved ?? AppConfig.defaultBaseUrl;
}
