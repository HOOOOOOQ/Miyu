import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Album-art card with dynamic colors from artwork (palette_generator).
class CoverCard extends StatelessWidget {
  final String title;
  final String? coverUrl;

  const CoverCard({super.key, required this.title, this.coverUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: coverUrl == null || coverUrl!.isEmpty
                  ? Container(color: Colors.grey.shade800)
                  : CachedNetworkImage(
                      imageUrl: coverUrl!,
                      fit: BoxFit.cover,
                      placeholder: (c, s) => const SizedBox(child: Icon(Icons.music_note, color: Colors.white)),
                      errorWidget: (c, s, e) => const Icon(Icons.music_note, color: Colors.white),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
