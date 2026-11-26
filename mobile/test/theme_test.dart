import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miyu/core/theme/miyu_colors.dart';
import 'package:miyu/core/theme/miyu_theme.dart';

void main() {
  group('Miyu theme', () {
    test('dark theme uses near-black surfaces and violet accent', () {
      final theme = MiyuTheme.dark();
      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, MiyuColors.accent);
      expect(theme.scaffoldBackgroundColor, MiyuColors.darkBackground);
      expect(theme.textTheme.bodyLarge?.color, Colors.white);
    });

    test('light theme keeps readable contrast', () {
      final theme = MiyuTheme.light();
      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, MiyuColors.lightBackground);
      expect(theme.textTheme.bodyLarge?.color, isNot(Colors.white));
    });

    test('avatar colors are deterministic per seed', () {
      final a = MiyuColors.avatarColorFor('user-1');
      final b = MiyuColors.avatarColorFor('user-1');
      expect(a, b);
      expect(MiyuColors.avatarPalette.contains(a), isTrue);
      expect(MiyuColors.avatarColorFor(''), MiyuColors.avatarPalette.first);
    });

    test('both themes expose filled button styling', () {
      for (final theme in [MiyuTheme.dark(), MiyuTheme.light()]) {
        final style = theme.filledButtonTheme.style;
        expect(style, isNotNull);
        expect(theme.useMaterial3, isTrue);
      }
    });
  });

  testWidgets('theme mode switches between light and dark material apps', (tester) async {
    Widget build(ThemeMode mode) => MaterialApp(
          theme: MiyuTheme.light(),
          darkTheme: MiyuTheme.dark(),
          themeMode: mode,
          home: const Scaffold(body: Text('Miyu')),
        );

    await tester.pumpWidget(build(ThemeMode.dark));
    expect(Theme.of(tester.element(find.text('Miyu'))).brightness, Brightness.dark);

    await tester.pumpWidget(build(ThemeMode.light));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.text('Miyu'))).brightness, Brightness.light);
  });
}
