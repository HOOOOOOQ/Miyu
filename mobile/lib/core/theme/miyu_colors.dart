import 'package:flutter/material.dart';

/// Miyu palette. Accent is an elegant violet; surfaces stay near-black.
class MiyuColors {
  MiyuColors._();

  static const Color accent = Color(0xFF8B7CFF);
  static const Color accentDeep = Color(0xFF6C5CE7);
  static const Color accentSoft = Color(0xFFB3A8FF);
  static const Color mint = Color(0xFF4ADE80);
  static const Color coral = Color(0xFFFF6B81);
  static const Color amber = Color(0xFFFFC66B);

  // Dark theme
  static const Color darkBackground = Color(0xFF0B0B0F);
  static const Color darkSurface = Color(0xFF14141B);
  static const Color darkElevated = Color(0xFF1C1C26);
  static const Color darkBorder = Color(0xFF2A2A38);
  static const Color darkTextSecondary = Color(0xFF9A9AAB);

  // Light theme
  static const Color lightBackground = Color(0xFFF6F5FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightElevated = Color(0xFFF0EEF8);
  static const Color lightBorder = Color(0xFFE2DFF0);
  static const Color lightTextSecondary = Color(0xFF6B6B7B);

  static const LinearGradient aurora = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B7CFF), Color(0xFF5B8DEF), Color(0xFFB56CFF)],
  );

  static const LinearGradient darkBackdrop = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF12121A), Color(0xFF0B0B0F), Color(0xFF0B0B0F)],
  );

  static const List<Color> avatarPalette = [
    Color(0xFF8B7CFF),
    Color(0xFF5B8DEF),
    Color(0xFFB56CFF),
    Color(0xFF4ADE80),
    Color(0xFFFF6B81),
    Color(0xFFFFC66B),
  ];

  static Color avatarColorFor(String seed) {
    if (seed.isEmpty) return avatarPalette.first;
    final hash = seed.codeUnits.fold<int>(0, (acc, c) => (acc * 31 + c) & 0x7fffffff);
    return avatarPalette[hash % avatarPalette.length];
  }
}
