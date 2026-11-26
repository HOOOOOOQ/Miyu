import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/theme/miyu_colors.dart';
import '../../shared/widgets/miyu_dialogs.dart';
import '../../shared/widgets/miyu_scaffold.dart';
import '../../shared/widgets/section_header.dart';

/// Image caching is handled by CachedNetworkImage, which writes to the app
/// cache directory. This screen measures and clears that footprint.
class StorageScreen extends ConsumerStatefulWidget {
  const StorageScreen({super.key});

  @override
  ConsumerState<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends ConsumerState<StorageScreen> {
  int? _cacheBytes;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _measure();
  }

  Future<int> _directorySize(Directory dir) async {
    if (!await dir.exists()) return 0;
    var total = 0;
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (_) {}
        }
      }
    } catch (_) {}
    return total;
  }

  Future<void> _measure() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final bytes = await _directorySize(cacheDir);
      if (mounted) setState(() => _cacheBytes = bytes);
    } catch (_) {
      if (mounted) setState(() => _cacheBytes = 0);
    }
  }

  Future<void> _clear() async {
    setState(() => _clearing = true);
    try {
      final cacheDir = await getTemporaryDirectory();
      if (await cacheDir.exists()) {
        await for (final entity in cacheDir.list(followLinks: false)) {
          try {
            await entity.delete(recursive: true);
          } catch (_) {}
        }
      }
      await _measure();
      if (mounted) MiyuDialogs.toast(context, 'Cache cleared');
    } catch (_) {
      if (mounted) MiyuDialogs.toast(context, 'Could not clear the cache');
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  String _format(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MiyuScaffold(
      appBar: AppBar(title: const Text('Storage')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: MiyuColors.aurora,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                children: [
                  const Icon(Icons.sd_storage_rounded, color: Colors.white, size: 38),
                  const SizedBox(height: 12),
                  Text(
                    _cacheBytes == null ? 'Calculating…' : _format(_cacheBytes!),
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const Text(
                    'cached photos, videos & files',
                    style: TextStyle(fontSize: 12.5, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SectionHeader(title: 'Manage'),
            Container(
              decoration: BoxDecoration(
                color: isDark ? MiyuColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? MiyuColors.darkBorder : MiyuColors.lightBorder,
                ),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.cleaning_services_rounded),
                    title: const Text('Clear cache'),
                    subtitle: const Text('Media re-downloads when you open it again'),
                    trailing: _clearing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                    onTap: _clearing ? null : _clear,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.refresh_rounded),
                    title: const Text('Recalculate'),
                    onTap: _measure,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Media you send is stored in Miyu\'s cloud media service. Clearing the cache does '
              'not delete anything from your conversations.',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: isDark ? MiyuColors.darkTextSecondary : MiyuColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
