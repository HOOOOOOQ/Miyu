import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../core/theme/miyu_colors.dart';
import '../../providers/session_provider.dart';
import '../../shared/widgets/glass_panel.dart';
import '../../shared/widgets/miyu_dialogs.dart';
import '../../shared/widgets/miyu_logo.dart';
import '../../shared/widgets/miyu_scaffold.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  static const _slides = [
    _SlideData(
      icon: Icons.chat_bubble_rounded,
      title: 'Conversations that flow',
      body: 'Real-time messaging with voice notes, photos, videos and files — '
          'all wrapped in a calm, glassy interface.',
    ),
    _SlideData(
      icon: Icons.videocam_rounded,
      title: 'Calls, crystal clear',
      body: 'One-tap voice and video calls powered by WebRTC, with automatic '
          'fallback through a TURN relay when networks get strict.',
    ),
    _SlideData(
      icon: Icons.groups_rounded,
      title: 'Together, beautifully',
      body: 'Group chats with admin tools, read receipts, reactions and pinning. '
          'Sign in once with Google and you are ready.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _continueWithGoogle() async {
    final success = await ref.read(sessionProvider.notifier).signInWithGoogle();
    if (!mounted) return;
    if (!success) {
      final error = ref.read(sessionProvider).error;
      if (error != null && error.isNotEmpty) {
        await MiyuDialogs.showError(context, error);
        ref.read(sessionProvider.notifier).clearError();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final busy = session.isRestoring;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MiyuScaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            children: [
              Row(
                children: [
                  const MiyuLogo(size: 40),
                  const SizedBox(width: 12),
                  const Text(
                    'Miyu',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.6),
                  ),
                  const Spacer(),
                  if (_page < _slides.length - 1)
                    TextButton(
                      onPressed: () => _pageController.animateToPage(
                        _slides.length - 1,
                        duration: const Duration(milliseconds: 420),
                        curve: Curves.easeOutCubic,
                      ),
                      child: const Text('Skip'),
                    ),
                ],
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) => setState(() => _page = index),
                  itemCount: _slides.length,
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GlassPanel(
                          padding: const EdgeInsets.all(34),
                          borderRadius: 36,
                          child: Icon(slide.icon, size: 64, color: MiyuColors.accentSoft),
                        )
                            .animate()
                            .fadeIn(duration: 420.ms)
                            .scale(begin: const Offset(0.9, 0.9), duration: 520.ms, curve: Curves.easeOutBack),
                        const SizedBox(height: 44),
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ).animate().fadeIn(delay: 120.ms, duration: 380.ms).slideY(begin: 0.18),
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            slide.body,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: isDark
                                      ? MiyuColors.darkTextSecondary
                                      : MiyuColors.lightTextSecondary,
                                  height: 1.5,
                                ),
                          ),
                        ).animate().fadeIn(delay: 220.ms, duration: 380.ms),
                      ],
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_slides.length, (index) {
                  final active = index == _page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 26 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active ? MiyuColors.accent : MiyuColors.accent.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 28),
              _GoogleButton(
                busy: busy,
                onPressed: busy ? null : _continueWithGoogle,
              ).animate().fadeIn(delay: 260.ms, duration: 400.ms),
              const SizedBox(height: 16),
              Text(
                'By continuing you agree to Miyu\'s terms. '
                'Your Google photo and name are used for your profile.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.45,
                  color: isDark ? MiyuColors.darkTextSecondary : MiyuColors.lightTextSecondary,
                ),
              ),
              if (AppConfig.isDev)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'dev · ${AppConfig.normalizedApiBaseUrl}',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: (isDark ? MiyuColors.darkTextSecondary : MiyuColors.lightTextSecondary)
                          .withValues(alpha: 0.7),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideData {
  const _SlideData({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1F1F1F),
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(MiyuColors.accentDeep),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomPaint(size: const Size(22, 22), painter: _GoogleLogoPainter()),
                  const SizedBox(width: 12),
                  const Text(
                    'Continue with Google',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.1),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Minimal Google "G" mark, drawn to avoid shipping a trademark asset.
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final strokeWidth = size.width * 0.22;
    final colors = [
      const Color(0xFF4285F4),
      const Color(0xFF34A853),
      const Color(0xFFFBBC05),
      const Color(0xFFEA4335),
    ];
    final startAngles = [-0.3, 0.9, 2.1, 3.5];
    for (var i = 0; i < 4; i++) {
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect.deflate(strokeWidth / 2), startAngles[i], 1.35, false, paint);
    }
    // Blue bar of the G
    final bar = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.52, size.height * 0.42, size.width * 0.46, strokeWidth * 0.9),
      bar,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
