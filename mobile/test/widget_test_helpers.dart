import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miyu/core/theme/miyu_theme.dart';

/// Wraps a widget with the providers + Miyu theme used by real screens.
Future<void> pumpMiyu(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
  ThemeMode themeMode = ThemeMode.dark,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: MiyuTheme.light(),
        darkTheme: MiyuTheme.dark(),
        themeMode: themeMode,
        home: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
