import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miyu/core/app_prefs.dart';
import 'package:miyu/data/local/database.dart';
import 'package:miyu/features/player/player_page.dart';
import 'package:miyu/theme/theme.dart';

/// Library — MASTER TASK 5.4: liked songs, playlists, downloads, followed
/// artists, recently played, local music, albums. Persisted via Drift.
class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dbAsync = ref.watch(appDatabaseProvider);
    final songsAsync = dbAsync.hasValue
        ? dbAsync.value.songs().then((v) => AsyncValue<List<Map<String, dynamic>>>.data(v))
        : const AsyncValue<List<Map<String, dynamic>>>.data([]);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: MiyuColors.textDark,
            title: Text('Pustaka', style: TextStyle(fontFamily: 'Figtree', fontWeight: FontWeight.w700)),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Title('Lagu Disukai'),
                  _LikedList(songsAsync),
                  const SizedBox(height: 28),
                  const _Title('Unduhan'),
                  const _Section('Semua'),
                  const _Section('Unduh'),
                  const SizedBox(height: 28),
                  const _Title('Artis Terikat'),
                  const _Section('0 Terikat'),
                  const SizedBox(height: 28),
                  const _Title('Terbaru'),
                  const _Section('Dilihat 1'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  final String label;
  const _Title(this.label);
  @override
  Widget build(BuildContext context) =>
      Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700));
}

class _Section extends StatelessWidget {
  final String label;
  const _Section(this.label);
  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        leading: const Icon(Icons.list_outlined, size: 18, color: Colors.grey),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MusicPlayerScreen())),
      );
}

class _LikedList extends StatelessWidget {
  final AsyncValue<List<Map<String, dynamic>>> songs;
  const _LikedList(this.songs);
  @override
  Widget build(BuildContext context) {
    if (!songs.hasValue) return const _Empty('Memuat...');
    final items = songs.value ?? [];
    if (items.isEmpty) return const _Empty('Belum ada lagu disukai');
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (c, i) {
        final s = items[i];
        return ListTile(title: Text(s['title']?.toString() ?? ''), onTap: () {});
      },
    );
  }
}

class _Empty extends StatelessWidget {
  final String message;
  const _Empty(this.message);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
      );
}
