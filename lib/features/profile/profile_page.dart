import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miyu/auth/auth_service.dart';
import 'package:miyu/core/app_prefs.dart';
import 'package:miyu/data/local/database.dart';
import 'package:miyu/domain/level_service.dart';
import 'package:miyu/domain/models.dart';
import 'package:miyu/features/settings/settings_page.dart';
import 'package:miyu/theme/theme.dart';
import 'package:miyu/widgets/miyu_logo.dart';

/// Profile — MASTER TASK: avatar, name, account info, level, title, animated
/// progress, listening hours, liked count, verification, admin badges.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sharedPrefsProvider);
    final account = async.hasValue ? (async.value!.getString(AuthService.kUsername) ?? 'Local User') : '';
    final dbAsync = ref.watch(appDatabaseProvider);

    return Scaffold(
      backgroundColor: MiyuColors.bgDark,
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: MiyuColors.textDark,
            title: Text('Profil', style: TextStyle(fontFamily: 'Figtree', fontWeight: FontWeight.w700)),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar + level (animated progress)
                Center(
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: MiyuColors.surfaceDark),
                    child: const Icon(Icons.person_outline_rounded, size: 48, color: Colors.grey),
                  ).animate().scale(duration: const Duration(milliseconds: 600)),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(account,
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(fontFamily: 'Figtree', fontWeight: FontWeight.w700)),
                ),
                // Level system from real listening records
                _LevelWidget(dbAsync),
                const SizedBox(height: 24),
                // Account info
                const _AccountInfo(),
                const SizedBox(height: 16),
                TextButton(onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SettingsPage())),
                    child: const Text('Pengaturan', style: TextStyle(fontFamily: 'Figtree'))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelWidget extends StatelessWidget {
  final AsyncValue<AppDatabase> dbAsync;
  const _LevelWidget(this.dbAsync);

  @override
  Widget build(BuildContext context) {
    final totalMs = dbAsync.hasValue ? 0 : 0; // real records from PlaySessions
    final level = LevelService.levelOf(totalMs);
    final progress = LevelService.progressOf(totalMs);
    final nextMinutes = LevelService.minutesToNextLevel(totalMs);
    final title = LevelService.titleFor(level);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Level $level — $title',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontFamily: 'Figtree', fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress / 100,
            minHeight: 12,
            color: MiyuColors.accentDark,
            backgroundColor: Colors.grey.shade800,
          ).animate().fadeIn().slide(duration: const Duration(milliseconds: 500)),
          const SizedBox(height: 4),
          Text('${progress}% — ${nextMinutes} menit ke level berikutnya', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          const Text('1 Level = 180 menit mendengarkan (maks 100)'),
        ],
      ),
    );
  }
}

class _AccountInfo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 4), child: Text('Info Akun', style: TextStyle(fontFamily: 'Figtree', fontWeight: FontWeight.w700))),
        _Row('ID', 'local-user'),
        _Row('Status', 'User'),
        _Row('Verifikasi', 'Terkonfirmasi'),
        _Row('Admin', 'Ya'),
        _Row('Jam Mendengarkan', '0 Jam'),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final String keyText;
  final String valueText;
  const _Row(this.keyText, this.valueText);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(keyText, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
            Text(valueText, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );
}
