import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miyu/auth/auth_service.dart';
import 'package:miyu/auth/login_screen.dart';
import 'package:miyu/core/constants.dart';
import 'package:miyu/features/home/home_page.dart';
import 'package:miyu/theme/theme.dart';
import 'package:miyu/widgets/miyu_logo.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final introCards = [
      const SplashCard('music.youtube.com integration', 'Discovery',
          'Semua fitur original tetap dipertahankan: aliran musik YouTube Music revers-engineered'),
      const SplashCard('Level + Progress', 'Percaya',
          'Bangun level lewat jam mendengarkan — 180 menit per level, maksimum 100'),
      const SplashCard('Music Player V2.5', 'Solusi',
          'MPlayer: queue, shuffle, repeat, lyrics, mini player, background playback'),
    ];

    return Scaffold(
      backgroundColor: MiyuColors.bgDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const MiyuLogo(size: 72),
            const SizedBox(height: 18),
            Text(AppConstants.appName,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(color: MiyuColors.textDark)),
            const SizedBox(height: 10),
            Text('v${AppConstants.versionName} (build ${AppConstants.versionCode})',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    )),
            const Padding(
              padding: EdgeInsets.all(28.0),
              child: Column(
                children: [
                  // Three introduction cards (MASTER TASK)
                  for (final c in introCards) c.animate(delay: const Duration(milliseconds: 300)).scale(duration: const Duration(milliseconds: 500)),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            // Login with the original provider (YouTube) — see LoginScreen
            ElevatedButton.icon(
              icon: const Icon(Icons.shield_outlined),
              label: const Text('Sign in (YouTube Music)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: MiyuColors.accentDark,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () async {
                await Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()));
              },
            ).animate().fadeIn(delay: const Duration(milliseconds: 700)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                // Continue without an account
                Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const HomePage()));
              },
              child: const Text('Continue without an account'),
            ).animate().fadeIn(delay: const Duration(milliseconds: 900)),
          ],
        ),
      ),
    );
  }
}

class SplashCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String description;

  const SplashCard(this.title, this.subtitle, this.description, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MiyuColors.surfaceDark,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
        ],
      ),
    );
  }
}
