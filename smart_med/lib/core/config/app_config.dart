class AppConfig {
  const AppConfig._();

  static const String _defaultApiBaseUrl = 'https://smartmed-km6mdeft.b4a.run';

  static const String _configuredApiBaseUrl = String.fromEnvironment(
    'SMART_MED_API_BASE_URL',
  );

  static String get apiBaseUrl {
    if (_configuredApiBaseUrl.isNotEmpty) {
      return _configuredApiBaseUrl;
    }

    return _defaultApiBaseUrl;
  }
}
