import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/miyu_colors.dart';

/// Floating glass navigation bar — one of the few surfaces that earns blur.
class GlassBottomNav extends StatelessWidget {
  const GlassBottomNav({
    super.key,
    required this.currentIndex,
    required this.onSelect,
    required this.items,
    this.unreadBadge = 0,
    this.callsBadge = 0,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;
  final List<GlassNavItem> items;
  final int unreadBadge;
  final int callsBadge;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 18, bottomInset > 0 ? bottomInset * 0.55 : 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: 66,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.9),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: List.generate(items.length, (index) {
                final item = items[index];
                final selected = index == currentIndex;
                final badge = index == 0 ? unreadBadge : (index == 1 ? callsBadge : 0);
                return Expanded(
                  child: Semantics(
                    label: item.label,
                    selected: selected,
                    button: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => onSelect(index),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                            decoration: BoxDecoration(
                              color: selected
                                  ? MiyuColors.accent.withValues(alpha: isDark ? 0.22 : 0.14)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Badge(
                              isLabelVisible: badge > 0,
                              label: Text(badge > 99 ? '99+' : '$badge'),
                              backgroundColor: MiyuColors.coral,
                              child: Icon(
                                selected ? item.activeIcon : item.icon,
                                size: 23,
                                color: selected
                                    ? (isDark ? Colors.white : MiyuColors.accentDeep)
                                    : (isDark
                                        ? MiyuColors.darkTextSecondary
                                        : MiyuColors.lightTextSecondary),
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                              color: selected
                                  ? (isDark ? Colors.white : MiyuColors.accentDeep)
                                  : (isDark
                                      ? MiyuColors.darkTextSecondary
                                      : MiyuColors.lightTextSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class GlassNavItem {
  const GlassNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}
