import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/miyu_colors.dart';
import '../../core/utils/validators.dart';
import '../../providers/core_providers.dart';
import '../../providers/session_provider.dart';
import '../../shared/widgets/miyu_avatar.dart';
import '../../shared/widgets/miyu_dialogs.dart';
import '../../shared/widgets/miyu_scaffold.dart';
import '../../shared/widgets/section_header.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _saving = false;

  Future<void> _updateProfile(Map<String, dynamic> updates) async {
    setState(() => _saving = true);
    try {
      final updated = await ref.read(chatRepositoryProvider).updateProfile(updates);
      ref.read(sessionProvider.notifier).updateUser(updated);
      if (mounted) MiyuDialogs.toast(context, 'Profile updated');
    } catch (error) {
      if (mounted) {
        await MiyuDialogs.showError(context, error.toString().replaceFirst('ApiException', 'Update failed:'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changeAvatar() async {
    try {
      final media = await ref.read(mediaServiceProvider).pickAndUploadImage();
      if (media == null) return;
      await _updateProfile({'photoURL': media.url});
    } catch (_) {
      if (mounted) MiyuDialogs.toast(context, 'Could not update your photo');
    }
  }

  Future<void> _editField({
    required String title,
    required String label,
    required String initialValue,
    required String field,
    int maxLength = 60,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final messenger = ScaffoldMessenger.of(context);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: maxLength,
          maxLines: maxLines,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    if (validator != null && validator(value) != null) {
      messenger.showSnackBar(SnackBar(content: Text(validator(value)!)));
      return;
    }
    await _updateProfile({field: value});
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null) {
      return const MiyuScaffold(body: Center(child: Text('Not signed in')));
    }

    return MiyuScaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 40),
          children: [
            Center(
              child: Stack(
                children: [
                  MiyuAvatar(
                    name: user.displayName,
                    imageUrl: user.photoURL,
                    size: 108,
                    seed: user.id,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Material(
                      color: MiyuColors.accent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _changeAvatar,
                        child: const SizedBox(
                          width: 34,
                          height: 34,
                          child: Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(user.displayName, style: Theme.of(context).textTheme.headlineMedium),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '@${user.username}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? MiyuColors.darkTextSecondary : MiyuColors.lightTextSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (user.bio.isNotEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Text(
                    user.bio,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: isDark ? MiyuColors.darkTextSecondary : MiyuColors.lightTextSecondary,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 22),
            const SectionHeader(title: 'About you'),
            _Card(
              children: [
                SettingsTile(
                  icon: Icons.badge_outlined,
                  title: 'Display name',
                  subtitle: user.displayName,
                  onTap: () => _editField(
                    title: 'Display name',
                    label: 'How people see you',
                    initialValue: user.displayName,
                    field: 'displayName',
                    validator: Validators.displayName,
                  ),
                ),
                const Divider(height: 1),
                SettingsTile(
                  icon: Icons.alternate_email_rounded,
                  title: 'Username',
                  subtitle: '@${user.username}',
                  onTap: () => _editField(
                    title: 'Username',
                    label: 'Lowercase letters, numbers, . and _',
                    initialValue: user.username,
                    field: 'username',
                    maxLength: 30,
                    validator: Validators.username,
                  ),
                ),
                const Divider(height: 1),
                SettingsTile(
                  icon: Icons.notes_rounded,
                  title: 'Bio',
                  subtitle: user.bio.isEmpty ? 'Say something about yourself' : user.bio,
                  onTap: () => _editField(
                    title: 'Bio',
                    label: 'Up to 200 characters',
                    initialValue: user.bio,
                    field: 'bio',
                    maxLength: 200,
                    maxLines: 3,
                    validator: Validators.bio,
                  ),
                ),
              ],
            ),
            const SectionHeader(title: 'Visibility'),
            _Card(
              children: [
                SwitchListTile(
                  title: const Text('Show online status', style: TextStyle(fontSize: 14.5)),
                  subtitle: const Text('Friends can see when you are active', style: TextStyle(fontSize: 11.5)),
                  value: user.showOnlineStatus,
                  activeColor: MiyuColors.accent,
                  onChanged: (value) => _updateProfile({'showOnlineStatus': value}),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Show last seen', style: TextStyle(fontSize: 14.5)),
                  subtitle: const Text('Turn off to hide your activity time', style: TextStyle(fontSize: 11.5)),
                  value: user.showLastSeen,
                  activeColor: MiyuColors.accent,
                  onChanged: (value) => _updateProfile({'showLastSeen': value}),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Signed in with ${user.email ?? 'Google'}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? MiyuColors.darkTextSecondary : MiyuColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

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
