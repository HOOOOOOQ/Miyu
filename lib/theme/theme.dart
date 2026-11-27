import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miyu/core/app_prefs.dart';

/// Appearance style (MASTER TASK: flat / glass).
enum appearanceStyle { flat, glass }

/// Theme mode (MASTER TASK: light / dark / system).
enum appearanceMode { light, dark, system }

/// Miyu palette — exact values from the MASTER TASK.
class MiyuColors {
  static const Color bgDark = Color(0xFF0B0C0F); // Background
  static const Color surfaceDark = Color(0xFF15161A); // Surface
  static const Color elevatedDark = Color(0xFF202127); // Elevated
  static const Color accentDark = Color(0xFFA855F7); // Accent
  static const Color secondaryDark = Color(0xFF6D28D9); // Secondary
  static const Color textDark = Color(0xFFF2F4F7); // Text

  static const Color bgLight = Color(0xFFF7F7FA); // Background
  static const Color surfaceLight = Color(0xFFFFFFFF); // Surface
  static const Color accentLight = Color(0xFF7C3AED); // Accent
  static const Color textLight = Color(0xFF17171C); // Text
}

/// Appearance state persisted in SharedPreferences.
class ThemeState {
  final appearanceStyle style;
  final appearanceMode themeMode;
  final Color? accent;

  const ThemeState({
    this.style = appearanceStyle.flat,
    this.themeMode = appearanceMode.system,
    this.accent,
  });

  ThemeState copyWith({appearanceStyle? style, appearanceMode? themeMode, Color? accent}) {
    return ThemeState(style: style ?? this.style, themeMode: themeMode ?? this.themeMode, accent: accent ?? this.accent);
  }

  /// Effective accent color for the current mode (override or default).
  Color get accentColor => accent ?? (MiyuColors.accentDark);
}

/// Pair of Material 3 themes (light + dark) for the selected style.
class MiyuThemes {
  final ThemeData light;
  final ThemeData dark;

  MiyuThemes(this.light, this.dark);

  factory MiyuThemes.fromState(ThemeState state) {
    final isDark = true;
    final cs = ColorScheme.dark(primary: state.accentColor, surfaceTint: state.accentColor);
    final dark = ThemeData.dark(useMaterial3: true)
        .copyWith(scaffoldBackgroundColor: state.style == appearanceStyle.glass ? null : MiyuColors.bgDark,
                  cardColor: state.style == appearanceStyle.glass ? Colors.transparent : MiyuColors.surfaceDark);
    final csLight = ColorScheme.light(primary: state.accentColor, surfaceTint: state.accentColor);
    final light = ThemeData.light(useMaterial3: true)
        .copyWith(scaffoldBackgroundColor: state.style == appearanceStyle.glass ? null : MiyuColors.bgLight,
                  cardColor: state.style == appearanceStyle.glass ? Colors.transparent : MiyuColors.surfaceLight);
    return MiyuThemes(light, dark);
  }

  ThemeData forSystemDark(bool dark) => dark ? dark : light;
}

class ThemeNotifier extends AsyncNotifier<ThemeState> {
  @override
  Future<ThemeState> build() async {
    final prefs = await ref.watch(sharedPrefsProvider.future);
    final styleRaw = prefs.getString('appearance_style') ?? appearanceStyle.flat.name;
    final modeRaw = prefs.getString('theme_mode') ?? appearanceMode.system.name;
    final accentRaw = prefs.getString('accent_color');
    return ThemeState(
      style: appearanceStyle.values.firstWhere((e) => e.name == styleRaw),
      themeMode: appearanceMode.values.firstWhere((e) => e.name == modeRaw),
      accent: accentRaw == null || accentRaw.isEmpty ? null : Color(int.parse(accentRaw, radix: 16)),
    );
  }

  /// Update appearance + persist. Users change it anytime without restart (MASTER TASK).
  Future<void> update(ThemeState next) async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    await prefs.setString('appearance_style', next.style.name);
    await prefs.setString('theme_mode', next.themeMode.name);
    await prefs.setString('accent_color', next.accent?.value.toRadixString(16) ?? '');
    state = next;
  }
}

final themeStateProvider = AsyncNotifierProvider<ThemeNotifier, ThemeState>(ThemeNotifier.new);
