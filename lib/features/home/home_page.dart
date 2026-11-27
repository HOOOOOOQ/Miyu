import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miyu/core/app_prefs.dart';
import 'package:miyu/data/local/database.dart';
import 'package:miyu/features/library/library_page.dart';
import 'package:miyu/features/player/mini_player.dart';
import 'package:miyu/features/search/search_page.dart';
import 'package:miyu/theme/theme.dart';
import 'package:miyu/widgets/cover_card.dart';

/// Home screen — MASTER TASK 5.2.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dbAsync = ref.watch(appDatabaseProvider);
    final async = dbAsync.hasValue
        ? dbAsync.value.songs().then((v) => AsyncValue<List<Map<String, dynamic>>>.data(v))
        : const AsyncValue<List<Map<String, dynamic>>>.data([]);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: MiyuColors.textDark,
            centerTitle: false,
            title: const Text('Miyu', style: TextStyle(fontFamily: 'Figtree', fontWeight: FontWeight.w700)),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GreetingText().animate(),
                  const SizedBox(height: 20),
                  const _SectionTitle('Lagu Terbaru Dilihat'),
                  const SizedBox(height: 12),
                  _SongRow(async, context, ref),
                  const SizedBox(height: 28),
                  const _SectionTitle('Lanjutkan Mendengarkan'),
                  const SizedBox(height: 12),
                  _SongRow(async, context, ref),
                  const SizedBox(height: 28),
                  const _SectionTitle('Artis Populer'),
                  const SizedBox(height: 12),
                  _ArtistRow(async, context, ref),
                  const SizedBox(height: 28),
                  const _SectionTitle('Album Terbaru'),
                  const SizedBox(height: 12),
                  _AlbumRow(async, context, ref),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle(this.label);
  @override
  Widget build(BuildContext context) =>
      Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700));
}

class GreetingText extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Text('Halo — Selamat datang di Miyu! 🎵',
        style: Theme.of(context).textTheme.displayMedium?.copyWith(fontFamily: 'Figtree', fontWeight: FontWeight.w600));
  }
}

class _SongRow extends StatelessWidget {
  final AsyncValue<List<Map<String, dynamic>>> async;
  _SongRow(this.async, this.context, this.ref);
  final BuildContext context;
  final WidgetRef ref;

  @override
  Widget build(_) {
    if (async.hasValue) {
      final songs = async.value!.where((s) => s['title'] is String).map((s) => s).take(8).toList();
      if (songs.isEmpty) return const _EmptyState('Belum ada musik');
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: songs.map((s) => CoverCard(title: s['title'] as String? ?? '', coverUrl: s['artworkUrl'] as String?)).toList(),
        ),
      );
    }
    return const _EmptyState('Muat data lokal...');
  }
}

class _ArtistRow extends StatelessWidget {
  _ArtistRow(this.async, this.context, this.ref);
  final AsyncValue<List<Map<String, dynamic>>> async;
  final BuildContext context;
  final WidgetRef ref;
  @override
  Widget build(_) => const _EmptyState('Data artis tidak tersedia');
}

class _AlbumRow extends StatelessWidget {
  _AlbumRow(this.async, this.context, this.ref);
  final AsyncValue<List<Map<String, dynamic>>> async;
  final BuildContext context;
  final WidgetRef ref;
  @override
  Widget build(_) => const _EmptyState('Data album tidak tersedia');
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState(this.message);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
      );
}
