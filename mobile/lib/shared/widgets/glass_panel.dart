import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/miyu_colors.dart';

/// The signature Miyu surface: translucent fill, thin border, soft blur.
/// Use sparingly — bottom bars, call sheets, dialogs, floating controls.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 24,
    this.blur = 22,
    this.opacity = 0.55,
    this.borderOpacity = 0.35,
    this.margin,
    this.onTap,
    this.showShadow = true,
    this.width,
    this.height,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blur;
  final double opacity;
  final double borderOpacity;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final bool showShadow;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark
        ? Colors.white.withValues(alpha: opacity * 0.13)
        : Colors.white.withValues(alpha: opacity);
    final border = isDark
        ? Colors.white.withValues(alpha: borderOpacity * 0.32)
        : Colors.white.withValues(alpha: 0.9);

    final radius = BorderRadius.circular(borderRadius);
    final content = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: radius,
            color: fill,
            border: Border.all(color: border, width: 0.8),
            boxShadow: showShadow
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ]
                : null,
          ),
          child: child,
        ),
      ),
    );

    if (onTap == null) {
      return Padding(padding: margin ?? EdgeInsets.zero, child: content);
    }
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: content,
        ),
      ),
    );
  }
}

/// Solid card variant for list rows where blur would be excessive.
class SolidCard extends StatelessWidget {
  const SolidCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.borderRadius = 20,
    this.onTap,
    this.color,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final VoidCallback? onTap;
  final Color? color;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = color ?? (isDark ? MiyuColors.darkSurface : Colors.white);
    final radius = BorderRadius.circular(borderRadius);
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Material(
        color: base,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: isDark ? MiyuColors.darkBorder : MiyuColors.lightBorder,
                width: 0.8,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
