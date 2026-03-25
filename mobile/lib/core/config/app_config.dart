class AppConfig {
  AppConfig._();

  static const String appName = 'Inventario';
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://inventario-hxzw.onrender.com',
  );
  static const Duration connectTimeout = Duration(seconds: 60);
  static const Duration receiveTimeout = Duration(seconds: 60);
}
