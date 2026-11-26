import 'package:flutter/foundation.dart';

/// Compile-time configuration, injected by `--dart-define`.
///
/// Only public values belong here. Database URIs, API secrets and TURN
/// credentials must never be compiled into the APK — TURN credentials are
/// fetched from the backend at call time.
class AppConfig {
  AppConfig._();

  static const String appName = 'Miyu';
  static const String appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');
  static const String appEnv = String.fromEnvironment('APP_ENV', defaultValue: 'development');

  /// e.g. https://miyu-api.example.com  (no trailing slash)
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000',
  );

  /// Defaults to the API host; override only when sockets live elsewhere.
  static const String socketUrl = String.fromEnvironment(
    'SOCKET_URL',
    defaultValue: 'http://10.0.2.2:5000',
  );

  /// Google Web client id (public). Required for Google Sign-In on Android
  /// when using the server-auth code flow.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );

  static bool get isProduction => appEnv.toLowerCase() == 'production';
  static bool get isDev => !isProduction;

  static String get normalizedApiBaseUrl => apiBaseUrl.endsWith('/')
      ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
      : apiBaseUrl;

  static String get normalizedSocketUrl => socketUrl.endsWith('/')
      ? socketUrl.substring(0, socketUrl.length - 1)
      : socketUrl;

  /// Reports the resolved environment in the About screen so testers can
  /// confirm which backend an APK points at.
  static String get summary => '$appName $appVersion · $appEnv\n$normalizedApiBaseUrl';

  static void debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[Miyu] $message');
    }
  }
}
