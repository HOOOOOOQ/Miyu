import 'package:flutter/material.dart';

import '../../core/theme/miyu_colors.dart';

class MiyuLoading extends StatelessWidget {
  const MiyuLoading({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation<Color>(MiyuColors.accent),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// Placeholder rows shown while the chat list loads.
class ChatListSkeleton extends StatelessWidget {
  const ChatListSkeleton({super.key, this.rows = 7});

  final int rows;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? MiyuColors.darkElevated : Colors.white;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      itemCount: rows,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          height: 74,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? MiyuColors.darkBorder : MiyuColors.lightBorder,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark ? MiyuColors.darkBorder : MiyuColors.lightElevated,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 12,
                      width: 120 + (index % 3) * 24,
                      decoration: BoxDecoration(
                        color: isDark ? MiyuColors.darkBorder : MiyuColors.lightElevated,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 10,
                      width: 180,
                      decoration: BoxDecoration(
                        color: (isDark ? MiyuColors.darkBorder : MiyuColors.lightElevated)
                            .withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
