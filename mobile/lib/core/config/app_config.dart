import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/secure_storage.dart';
import '../network/api_client.dart';

class AppConfig {
  AppConfig._();

  static const String appName = 'Inventario';
  static const String appVersion = '1.1.0';
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://inventario.dertyos.com',
  );
  static const String defaultBaseUrl = baseUrl;
  static const Duration connectTimeout = Duration(seconds: 60);
  static const Duration receiveTimeout = Duration(seconds: 60);
}

/// Holds the current server URL. Initialized from storage, updated from settings.
final serverUrlProvider = StateProvider<String>((ref) => AppConfig.baseUrl);

/// Loads the saved server URL from storage on app start.
Future<String> loadServerUrl(SecureStorage storage) async {
  final saved = await storage.getServerUrl();
  return saved ?? AppConfig.baseUrl;
}
