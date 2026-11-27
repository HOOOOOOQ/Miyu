import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:miyu/core/constants.dart';
import 'package:miyu/core/developer_info.dart';
import 'package:miyu/theme/theme.dart';
import 'package:miyu/widgets/miyu_logo.dart';

/// About Miyu — app info, developer profile, social media, support & donation.
/// Navigation: Settings → About Miyu → {About Miyu, Developer Profile, Social Media, Support Miyu}.
class AboutMiyuSection extends StatelessWidget {
  const AboutMiyuSection({super.key});

  static Future<void> openUrl(BuildContext context, String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tidak dapat membuka tautan: $url')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('Tentang Miyu', style: TextStyle(fontFamily: 'Figtree', fontWeight: FontWeight.w800, fontSize: 20)),
        ),
        _AboutInfoCard(),
        const SizedBox(height: 24),
        const _DeveloperProfileCard(),
        const SizedBox(height: 24),
        const _SocialMediaSection(),
        const SizedBox(height: 24),
        const SupportMiyuSection(),
      ],
    );
  }
}

/// A. About Miyu — logo, name, version, versionCode, build info, description, copyright.
class _AboutInfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 0,
      color: isDark ? MiyuColors.surfaceDark : MiyuColors.surfaceLight,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const MiyuLogo(size: 48),
                const SizedBox(width: 12),
                Text(AboutMiyu.name,
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(fontFamily: 'Figtree', fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 16),
            _InfoRow('Versi', AppConstants.versionName),
            _InfoRow('Version Code', AppConstants.versionCode.toString()),
            _InfoRow('Build', _buildInfo()),
            _InfoRow('Deskripsi', AboutMiyu.description),
            _InfoRow('Copyright', AboutMiyu.copyright),
          ],
        ),
      ),
    );
  }

  String _buildInfo() {
    // Build information — kDebugMode and package name (real values, not fake).
    final mode = kDebugMode ? 'debug' : 'release';
    return '$mode — ${AppConstants.applicationId}';
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
            ),
            Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyMedium)),
          ],
        ),
      );
}

/// B. Developer Profile — PallxXx + social links (exact strings from user).
class _DeveloperProfileCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 0,
      color: isDark ? MiyuColors.surfaceDark : MiyuColors.surfaceLight,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pengembang', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.person_outline_rounded, size: 18, color: MiyuColors.accentDark),
                const SizedBox(width: 6),
                Text(DeveloperInfo.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            Text('Independent Application Developer',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
            const SizedBox(height: 14),
            // Telegram
            _LinkRow('Telegram', Icons.telegram, DeveloperInfo.telegram),
            const SizedBox(height: 8),
            // TikTok
            _LinkRow('TikTok', Icons.tiktok, DeveloperInfo.tiktok),
            const SizedBox(height: 8),
            // Saweria
            _LinkRow('Saweria', Icons.volunteer_activism_outlined, DeveloperInfo.saweria),
          ],
        ),
      ),
    );
  }

  Widget _LinkRow(String label, IconData icon, String url) {
    return ListTile(
      leading: Icon(icon, color: MiyuColors.accentDark),
      title: Text(label, style: const TextStyle(fontFamily: 'Figtree', fontWeight: FontWeight.w600)),
      subtitle: Text(url, style: const TextStyle(fontFamily: 'Figtree', fontSize: 12, color: Colors.grey)),
      trailing: const Icon(Icons.open_in_new_outlined, size: 18, color: Colors.grey),
      onTap: () => AboutMiyuSection.openUrl(_of(), url),
    ).animate().fadeIn(duration: const Duration(milliseconds: 400));
  }

  BuildContext _of() => context;
}

/// C. Social Media section.
class _SocialMediaSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Media Sosial', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _SocialRow('Telegram', Icons.telegram, DeveloperInfo.telegram),
            const SizedBox(height: 6),
            _SocialRow('TikTok', Icons.tiktok, DeveloperInfo.tiktok),
            const SizedBox(height: 6),
            _SocialRow('Saweria', Icons.volunteer_activism_outlined, DeveloperInfo.saweria),
          ],
        ),
      );

  Widget _SocialRow(String label, IconData icon, String url) {
    return ListTile(
      leading: Icon(icon, color: MiyuColors.accentDark),
      title: Text(label),
      trailing: const Icon(Icons.open_in_new_outlined),
      onTap: () => AboutMiyuSection.openUrl(context, url),
    );
  }
}

/// C2. Support Miyu — Saweria card + QRIS Coming Soon.
class SupportMiyuSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dukung Miyu 🌱', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'Dukung pengembang Miyu kami — donasi bersifat sukarela dan tidak wajib.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          // Saweria support card + button
          Card(
            elevation: 2,
            margin: EdgeInsets.zero,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => AboutMiyuSection.openUrl(context, DeveloperInfo.saweria),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0x33FFFFFF) : const Color(0x12000000),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.volunteer_activism_rounded, size: 20, color: MiyuColors.accentDark),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('Saweria',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontFamily: 'Figtree', fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(DeveloperInfo.saweria, style: const TextStyle(fontFamily: 'Figtree', fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: MiyuColors.accentDark,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => AboutMiyuSection.openUrl(context, DeveloperInfo.saweria),
                          child: const Text('Donasikan di Saweria'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // QRIS — Coming Soon label
          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('QRIS'),
                  Text(DeveloperInfo.qris, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
