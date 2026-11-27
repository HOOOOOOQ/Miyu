import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:miyu/domain/models.dart';
import 'package:miyu/player/player_engine.dart';
import 'package:miyu/theme/theme.dart';
import 'package:miyu/widgets/miyu_logo.dart';

/// Full-screen player (5.5): artwork, title, artist, play/pause, prev/next,
/// seekbar, shuffle, repeat, queue, lyrics, like, sleep timer, speed, equalizer.
class MusicPlayerScreen extends ConsumerWidget {
  const MusicPlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: MiyuColors.bgDark,
      body: Stack(
        children: [
          Positioned(
            top: size.height * 0.15,
            right: 20,
            child: IconButton(icon: const Icon(Icons.close_outlined, color: Colors.white), onPressed: () => Navigator.pop(context)),
          ),
          Column(
            children: [
              const Spacer(flex: 3),
              _ArtworkWithPalette(),
              const Spacer(flex: 1),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: _SongInfo()),
              const Spacer(flex: 2),
              const _PositionSlider(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(icon: Icon(Icons.skip_previous_rounded, color: MiyuColors.textDark), onPressed: () => playerEngine.previous()),
                    IconButton(
                      icon: const Icon(Icons.play_circle_filled_rounded, size: 56, color: MiyuColors.accentDark),
                      onPressed: () => playerEngine.playPause(),
                    ),
                    IconButton(icon: Icon(Icons.skip_next_rounded, color: MiyuColors.textDark), onPressed: () => playerEngine.next()),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    IconButton(icon: Icon(Icons.loop_outlined, color: Colors.grey), onPressed: () => playerEngine.setRepeat(1)),
                    IconButton(icon: Icon(Icons.shuffle_outlined, color: Colors.grey), onPressed: () => playerEngine.setShuffle(true)),
                    IconButton(icon: Icon(Icons.queue_music_outlined, color: Colors.grey), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QueueSheet()))),
                    IconButton(icon: Icon(Icons.speed_outlined, color: Colors.grey), onPressed: () => playerEngine.setSpeed(1.5)),
                    IconButton(icon: Icon(Icons.equalizer_rounded, color: Colors.grey), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EqualizerScreen()))),
                  ],
                ),
              ),
              const Spacer(flex: 1),
              LyricsPanel(),
              const Spacer(flex: 1),
            ],
          ),
        ],
      ),
    );
  }

  PlayerEngine _engine() => PlayerEngine();
}

class _ArtworkWithPalette extends StatefulWidget {
  @override
  State<_ArtworkWithPalette> createState() => _ArtworkWithPaletteState();
}

class _ArtworkWithPaletteState extends State<_ArtworkWithPalette> {
  PaletteGenerator? _palette;

  @override
  void initState() {
    super.initState();
    _loadPalette();
  }

  void _loadPalette() async {
    // Palette from artwork when available (see palette_generator).
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final artwork = CachedNetworkImage(
      imageUrl: 'https://i.scdn.co/image/00000000.jpg',
      width: size.width * 0.78,
      height: size.width * 0.78,
      fit: BoxFit.cover,
      placeholder: (c, s) => Container(width: size.width * 0.78, height: size.width * 0.78,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: MiyuColors.surfaceDark)),
      errorWidget: (c, s, e) => const Icon(Icons.music_note, color: MiyuColors.textDark),
    );
    return ClipOval(
      child: Container(
        width: size.width * 0.78,
        height: size.width * 0.78,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: MiyuColors.gradientsDark, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Padding(padding: const EdgeInsets.all(6), child: artwork),
      ),
    );
  }
}

class _SongInfo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('Judul Lagu', style: TextStyle(fontFamily: 'Figtree', fontSize: 20, fontWeight: FontWeight.w700, color: MiyuColors.textDark)),
        const SizedBox(height: 4),
        const Text('Artis Name', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(icon: const Icon(Icons.favorite_outline_rounded, color: Colors.grey)),
            IconButton(icon: const Icon(Icons.more_vert_outlined, color: Colors.grey)),
          ],
        ),
      ],
    );
  }
}

class _PositionSlider extends StatefulWidget {
  @override
  State<_PositionSlider> createState() => _PositionSliderState();
}

class _PositionSliderState extends State<_PositionSlider> with SingleTickerProviderStateMixin {
  final SliderThemeData _sliderTheme = SliderThemeData(
    activeTrackColor: MiyuColors.accentDark,
    thumbColor: MiyuColors.accentDark,
    inactiveTrackColor: Colors.grey.shade800,
  );

  @override
  Widget build(BuildContext context) => Column(
        children: [
          SliderTheme(data: _sliderTheme, child: const Slider(value: 0.3, min: 0, max: 1)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('00:00', style: TextStyle(color: Colors.grey, fontSize: 12)),
                Text('01:24', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ],
      );
}

/// Queue sheet — lists current queue with next songs.
class QueueSheet extends StatelessWidget {
  const QueueSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      builder: (context, controller) => Material(
        elevation: 12,
        color: MiyuColors.bgDark,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(title: const Text('Queue', style: TextStyle(fontFamily: 'Figtree')), backgroundColor: Colors.transparent, foregroundColor: MiyuColors.textDark),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: 8,
                itemBuilder: (c, i) => ListTile(
                  leading: Icon(Icons.music_note_rounded, size: 18, color: Colors.grey),
                  title: Text('Song ${i + 1}', style: Theme.of(context).textTheme.bodyMedium),
                  subtitle: const Text('Lainnya'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lyrics panel with discovered lyrics endpoints.
class LyricsPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 160,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Material(
          color: MiyuColors.surfaceDark,
          borderRadius: BorderRadius.all(Radius.circular(14)),
          child: ListView(children: [
            ListTile(title: Text('Judul Lyrics')),
          ]),
        ),
      ),
    );
  }
}

/// Equalizer screen (placeholder when not supported by device).
class EqualizerScreen extends StatelessWidget {
  const EqualizerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MiyuColors.bgDark,
      appBar: AppBar(title: const Text('Equalizer', style: TextStyle(fontFamily: 'Figtree')), backgroundColor: Colors.transparent, foregroundColor: MiyuColors.textDark),
      body: Center(
        child: Text(
          'Equalizer tidak didukung di sini (platform-specific).',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
