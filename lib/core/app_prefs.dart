import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences provider used across the app.
final sharedPrefsProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
}, name: 'sharedPrefsProvider');

/// Simple local persistence helper (defaults, plus offline toggles).
class AppPrefs {
  static const String _kAppearanceStyle = 'appearance_style';
  static const String _kThemeMode = 'theme_mode';
  static const String _kAccentColor = 'accent_color';
  static const String _kLanguage = 'language';
  static const String _kAccountToken = 'account_token';
  static const String _kAccountUsername = 'account_username';
  static const String _kAccountRole = 'account_role';
  static const String _kCloudEnabled = 'cloud_enabled';

  static const String _kVolume = 'volume';
  static const String _kRepeat = 'repeat_mode';
  static const String _kSpeed = 'playback_speed';

  static Future<SharedPreferences> _load() => SharedPreferences.getInstance();
}
