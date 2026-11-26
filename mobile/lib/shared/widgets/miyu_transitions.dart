import 'package:flutter/material.dart';

/// Route builders with the muted, premium transitions Miyu uses.
class MiyuTransitions {
  MiyuTransitions._();

  static Route<T> fadeThrough<T>(Widget page, {Duration duration = const Duration(milliseconds: 320)}) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.035),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  static Route<T> scaleIn<T>(Widget page, {Duration duration = const Duration(milliseconds: 380)}) {
    return PageRouteBuilder<T>(
      opaque: false,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      pageBuilder: (_, __, ___) => page,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: Tween<double>(begin: 0.92, end: 1).animate(curved), child: child),
        );
      },
    );
  }
}
