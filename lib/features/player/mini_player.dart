import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:miyu/domain/models.dart';
import 'package:miyu/player/player_engine.dart';
import 'package:just_audio/just_audio.dart';
import 'package:miyu/features/player/player_page.dart';
import 'package:miyu/theme/theme.dart';

/// Mini player — bottom bar on Home/Library (5.5).
class MiniPlayer extends StatelessWidget {
  final PlayerEngine engine;

  const MiniPlayer({super.key, required this.engine});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlayerState>(
      stream: engine.playerStateStream,
      builder: (c, snap) {
        final song = engine.currentSong;
        final title = song?.title ?? 'Lagu';
        final artist = song?.artist ?? '';
        return InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MusicPlayerScreen())),
          child: Container(
            height: 58,
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: song?.artworkUrl != null
                        ? CachedNetworkImage(imageUrl: song!.artworkUrl!, width: 44, height: 44, fit: BoxFit.cover)
                        : const Icon(Icons.music_note_rounded, color: Colors.grey),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(artist, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.play_arrow_rounded, size: 28, color: MiyuColors.accentDark),
                    onPressed: () => engine.playPause(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded, color: Colors.grey),
                    onPressed: () => engine.next(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
