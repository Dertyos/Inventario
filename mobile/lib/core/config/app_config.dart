import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/secure_storage.dart';

class AppConfig {
  AppConfig._();

  static const String appName = 'Inventario';
  static const String appVersion = '1.2.0';
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://inventario.dertyos.com',
  );
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}

/// Holds the current server URL. Initialized from storage, updated from settings.
class ServerUrlNotifier extends Notifier<String> {
  @override
  String build() => AppConfig.baseUrl;

  void update(String url) => state = url;
}

final serverUrlProvider =
    NotifierProvider<ServerUrlNotifier, String>(ServerUrlNotifier.new);

/// Loads the saved server URL from storage on app start.
Future<String> loadServerUrl(SecureStorage storage) async {
  final saved = await storage.getServerUrl();
  return saved ?? AppConfig.baseUrl;
}
