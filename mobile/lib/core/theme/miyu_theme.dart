import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'miyu_colors.dart';

class MiyuTheme {
  MiyuTheme._();

  static const String _displayFont = 'Inter';

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: MiyuColors.accent,
      onPrimary: Colors.white,
      secondary: MiyuColors.accentSoft,
      surface: MiyuColors.darkSurface,
      onSurface: Colors.white,
      error: MiyuColors.coral,
      outline: MiyuColors.darkBorder,
    );
    return _base(scheme, Brightness.dark).copyWith(
      scaffoldBackgroundColor: MiyuColors.darkBackground,
      dividerColor: MiyuColors.darkBorder,
      textTheme: _textTheme(Brightness.dark),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: Colors.white,
        unselectedItemColor: MiyuColors.darkTextSecondary,
        type: BottomNavigationBarType.fixed,
      ),
      inputDecorationTheme: _inputTheme(
        fill: MiyuColors.darkElevated,
        border: MiyuColors.darkBorder,
        hint: MiyuColors.darkTextSecondary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: MiyuColors.darkElevated,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: MiyuColors.darkTextSecondary,
        textColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.white : MiyuColors.darkTextSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? MiyuColors.accent : MiyuColors.darkBorder,
        ),
      ),
    );
  }

  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: MiyuColors.accentDeep,
      onPrimary: Colors.white,
      secondary: MiyuColors.accent,
      surface: MiyuColors.lightSurface,
      onSurface: Color(0xFF14141B),
      error: MiyuColors.coral,
      outline: MiyuColors.lightBorder,
    );
    return _base(scheme, Brightness.light).copyWith(
      scaffoldBackgroundColor: MiyuColors.lightBackground,
      dividerColor: MiyuColors.lightBorder,
      textTheme: _textTheme(Brightness.light),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: MiyuColors.accentDeep,
        unselectedItemColor: MiyuColors.lightTextSecondary,
        type: BottomNavigationBarType.fixed,
      ),
      inputDecorationTheme: _inputTheme(
        fill: Colors.white,
        border: MiyuColors.lightBorder,
        hint: MiyuColors.lightTextSecondary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Color(0xFF14141B),
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: Color(0xFF14141B)),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1C1C26),
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: MiyuColors.lightTextSecondary,
        textColor: Color(0xFF14141B),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.white : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? MiyuColors.accentDeep : MiyuColors.lightBorder,
        ),
      ),
    );
  }

  static ThemeData _base(ColorScheme scheme, Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      fontFamily: _displayFont,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
        },
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          backgroundColor: MiyuColors.accent,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: MiyuColors.accentSoft,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: brightness == Brightness.dark ? Colors.white : const Color(0xFF14141B),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: brightness == Brightness.dark ? MiyuColors.darkElevated : Colors.white,
        side: BorderSide(
          color: brightness == Brightness.dark ? MiyuColors.darkBorder : MiyuColors.lightBorder,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: brightness == Brightness.dark ? Colors.white : const Color(0xFF14141B),
        ),
      ),
    );
  }

  static TextTheme _textTheme(Brightness brightness) {
    final primary = brightness == Brightness.dark ? Colors.white : const Color(0xFF14141B);
    final secondary = brightness == Brightness.dark
        ? MiyuColors.darkTextSecondary
        : MiyuColors.lightTextSecondary;
    return TextTheme(
      displayLarge: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, letterSpacing: -1.6, color: primary),
      displayMedium: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1.0, color: primary),
      headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: primary),
      headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.6, color: primary),
      titleLarge: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: primary),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.1, color: primary),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primary),
      bodyLarge: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w400, height: 1.4, color: primary),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.45, color: primary),
      bodySmall: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w400, color: secondary),
      labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.2, color: primary),
      labelMedium: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: secondary),
      labelSmall: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 0.4, color: secondary),
    );
  }

  static InputDecorationTheme _inputTheme({
    required Color fill,
    required Color border,
    required Color hint,
  }) {
    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      hintStyle: TextStyle(color: hint, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: MiyuColors.accent, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: MiyuColors.coral),
      ),
    );
  }
}
