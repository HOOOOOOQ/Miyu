import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miyu/core/app_prefs.dart';
import 'package:miyu/theme/theme.dart';

/// Search — MASTER TASK 5.3: songs, albums, artists, playlists + history.
class SearchPage extends ConsumerWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(sharedPrefsProvider);
    final searchHistory = prefs.hasValue ? (prefs.value?.getStringList('search_history') ?? const <String>[]) : const <String>[];

    return Scaffold(
      backgroundColor: MiyuColors.bgDark,
      body: Column(
        children: [
          const SearchBarWidget(autofocus: true),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                if (searchHistory.isNotEmpty) ...[
                  const _Section('Penelusuran Terakhir'),
                  for (final h in searchHistory.take(8))
                    ListTile(
                      title: Text(h, style: Theme.of(context).textTheme.bodyMedium),
                      leading: const Icon(Icons.history_outlined, size: 18, color: Colors.grey),
                      trailing: IconButton(
                        icon: const Icon(Icons.close_outlined, size: 18, color: Colors.grey),
                        onPressed: () {
                          ref.read(sharedPrefsProvider).value
                              ?.setStringList('search_history', [for (final x in searchHistory) if (x != h) x]);
                        },
                      ),
                    ),
                  ListTile(
                    title: const Text('Hapus riwayat', style: TextStyle(fontFamily: 'Figtree')),
                    leading: const Icon(Icons.delete_sweep_outlined, size: 18, color: Colors.grey),
                    onTap: () => ref.read(sharedPrefsProvider).value?.setStringList('search_history', const []),
                  ),
                ],
                const _Section('Songs'),
                const _SearchRow('lagu tertrend', ['vibe check', 'masih berharap', 'semoga tak sesal']),
                const _Section('Albums'),
                const _SearchRow('album', ['hello - adele', 'handwritten - ed sheeran']),
                const _Section('Artists'),
                const _SearchRow('artis', ['zINA', 'mocca', 'pamor agung']),
                const _Section('Playlists'),
                const _SearchRow('playlist', ['musik durasi', ' Indonesia Sejuta', 'Chill']),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  const _Section(this.label);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      );
}

class _SearchRow extends StatelessWidget {
  final String title;
  final List<String> suggestions;
  const _SearchRow(this.title, this.suggestions);

  @override
  Widget build(BuildContext context) => Column(
        children: suggestions.map((s) => ListTile(title: Text(s), leading: const Icon(Icons.search_outlined, size: 18, color: Colors.grey), onTap: () {})).toList(),
      );
}

class SearchBarWidget extends StatefulWidget {
  final bool autofocus;
  const SearchBarWidget({super.key, this.autofocus = false});

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends ConsumerState<SearchBarWidget> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), () {
        // Debounced live search — requests go through YtMusicService (Stage 2).
        if (mounted) {
          final q = _controller.text;
          if (q.trim().isEmpty) return;
          ref.read(sharedPrefsProvider).value?.setStringList('search_history', [
            q.trim(),
            ...(ref.read(sharedPrefsProvider).value?.getStringList('search_history') ?? const <String>[])
                .where((h) => h != q.trim())
                .take(9),
          ]);
        }
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _controller,
            autofocus: widget.autofocus,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_outlined, color: Colors.grey),
              hintText: 'Cari lagu, album, artis, playlist...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              fillColor: MiyuColors.surfaceDark,
            ),
            onChanged: (v) {
              if (v.trim().isEmpty) {
                // Search history persists
              }
            },
          ),
        ),
      );
}
