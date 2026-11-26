import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/miyu_colors.dart';

/// Dark aurora backdrop used behind every primary screen.
/// Glass surfaces need something visually rich underneath to read as glass.
class MiyuBackdrop extends StatelessWidget {
  const MiyuBackdrop({super.key, required this.child, this.showGlow = true});

  final Widget child;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: isDark
            ? MiyuColors.darkBackdrop
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF9F8FE), Color(0xFFF3F1FB), Color(0xFFF6F5FA)],
              ),
      ),
      child: Stack(
        children: [
          if (showGlow) ...[
            Positioned(
              top: -140,
              left: -80,
              child: _GlowOrb(
                size: 320,
                color: MiyuColors.accent.withValues(alpha: isDark ? 0.32 : 0.18),
              ),
            ),
            Positioned(
              top: 120,
              right: -120,
              child: _GlowOrb(
                size: 280,
                color: const Color(0xFF5B8DEF).withValues(alpha: isDark ? 0.22 : 0.12),
              ),
            ),
          ],
          child,
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

/// Standard screen shell: backdrop + transparent app bar + padded body.
class MiyuScaffold extends StatelessWidget {
  const MiyuScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
    this.showGlow = true,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? Colors.transparent,
      extendBody: true,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: MiyuBackdrop(showGlow: showGlow, child: body),
    );
  }
}
