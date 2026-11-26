import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miyu/config/app_config.dart';
import 'package:miyu/core/storage/preferences.dart';
import 'package:miyu/features/settings/settings_screen.dart';
import 'package:miyu/providers/core_providers.dart';
import 'package:miyu/providers/session_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widget_test_helpers.dart';

/// Guards Settings → "Server address", the only way to repoint a shipped APK
/// at a different backend. A regression here would strand users on a dead host
/// with no recovery short of a new build.
void main() {
  late Preferences preferences;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    preferences = await Preferences.load();
  });

  List<Override> overrides({String? serverUrl}) => [
        currentUserProvider.overrideWith((ref) => null),
        preferencesProvider.overrideWithValue(preferences),
        serverUrlProvider.overrideWith((ref) => serverUrl),
      ];

  testWidgets('shows the compiled backend host when nothing is overridden', (tester) async {
    await pumpMiyu(tester, const SettingsScreen(), overrides: overrides());

    expect(find.text(AppConfig.normalizedApiBaseUrl), findsOneWidget);
  });

  testWidgets('shows a saved override instead of the default', (tester) async {
    await pumpMiyu(
      tester,
      const SettingsScreen(),
      overrides: overrides(serverUrl: 'http://192.168.1.10:5000'),
    );

    expect(find.text('http://192.168.1.10:5000'), findsOneWidget);
    expect(find.text(AppConfig.normalizedApiBaseUrl), findsNothing);
  });

  testWidgets('tapping the tile opens an editable dialog prefilled with the host',
      (tester) async {
    await pumpMiyu(
      tester,
      const SettingsScreen(),
      overrides: overrides(serverUrl: 'http://192.168.1.10:5000'),
    );

    await tester.tap(find.text('Server address'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Use default'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'http://192.168.1.10:5000',
    );
  });

  testWidgets('saving a bare host normalises it and persists it', (tester) async {
    await pumpMiyu(tester, const SettingsScreen(), overrides: overrides());

    await tester.tap(find.text('Server address'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '192.168.1.10:5000');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(preferences.serverUrlOverride, 'http://192.168.1.10:5000');
  });

  testWidgets('"Use default" clears a stored override', (tester) async {
    await preferences.setServerUrlOverride('http://192.168.1.10:5000');
    await pumpMiyu(
      tester,
      const SettingsScreen(),
      overrides: overrides(serverUrl: 'http://192.168.1.10:5000'),
    );

    await tester.tap(find.text('Server address'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use default'));
    await tester.pumpAndSettle();

    expect(preferences.serverUrlOverride, isNull);
  });

  testWidgets('an invalid address is rejected and nothing is written', (tester) async {
    await pumpMiyu(tester, const SettingsScreen(), overrides: overrides());

    await tester.tap(find.text('Server address'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ftp://nope');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(preferences.serverUrlOverride, isNull);
  });
}
