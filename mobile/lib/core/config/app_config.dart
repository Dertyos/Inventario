class AppConfig {
  AppConfig._();

  static const String appName = 'Inventario';
  static const String appVersion = '1.1.0';
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://inventario.dertyos.com',
  );
  static const Duration connectTimeout = Duration(seconds: 60);
  static const Duration receiveTimeout = Duration(seconds: 60);
}
