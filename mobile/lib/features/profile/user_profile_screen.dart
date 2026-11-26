import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/miyu_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/user.dart';
import '../../providers/call_provider.dart';
import '../../providers/chat_list_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/session_provider.dart';
import '../../routing/routes.dart';
import '../../shared/widgets/miyu_avatar.dart';
import '../../shared/widgets/miyu_dialogs.dart';
import '../../shared/widgets/miyu_scaffold.dart';
import '../../shared/widgets/section_header.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  User? _user;
  bool _loading = true;
  bool _blocked = false;
  bool _blockedMe = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await ref.read(chatRepositoryProvider).getUser(widget.userId);
      if (!mounted) return;
      setState(() {
        _user = result.user;
        _blocked = result.iBlockedThem;
        _blockedMe = result.theyBlockedMe;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load this profile';
      });
    }
  }

  Future<void> _message() async {
    final user = _user;
    if (user == null) return;
    try {
      final chat = await ref.read(chatRepositoryProvider).createDirectChat(user.id);
      ref.read(chatListProvider.notifier).upsertChat(chat);
      if (!mounted) return;
      await context.push(MiyuRoutes.chatFor(chat.id));
    } catch (_) {
      if (!mounted) return;
      MiyuDialogs.toast(context, 'Could not start a conversation');
    }
  }

  Future<void> _call(bool video) async {
    final user = _user;
    if (user == null) return;
    await ref
        .read(callControllerProvider.notifier)
        .startCall(peer: user, callType: video ? CallType.video : CallType.voice);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = _user;
    final isMe = user?.id == ref.watch(currentUserIdProvider);

    return MiyuScaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (user != null && !isMe)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (value) async {
                if (value == 'block') {
                  final confirmed = await MiyuDialogs.confirm(
                    context,
                    title: _blocked ? 'Unblock ${user.displayName}?' : 'Block ${user.displayName}?',
                    message: _blocked
                        ? 'You will be able to message each other again.'
                        : 'They will not be able to message or call you.',
                    confirmLabel: _blocked ? 'Unblock' : 'Block',
                    destructive: !_blocked,
                  );
                  if (!confirmed || !mounted) return;
                  try {
                    if (_blocked) {
                      await ref.read(chatRepositoryProvider).unblockUser(user.id);
                    } else {
                      await ref.read(chatRepositoryProvider).blockUser(user.id);
                    }
                    setState(() => _blocked = !_blocked);
                  } catch (_) {
                    if (mounted) MiyuDialogs.toast(context, 'Action failed');
                  }
                } else if (value == 'report') {
                  final reason = await MiyuDialogs.promptText(
                    context,
                    title: 'Report ${user.displayName}',
                    hint: 'Why are you reporting this user?',
                    maxLines: 3,
                    maxLength: 500,
                    confirmLabel: 'Report',
                  );
                  if (reason == null || reason.length < 3 || !mounted) return;
                  try {
                    await ref.read(chatRepositoryProvider).reportUser(user.id, reason);
                    if (mounted) MiyuDialogs.toast(context, 'Report submitted');
                  } catch (_) {
                    if (mounted) MiyuDialogs.toast(context, 'Could not submit the report');
                  }
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'block', child: Text(_blocked ? 'Unblock user' : 'Block user')),
                const PopupMenuItem(value: 'report', child: Text('Report user')),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 30),
                    children: [
                      Center(
                        child: MiyuAvatar(
                          name: user!.displayName,
                          imageUrl: user.photoURL,
                          size: 110,
                          showPresence: user.showOnlineStatus,
                          isOnline: user.isOnline,
                          seed: user.id,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          user.displayName,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '@${user.username}',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? MiyuColors.darkTextSecondary
                                  : MiyuColors.lightTextSecondary,
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            user.isOnline && user.showOnlineStatus
                                ? 'Online'
                                : user.showLastSeen
                                    ? Formatters.lastSeen(user.lastSeen)
                                    : 'Last seen recently',
                            style: TextStyle(
                              fontSize: 12,
                              color: user.isOnline && user.showOnlineStatus
                                  ? MiyuColors.mint
                                  : (isDark
                                      ? MiyuColors.darkTextSecondary
                                      : MiyuColors.lightTextSecondary),
                            ),
                          ),
                        ),
                      ),
                      if (user.bio.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? MiyuColors.darkSurface : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? MiyuColors.darkBorder : MiyuColors.lightBorder,
                            ),
                          ),
                          child: Text(
                            user.bio,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13, height: 1.5),
                          ),
                        ),
                      ],
                      if (_blockedMe) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: MiyuColors.coral.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            'You cannot message this user right now.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: MiyuColors.coral),
                          ),
                        ),
                      ],
                      if (!isMe && !_blocked && !_blockedMe) ...[
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _CircleAction(
                              icon: Icons.chat_bubble_rounded,
                              label: 'Message',
                              onTap: _message,
                            ),
                            const SizedBox(width: 26),
                            _CircleAction(
                              icon: Icons.call_rounded,
                              label: 'Voice',
                              onTap: () => _call(false),
                            ),
                            const SizedBox(width: 26),
                            _CircleAction(
                              icon: Icons.videocam_rounded,
                              label: 'Video',
                              onTap: () => _call(true),
                            ),
                          ],
                        ),
                      ],
                      if (_blocked) ...[
                        const SectionHeader(title: 'Blocked'),
                        TextButton(
                          onPressed: () async {
                            try {
                              await ref.read(chatRepositoryProvider).unblockUser(user.id);
                              setState(() => _blocked = false);
                            } catch (_) {
                              if (mounted) MiyuDialogs.toast(context, 'Could not unblock');
                            }
                          },
                          child: const Text('Unblock ${user.displayName}'),
                        ),
                      ],
                    ],
                  ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: MiyuColors.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: MiyuColors.accent, size: 24),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
