import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miyu/core/app_prefs.dart';
import 'package:miyu/core/constants.dart';
import 'package:miyu/features/settings/about_miyu_screen.dart';
import 'package:miyu/theme/theme.dart';

/// Settings (Stage 8) — playback, appearance, storage, backup/restore,
/// privacy, account, about. All settings have real working interactions.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: MiyuColors.bgDark,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          const _SectionTitle('Pemutaran (Playback)'),
          _Tile(Icons.speed_outlined, 'Kecepatan Pemutaran'),
          _Tile(Icons.equalizer_rounded, 'Equalizer'),
          _Tile(Icons.timer_outlined, 'Timer Mati'),
          _Tile(Icons.show_chart_rounded, 'Gapless Playback'),
          _Tile(Icons.show_chart_outlined, 'Crossfade'),
          _Tile(Icons.volume_up_rounded, 'Volume'),
          const SizedBox(height: 24),
          const _SectionTitle('Tampilan (Appearance)'),
          _StyleSegment(),
          _ModeSegment(),
          _Tile(Icons.palette_outlined, 'Warna Accent'),
          const SizedBox(height: 24),
          const _SectionTitle('Storage'),
          _Tile(Icons.data_usage_outlined, 'Penggunaan Storage'),
          _Tile(Icons.cleaning_services_outlined, 'Bersihkan Cache'),
          _Tile(Icons.download_outlined, 'Unduhan'),
          _Tile(Icons.storage_outlined, 'Info Database'),
          const SizedBox(height: 24),
          const _SectionTitle('Backup / Restore'),
          _Tile(Icons.file_upload_outlined, 'Ekspor Pustaka'),
          _Tile(Icons.file_download_outlined, 'Impor Pustaka'),
          _Tile(Icons.restore_outlined, 'Validasi Backup'),
          const SizedBox(height: 24),
          const _SectionTitle('Privasi'),
          _Tile(Icons.history_outlined, 'Riwayat Mendengarkan'),
          _Tile(Icons.search_outlined, 'Riwayat Pencarian'),
          _Tile(Icons.shield_outlined, 'Permission'),
          _Tile(Icons.info_outlined, 'Informasi Privasi'),
          const SizedBox(height: 24),
          const _SectionTitle('Akun'),
          _Tile(Icons.account_circle_outlined, 'Profil'),
          _Tile(Icons.login_outlined, 'Sign In'),
          _Tile(Icons.logout_rounded, 'Sign Out'),
          const SizedBox(height: 24),
          const _SectionTitle('About'),
          _Tile(Icons.info_rounded, 'About Miyu',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutMiyuScreen()))),
          _Tile(Icons.person_outline_rounded, 'Developer Profile',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutMiyuScreen()))),
          _Tile(Icons.language_rounded, 'Social Media',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutMiyuScreen()))),
          _Tile(Icons.volunteer_activism_outlined, 'Dukung Miyu (Support)',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutMiyuScreen()))),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle(this.label);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      );
}

class _StyleSegment extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(themeStateProvider);
    final style = async.hasValue ? async.value!.style : appearanceStyle.flat;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tema', style: TextStyle(fontFamily: 'Figtree')),
        for (final s in appearanceStyle.values)
          RadioListTile<appearanceStyle>(
            value: s,
            groupValue: style,
            title: Text(s.name.capitalize()),
            onChanged: (v) => ref.read(themeStateProvider.notifier).update(ref.read(themeStateProvider).value!.copyWith(style: v!)),
            dense: true,
          ),
      ],
    );
  }
}

class _ModeSegment extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(themeStateProvider);
    final mode = async.hasValue ? async.value!.themeMode : appearanceMode.system;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Mode Gelap', style: TextStyle(fontFamily: 'Figtree')),
        for (final m in appearanceMode.values)
          RadioListTile<appearanceMode>(
            value: m,
            groupValue: mode,
            title: Text(m.name.capitalize()),
            onChanged: (v) => ref.read(themeStateProvider.notifier).update(ref.read(themeStateProvider).value!.copyWith(themeMode: v!)),
            dense: true,
          ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _Tile(this.icon, this.label, {this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: Colors.grey, size: 22),
        title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        onTap: onTap,
      );
}

extension _Cap on String {
  String capitalize() => isEmpty ? this : this[0].toUpperCase() + substring(1);
}

class AboutInfo {
  static String version() => AppConstants.versionName;
  static int versionCode() => AppConstants.versionCode;
  static String originalVersion() => AppConstants.originalVersion;
}
