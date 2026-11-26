import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/app_config.dart';
import 'core/theme/miyu_theme.dart';
import 'providers/settings_provider.dart';
import 'routing/app_router.dart';

class MiyuApp extends ConsumerWidget {
  const MiyuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      themeMode: themeMode,
      theme: MiyuTheme.light(),
      darkTheme: MiyuTheme.dark(),
      builder: (context, child) {
        // Cap text scaling so glass layouts do not break with extreme
        // accessibility settings, while still respecting user preference.
        final scaler = MediaQuery.of(context).textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.3);
        return MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: scaler), child: child!);
      },
    );
  }
}
