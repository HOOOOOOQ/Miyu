import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'core/storage/preferences.dart';
import 'providers/core_providers.dart';

/// Top-level FCM handler. Must be a top-level function for background isolates.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase may not be initialized in a fresh background isolate.
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (_) {}
  // System notifications are rendered by the OS for notification payloads;
  // nothing else is required here.
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  // Firebase is optional at boot: the app remains usable (minus push) when the
  // project has not been configured yet.
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (error) {
    AppConfig.debugLog('Firebase unavailable: $error');
  }

  final preferences = await Preferences.load();
  final container = ProviderContainer(overrides: [
    preferencesProvider.overrideWithValue(preferences),
  ]);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MiyuApp(),
    ),
  );
}
