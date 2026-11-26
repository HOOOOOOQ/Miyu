import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/miyu_colors.dart';
import '../../models/group.dart';
import '../../models/user.dart';
import '../../providers/chat_list_provider.dart';
import '../../providers/contacts_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/session_provider.dart';
import '../../routing/routes.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/miyu_avatar.dart';
import '../../shared/widgets/miyu_dialogs.dart';
import '../../shared/widgets/miyu_scaffold.dart';
import '../../shared/widgets/section_header.dart';

class GroupInfoScreen extends ConsumerStatefulWidget {
  const GroupInfoScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends ConsumerState<GroupInfoScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final group = await ref.read(groupControllerProvider.notifier).load(widget.groupId);
      if (group != null && mounted) {
        // Fetch full member profiles through the group endpoint.
        await ref.read(groupControllerProvider.notifier).load(widget.groupId);
      }
    });
  }

  Future<void> _addMembers() async {
    final contacts = ref.read(contactsProvider);
    final group = ref.read(groupControllerProvider).value;
    if (group == null) return;
    final candidates = contacts.recentPeers.where((u) => !group.members.contains(u.id)).toList();
    if (candidates.isEmpty) {
      MiyuDialogs.toast(context, 'Everyone you know is already in this group');
      return;
    }
    final selected = <String>{};
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setSheetState) => Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: isDark ? MiyuColors.darkElevated : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                Text('Add members', style: Theme.of(sheetContext).textTheme.titleLarge),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: candidates.length,
                    itemBuilder: (context, index) {
                      final user = candidates[index];
                      return CheckboxListTile(
                        value: selected.contains(user.id),
                        activeColor: MiyuColors.accent,
                        title: Text(user.displayName),
                        subtitle: Text('@${user.username}'),
                        secondary: MiyuAvatar(name: user.displayName, imageUrl: user.photoURL, size: 40, seed: user.id),
                        onChanged: (value) => setSheetState(() {
                          if (value == true) {
                            selected.add(user.id);
                          } else {
                            selected.remove(user.id);
                          }
                        }),
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: selected.isEmpty
                        ? null
                        : () => Navigator.of(sheetContext).pop(true),
                    child: Text(selected.isEmpty ? 'Select people' : 'Add ${selected.length}'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (confirmed != true || !mounted) return;
    final error =
        await ref.read(groupControllerProvider.notifier).addMembers(widget.groupId, selected.toList());
    if (!mounted) return;
    if (error != null) {
      await MiyuDialogs.showError(context, error);
    } else {
      MiyuDialogs.toast(context, 'Members added');
      ref.read(chatListProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupState = ref.watch(groupControllerProvider);
    final currentUserId = ref.watch(currentUserIdProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MiyuScaffold(
      appBar: AppBar(title: const Text('Group info')),
      body: SafeArea(
        child: groupState.when(
          loading: () => const MiyuLoading(message: 'Loading group'),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Text(error.toString(), textAlign: TextAlign.center),
            ),
          ),
          data: (group) {
            if (group == null) return const MiyuLoading();
            final isAdmin = group.isAdmin(currentUserId);
            final canEdit = isAdmin || group.memberPermissions.editGroupInfo;
            final memberProfiles = group.memberProfiles.isNotEmpty
                ? group.memberProfiles
                : group.members.map((id) => User(id: id, displayName: 'Miyu user', username: '')).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
              children: [
                Center(
                  child: Column(
                    children: [
                      MiyuAvatar(
                        name: group.name,
                        imageUrl: group.avatar,
                        size: 96,
                        seed: group.id,
                      ),
                      const SizedBox(height: 14),
                      Text(group.name, style: Theme.of(context).textTheme.headlineMedium),
                      if (group.description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            group.description,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              color: isDark
                                  ? MiyuColors.darkTextSecondary
                                  : MiyuColors.lightTextSecondary,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        '${group.members.length} members',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? MiyuColors.darkTextSecondary
                              : MiyuColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _ActionGrid(
                  onAddMembers: isAdmin || group.memberPermissions.addMembers ? _addMembers : null,
                  onMessage: () => context.go(MiyuRoutes.chatFor(group.conversationId ?? '')),
                  onEdit: canEdit
                      ? () async {
                          final name = await MiyuDialogs.promptText(
                            context,
                            title: 'Group name',
                            initialValue: group.name,
                          );
                          if (name == null || name.isEmpty || !mounted) return;
                          final error = await ref
                              .read(groupControllerProvider.notifier)
                              .update(group.id, {'name': name});
                          if (error != null && mounted) {
                            await MiyuDialogs.showError(context, error);
                          }
                        }
                      : null,
                ),
                const SectionHeader(title: 'Members'),
                ...memberProfiles.map((member) => _MemberTile(
                      group: group,
                      member: member,
                      currentUserId: currentUserId,
                      isAdmin: group.isAdmin(member.id),
                    )),
                const SectionHeader(title: 'Group settings'),
                if (isAdmin) ...[
                  _SwitchTile(
                    title: 'Members can send messages',
                    value: group.memberPermissions.sendMessages,
                    onChanged: (value) => ref
                        .read(groupControllerProvider.notifier)
                        .update(group.id, {
                          'memberPermissions': {'sendMessages': value}
                        }),
                  ),
                  _SwitchTile(
                    title: 'Members can add people',
                    value: group.memberPermissions.addMembers,
                    onChanged: (value) => ref
                        .read(groupControllerProvider.notifier)
                        .update(group.id, {
                          'memberPermissions': {'addMembers': value}
                        }),
                  ),
                  _SwitchTile(
                    title: 'Members can edit group info',
                    value: group.memberPermissions.editGroupInfo,
                    onChanged: (value) => ref
                        .read(groupControllerProvider.notifier)
                        .update(group.id, {
                          'memberPermissions': {'editGroupInfo': value}
                        }),
                  ),
                ],
                const SizedBox(height: 12),
                SettingsTile(
                  icon: Icons.exit_to_app_rounded,
                  title: 'Leave group',
                  destructive: true,
                  onTap: () async {
                    final confirmed = await MiyuDialogs.confirm(
                      context,
                      title: 'Leave group?',
                      message: 'You will stop receiving messages from ${group.name}.',
                      confirmLabel: 'Leave',
                      destructive: true,
                    );
                    if (!confirmed || !mounted) return;
                    final error = await ref.read(groupControllerProvider.notifier).leave(group.id);
                    if (!mounted) return;
                    if (error != null) {
                      await MiyuDialogs.showError(context, error);
                    } else {
                      ref.read(chatListProvider.notifier).removeChat(group.conversationId ?? '');
                      context.go(MiyuRoutes.home);
                    }
                  },
                ),
                if (group.isOwner(currentUserId))
                  SettingsTile(
                    icon: Icons.delete_forever_rounded,
                    title: 'Delete group',
                    destructive: true,
                    onTap: () async {
                      final confirmed = await MiyuDialogs.confirm(
                        context,
                        title: 'Delete group?',
                        message: 'This permanently removes the group and all its messages.',
                        confirmLabel: 'Delete',
                        destructive: true,
                      );
                      if (!confirmed || !mounted) return;
                      final error = await ref.read(groupControllerProvider.notifier).delete(group.id);
                      if (!mounted) return;
                      if (error != null) {
                        await MiyuDialogs.showError(context, error);
                      } else {
                        ref.read(chatListProvider.notifier).removeChat(group.conversationId ?? '');
                        context.go(MiyuRoutes.home);
                      }
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({this.onAddMembers, this.onMessage, this.onEdit});

  final VoidCallback? onAddMembers;
  final VoidCallback? onMessage;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _GridAction(icon: Icons.person_add_alt_1_rounded, label: 'Add', onTap: onAddMembers),
        _GridAction(icon: Icons.chat_bubble_outline_rounded, label: 'Message', onTap: onMessage),
        _GridAction(icon: Icons.edit_rounded, label: 'Rename', onTap: onEdit),
      ],
    );
  }
}

class _GridAction extends StatelessWidget {
  const _GridAction({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: MiyuColors.accent.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: MiyuColors.accent, size: 22),
              ),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({
    required this.group,
    required this.member,
    required this.currentUserId,
    required this.isAdmin,
  });

  final Group group;
  final User member;
  final String? currentUserId;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMe = member.id == currentUserId;
    final iAmAdmin = group.isAdmin(currentUserId);
    final iAmOwner = group.isOwner(currentUserId);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
      leading: MiyuAvatar(
        name: member.displayName,
        imageUrl: member.photoURL,
        size: 42,
        showPresence: true,
        isOnline: member.isOnline,
        seed: member.id,
      ),
      title: Text(
        member.displayName + (isMe ? ' (you)' : ''),
        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        isAdmin ? 'Admin' : (member.username.isEmpty ? 'Member' : '@${member.username}'),
        style: TextStyle(
          fontSize: 12,
          color: isAdmin ? MiyuColors.accent : null,
        ),
      ),
      trailing: (iAmAdmin && !isMe)
          ? PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz_rounded),
              onSelected: (value) async {
                final controller = ref.read(groupControllerProvider.notifier);
                String? error;
                if (value == 'admin') {
                  error = await controller.setAdmin(group.id, member.id, makeAdmin: !isAdmin);
                } else if (value == 'remove') {
                  error = await controller.removeMember(group.id, member.id);
                }
                if (error != null && context.mounted) {
                  await MiyuDialogs.showError(context, error);
                }
              },
              itemBuilder: (context) => [
                if (iAmOwner)
                  PopupMenuItem(
                    value: 'admin',
                    child: Text(isAdmin ? 'Dismiss as admin' : 'Make admin'),
                  ),
                const PopupMenuItem(value: 'remove', child: Text('Remove from group')),
              ],
            )
          : null,
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({required this.title, required this.value, required this.onChanged});

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      value: value,
      activeColor: MiyuColors.accent,
      onChanged: onChanged,
    );
  }
}
