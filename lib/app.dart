import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miyu/features/splash/splash_screen.dart';
import 'package:miyu/theme/theme.dart';

class MiyuApp extends ConsumerWidget {
  const MiyuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(themeStateProvider);
    final state = async.value ?? const ThemeState();
    final themes = MiyuThemes.fromState(state);
    return MaterialApp(
      title: 'Miyu',
      debugShowCheckedModeBanner: false,
      theme: themes.light,
      darkTheme: themes.dark,
      themeMode: state.themeMode,
      home: const SplashScreen(),
    );
  }
}
