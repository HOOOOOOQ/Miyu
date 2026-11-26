import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/miyu_colors.dart';
import '../../core/utils/formatters.dart';

class MiyuAvatar extends StatelessWidget {
  const MiyuAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 48,
    this.isOnline = false,
    this.showPresence = false,
    this.seed,
    this.borderRadius,
  });

  final String name;
  final String? imageUrl;
  final double size;
  final bool isOnline;
  final bool showPresence;
  final String? seed;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? size * 0.34;
    final baseColor = MiyuColors.avatarColorFor(seed ?? name);
    final initials = Formatters.initials(name);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [baseColor, baseColor.withValues(alpha: 0.72)],
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl != null && imageUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Center(
                      child: Text(
                        initials,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: size * 0.34,
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Center(
                      child: Text(
                        initials,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: size * 0.34,
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: size * 0.34,
                      ),
                    ),
                  ),
          ),
          if (showPresence && isOnline)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: size * 0.3,
                height: size * 0.3,
                decoration: BoxDecoration(
                  color: MiyuColors.mint,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? MiyuColors.darkBackground
                        : Colors.white,
                    width: 2.2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Stacked avatar preview for group chats.
class MiyuAvatarStack extends StatelessWidget {
  const MiyuAvatarStack({
    super.key,
    required this.names,
    this.imageUrls = const [],
    this.size = 48,
  });

  final List<String> names;
  final List<String?> imageUrls;
  final double size;

  @override
  Widget build(BuildContext context) {
    final count = names.length.clamp(1, 3);
    return SizedBox(
      width: size + (count - 1) * size * 0.36,
      height: size,
      child: Stack(
        children: List.generate(count, (index) {
          final offset = index * size * 0.36;
          return Positioned(
            left: offset,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * 0.34),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? MiyuColors.darkBackground
                      : Colors.white,
                  width: 2,
                ),
              ),
              child: MiyuAvatar(
                name: names[index],
                imageUrl: index < imageUrls.length ? imageUrls[index] : null,
                size: size - 4,
              ),
            ),
          );
        }),
      ),
    );
  }
}
