import 'package:flutter/foundation.dart';

/// Compile-time configuration, injected by `--dart-define`.
///
/// Only public values belong here. Database URIs, API secrets and TURN
/// credentials must never be compiled into the APK — TURN credentials are
/// fetched from the backend at call time.
///
/// Runtime overrides: the backend host can be changed inside the app (Settings
/// → Server address) without rebuilding, so a tester can point the same APK at
/// a laptop on the LAN, an emulator, or the Pterodactyl host below.
class AppConfig {
  AppConfig._();

  static const String appName = 'Miyu';
  static const String appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');
  static const String appEnv = String.fromEnvironment('APP_ENV', defaultValue: 'development');

  /// Deployed backend for this project. It is public information (the phone
  /// has to reach it), so it is a sane default rather than a secret. Override
  /// with `--dart-define=API_BASE_URL=...` for any other environment.
  static const String defaultServerUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://play.notmemc.my.id:3186',
  );

  /// e.g. https://miyu-api.example.com  (no trailing slash)
  static const String apiBaseUrl = defaultServerUrl;

  /// Defaults to the API host; override only when sockets live elsewhere.
  static const String socketUrl = String.fromEnvironment(
    'SOCKET_URL',
    defaultValue: defaultServerUrl,
  );

  /// Google Web client id (public). Required for Google Sign-In on Android
  /// when using the server-auth code flow.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );

  static bool get isProduction => appEnv.toLowerCase() == 'production';
  static bool get isDev => !isProduction;

  static String get normalizedApiBaseUrl => _trimSlash(apiBaseUrl);

  static String get normalizedSocketUrl => _trimSlash(socketUrl);

  /// Backend the app actually talks to: the Settings override when present,
  /// otherwise the compiled default. [override] comes from Preferences and is
  /// passed down through the providers rather than read here, because this
  /// class is `const` configuration.
  static String resolvedApiBaseUrl([String? override]) =>
      override != null && override.isNotEmpty ? _trimSlash(override) : normalizedApiBaseUrl;

  static String resolvedSocketUrl([String? override]) =>
      override != null && override.isNotEmpty ? _trimSlash(override) : normalizedSocketUrl;

  /// Normalises whatever the user typed into Settings into a scheme+host,
  /// e.g. `play.notmemc.my.id:3186` -> `http://play.notmemc.my.id:3186`.
  /// Returns null when the input cannot be a host, so the UI can reject it
  /// instead of writing a broken value that only fails at the next request.
  static String? normalizeServerInput(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return null;
    if (!value.contains('://')) value = 'http://$value';
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return _trimSlash(value);
  }

  static String _trimSlash(String value) =>
      value.endsWith('/') ? value.substring(0, value.length - 1) : value;

  /// Reports the resolved environment in the About screen so testers can
  /// confirm which backend an APK points at.
  static String get summary => '$appName $appVersion · $appEnv\n$normalizedApiBaseUrl';

  static void debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[Miyu] $message');
    }
  }
}
