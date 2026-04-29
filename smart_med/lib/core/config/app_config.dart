import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig._();

  static const String _configuredApiBaseUrl = String.fromEnvironment(
    'SMART_MED_API_BASE_URL',
  );

  static String get apiBaseUrl {
    if (_configuredApiBaseUrl.isNotEmpty) {
      return _configuredApiBaseUrl;
    }

    if (kIsWeb) {
      final uri = Uri.base;
      return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://192.168.1.101:8000';
      default:
        return 'http://127.0.0.1:8000';
    }
  }
}
