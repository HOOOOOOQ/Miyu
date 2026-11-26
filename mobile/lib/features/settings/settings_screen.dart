import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_config.dart';
import '../../core/theme/miyu_colors.dart';
import '../../providers/session_provider.dart';
import '../../providers/settings_provider.dart';
import '../../routing/routes.dart';
import '../../shared/widgets/miyu_avatar.dart';
import '../../shared/widgets/miyu_dialogs.dart';
import '../../shared/widgets/miyu_scaffold.dart';
import '../../shared/widgets/section_header.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.embedded = false});

  /// When embedded in the home tab we hide the back button.
  final bool embedded;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Future<void> _cycleTheme() async {
    final current = ref.read(themeModeProvider);
    final next = switch (current) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    await ref.read(themeModeProvider.notifier).setThemeMode(next);
    if (!mounted) return;
    final label = switch (next) {
      ThemeMode.system => 'System theme',
      ThemeMode.light => 'Light theme',
      ThemeMode.dark => 'Dark theme',
    };
    MiyuDialogs.toast(context, label);
  }

  String get _themeLabel => switch (ref.watch(themeModeProvider)) {
        ThemeMode.system => 'System',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };

  Future<void> _logout() async {
    final confirmed = await MiyuDialogs.confirm(
      context,
      title: 'Sign out of Miyu?',
      message: 'Your conversations stay safe. You can sign back in with Google anytime.',
      confirmLabel: 'Sign out',
      destructive: true,
    );
    if (!confirmed) return;
    await ref.read(sessionProvider.notifier).signOut();
    if (!mounted) return;
    context.go(MiyuRoutes.onboarding);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = ListView(
      padding: EdgeInsets.fromLTRB(16, widget.embedded ? 14 : 6, 16, widget.embedded ? 110 : 30),
      children: [
        if (widget.embedded)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Preferences',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? MiyuColors.darkTextSecondary : MiyuColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text('Settings', style: Theme.of(context).textTheme.headlineLarge),
              ],
            ),
          ),
        Material(
          color: isDark ? MiyuColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => context.push(MiyuRoutes.profile),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  MiyuAvatar(
                    name: user?.displayName ?? 'Miyu',
                    imageUrl: user?.photoURL,
                    size: 56,
                    seed: user?.id,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? 'Miyu user',
                          style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user == null ? '' : '@${user.username}',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark
                                ? MiyuColors.darkTextSecondary
                                : MiyuColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        ),
        const SectionHeader(title: 'Appearance'),
        _SettingsCard(
          children: [
            SettingsTile(
              icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              title: 'Theme',
              subtitle: _themeLabel,
              onTap: _cycleTheme,
            ),
          ],
        ),
        const SectionHeader(title: 'Notifications & privacy'),
        _SettingsCard(
          children: [
            SettingsTile(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              subtitle: 'Message, call and group alerts',
              onTap: () async {
                final allowed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Message alerts'),
                    content: const Text(
                      'Miyu sends push notifications for new messages and calls. '
                      'You can fine-tune them per chat by long-pressing a conversation.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
                if (allowed == null) return;
              },
            ),
            const Divider(height: 1),
            SettingsTile(
              icon: Icons.block_rounded,
              title: 'Blocked users',
              subtitle: 'People who cannot reach you',
              onTap: () => context.push(MiyuRoutes.blocked),
            ),
            const Divider(height: 1),
            SettingsTile(
              icon: Icons.shield_outlined,
              title: 'Security',
              subtitle: 'Sessions, tokens and device sign-out',
              onTap: () async {
                final confirmed = await MiyuDialogs.confirm(
                  context,
                  title: 'End all sessions?',
                  message: 'You will be signed out everywhere. Sign in again to continue.',
                  confirmLabel: 'End sessions',
                  destructive: true,
                );
                if (confirmed) await _logout();
              },
            ),
          ],
        ),
        const SectionHeader(title: 'Storage'),
        _SettingsCard(
          children: [
            SettingsTile(
              icon: Icons.sd_storage_outlined,
              title: 'Storage management',
              subtitle: 'Cached photos, videos and files',
              onTap: () => context.push(MiyuRoutes.storage),
            ),
          ],
        ),
        const SectionHeader(title: 'About'),
        _SettingsCard(
          children: [
            SettingsTile(
              icon: Icons.info_outline_rounded,
              title: 'About Miyu',
              subtitle: 'Version ${AppConfig.appVersion}',
              onTap: () => context.push(MiyuRoutes.about),
            ),
            const Divider(height: 1),
            SettingsTile(
              icon: Icons.logout_rounded,
              title: 'Sign out',
              destructive: true,
              onTap: _logout,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            'Miyu · crafted with care',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? MiyuColors.darkTextSecondary : MiyuColors.lightTextSecondary,
            ),
          ),
        ),
      ],
    );

    if (widget.embedded) {
      return SafeArea(bottom: false, child: content);
    }
    return MiyuScaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(child: content),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? MiyuColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? MiyuColors.darkBorder : MiyuColors.lightBorder,
          width: 0.8,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(children: children),
      ),
    );
  }
}
