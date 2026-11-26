import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core_providers.dart';

class SettingsController extends StateNotifier<ThemeMode> {
  SettingsController({required Ref ref})
      : _ref = ref,
        super(ref.read(preferencesProvider).themeMode);

  final Ref _ref;

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _ref.read(preferencesProvider).setThemeMode(mode);
  }
}

final themeModeProvider = StateNotifierProvider<SettingsController, ThemeMode>((ref) {
  return SettingsController(ref: ref);
});

/// Global "am I allowed to show a floating banner" switch, toggled from
/// Settings → Notifications.
class InAppBannerController extends StateNotifier<bool> {
  InAppBannerController() : super(true);
  void setEnabled(bool value) => state = value;
}

final inAppBannerProvider = StateNotifierProvider<InAppBannerController, bool>((ref) {
  return InAppBannerController();
});
