import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Non-sensitive local preferences (theme, onboarding, notification toggles).
class Preferences {
  Preferences(this._prefs);

  final SharedPreferences _prefs;

  static const _themeKey = 'miyu.themeMode';
  static const _onboardingKey = 'miyu.onboardingComplete';

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

  bool get onboardingComplete => _prefs.getBool(_onboardingKey) ?? false;

  Future<void> setOnboardingComplete(bool value) => _prefs.setBool(_onboardingKey, value);

  Future<void> clear() => _prefs.clear();
}
