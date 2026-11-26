import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Non-sensitive local preferences (theme, onboarding, notification toggles).
class Preferences {
  Preferences(this._prefs);

  final SharedPreferences _prefs;

  static const _themeKey = 'miyu.themeMode';
  static const _onboardingKey = 'miyu.onboardingComplete';
  static const _serverOverrideKey = 'miyu.serverUrlOverride';

  static Future<Preferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return Preferences(prefs);
  }

  ThemeMode get themeMode {
    switch (_prefs.getString(_themeKey)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _prefs.setString(_themeKey, value);
  }

  /// Runtime backend override entered in Settings (blank = use the compiled
  /// default). Useful for testing an APK against a LAN or Pterodactyl host
  /// without rebuilding, and for recovering if the baked-in URL is wrong.
  String? get serverUrlOverride {
    final value = _prefs.getString(_serverOverrideKey)?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  Future<void> setServerUrlOverride(String? url) async {
    final value = url?.trim();
    if (value == null || value.isEmpty) {
      await _prefs.remove(_serverOverrideKey);
    } else {
      await _prefs.setString(_serverOverrideKey, value);
    }
  }

  bool get onboardingComplete => _prefs.getBool(_onboardingKey) ?? false;

  Future<void> setOnboardingComplete(bool value) => _prefs.setBool(_onboardingKey, value);

  Future<void> clear() => _prefs.clear();
}
