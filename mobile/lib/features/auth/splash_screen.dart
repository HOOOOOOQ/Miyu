import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/miyu_colors.dart';
import '../../providers/session_provider.dart';
import '../../shared/widgets/miyu_logo.dart';
import '../../shared/widgets/miyu_scaffold.dart';

/// Brand splash. The router redirects as soon as session checking resolves,
/// so this screen only shows while `bootstrap()` is in flight.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(sessionProvider.notifier).bootstrap());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MiyuColors.darkBackground,
      body: MiyuBackdrop(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MiyuLogo(size: 96)
                  .animate()
                  .fadeIn(duration: 500.ms, curve: Curves.easeOut)
                  .scale(begin: const Offset(0.86, 0.86), end: const Offset(1, 1), duration: 640.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 24),
              const Text(
                'Miyu',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                  color: Colors.white,
                ),
              )
                  .animate()
                  .fadeIn(delay: 160.ms, duration: 420.ms)
                  .slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic),
              const SizedBox(height: 8),
              Text(
                'conversations, quietly beautiful',
                style: TextStyle(
                  fontSize: 13,
                  letterSpacing: 0.3,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ).animate().fadeIn(delay: 320.ms, duration: 420.ms),
              const SizedBox(height: 52),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ).animate().fadeIn(delay: 500.ms, duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
}
