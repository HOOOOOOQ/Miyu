import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/miyu_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/chat.dart';
import '../../models/message.dart';
import '../../providers/chat_list_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/session_provider.dart';
import '../../routing/routes.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/miyu_avatar.dart';
import '../../shared/widgets/miyu_dialogs.dart';
import '../../shared/widgets/responsive.dart';
import '../../shared/widgets/section_header.dart';

class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  final _searchController = TextEditingController();
  bool _searchOpen = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatListProvider);
    final user = ref.watch(currentUserProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chats = state.visibleChats;

    return SafeArea(
      bottom: false,
      child: ResponsiveBody(
        child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _greeting(),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                          color: isDark ? MiyuColors.darkTextSecondary : MiyuColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        state.showArchived ? 'Archived' : 'Chats',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                    ],
                  ),
                ),
                if (state.archivedCount > 0)
                  IconButton(
                    tooltip: state.showArchived ? 'Back to chats' : 'Archived chats',
                    onPressed: () => ref.read(chatListProvider.notifier).toggleArchived(),
                    icon: Icon(
                      state.showArchived ? Icons.unarchive_outlined : Icons.inventory_2_outlined,
                    ),
                  ),
                IconButton(
                  tooltip: 'Search',
                  onPressed: () => setState(() => _searchOpen = !_searchOpen),
                  icon: Icon(_searchOpen ? Icons.close_rounded : Icons.search_rounded),
                ),
                const SizedBox(width: 2),
                MiyuAvatar(
                  name: user?.displayName ?? 'Miyu',
                  imageUrl: user?.photoURL,
                  size: 40,
                  showPresence: true,
                  isOnline: true,
                  seed: user?.id,
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            child: _searchOpen
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      onChanged: (value) => ref.read(chatListProvider.notifier).setSearchQuery(value),
                      decoration: InputDecoration(
                        hintText: 'Search conversations',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  ref.read(chatListProvider.notifier).setSearchQuery('');
                                  setState(() {});
                                },
                              ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: state.loading && state.chats.isEmpty
                ? const ChatListSkeleton()
                : RefreshIndicator(
                    color: MiyuColors.accent,
                    backgroundColor: isDark ? MiyuColors.darkSurface : Colors.white,
                    onRefresh: () => ref.read(chatListProvider.notifier).refresh(),
                    child: chats.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(height: MediaQuery.of(context).size.height * 0.08),
                              EmptyState(
                                icon: state.showArchived
                                    ? Icons.inventory_2_outlined
                                    : Icons.forum_outlined,
                                title: state.showArchived ? 'Nothing archived' : 'No conversations yet',
                                message: state.showArchived
                                    ? 'Archive a chat from its long-press menu to tuck it away here.'
                                    : 'Start a conversation with the button below, or find friends in Contacts.',
                                actionLabel: state.showArchived ? null : 'New chat',
                                onAction: state.showArchived
                                    ? null
                                    : () => context.push(MiyuRoutes.newChat),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(14, 4, 14, 108),
                            itemCount: chats.length + (state.error != null ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (state.error != null && index == 0) {
                                return _ErrorBanner(message: state.error!);
                              }
                              final chat = chats[index - (state.error != null ? 1 : 0)];
                              return _ChatTile(chat: chat, index: index);
                            },
                          ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 104),
            child: Align(
              alignment: Alignment.centerRight,
              child: _NewChatFab(onPressed: () => context.push(MiyuRoutes.newChat)),
            ),
          ),
        ],
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'Late night';
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }
}

class _NewChatFab extends StatelessWidget {
  const _NewChatFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Start a new chat',
      child: Material(
        color: MiyuColors.accent,
        shape: const CircleBorder(),
        elevation: 10,
        shadowColor: MiyuColors.accent.withValues(alpha: 0.5),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: const SizedBox(
            width: 58,
            height: 58,
            child: Icon(Icons.add_comment_rounded, color: Colors.white, size: 25),
          ),
        ),
      ),
    );
  }
}

class _ChatTile extends ConsumerWidget {
  const _ChatTile({required this.chat, required this.index});

  final Chat chat;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userId = ref.watch(currentUserIdProvider);
    final last = chat.lastMessage;
    
    String preview;
    if (last == null) {
      preview = chat.isGroup ? 'Group created — say hello' : 'Say hello to ${chat.title}';
    } else if (last.isDeleted) {
      preview = 'Message deleted';
    } else if (last.messageType == MessageType.system) {
      preview = last.content;
    } else {
      switch (last.messageType) {
        case MessageType.image:
          preview = '📷 Photo';
          break;
        case MessageType.video:
          preview = '🎬 Video';
          break;
        case MessageType.audio:
          preview = '🎙️ Voice message';
          break;
        case MessageType.file:
          preview = '📎 ${last.mediaMeta?.fileName ?? 'Document'}';
          break;
        default:
          preview = last.content;
      }
    }

    final isMine = last?.senderId == userId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isDark ? MiyuColors.darkSurface.withValues(alpha: 0.86) : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            ref.read(activeChatIdProvider.notifier).state = chat.id;
            await context.push(MiyuRoutes.chatFor(chat.id));
            ref.read(activeChatIdProvider.notifier).state = null;
          },
          onLongPress: () => _showMenu(context, ref),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? (chat.unreadCount > 0
                        ? MiyuColors.accent.withValues(alpha: 0.35)
                        : MiyuColors.darkBorder)
                    : MiyuColors.lightBorder,
              ),
            ),
            child: Row(
              children: [
                MiyuAvatar(
                  name: chat.title,
                  imageUrl: chat.avatarUrl,
                  size: 52,
                  isOnline: chat.peerIsOnline,
                  showPresence: !chat.isGroup,
                  seed: chat.avatarSeed,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (chat.isGroup)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(
                                Icons.groups_rounded,
                                size: 15,
                                color: isDark
                                    ? MiyuColors.darkTextSecondary
                                    : MiyuColors.lightTextSecondary,
                              ),
                            ),
                          Flexible(
                            child: Text(
                              chat.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: chat.unreadCount > 0 ? FontWeight.w800 : FontWeight.w600,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          if (chat.pinned)
                            const Padding(
                              padding: EdgeInsets.only(left: 5),
                              child: Icon(Icons.push_pin_rounded, size: 13, color: MiyuColors.accent),
                            ),
                          if (chat.muted)
                            Padding(
                              padding: const EdgeInsets.only(left: 5),
                              child: Icon(
                                Icons.notifications_off_rounded,
                                size: 13,
                                color: isDark
                                    ? MiyuColors.darkTextSecondary
                                    : MiyuColors.lightTextSecondary,
                              ),
                            ),
                          const SizedBox(width: 8),
                          Text(
                            Formatters.chatTimestamp(chat.lastActivity),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: chat.unreadCount > 0 ? FontWeight.w700 : FontWeight.w500,
                              color: chat.unreadCount > 0
                                  ? MiyuColors.accent
                                  : (isDark
                                      ? MiyuColors.darkTextSecondary
                                      : MiyuColors.lightTextSecondary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (isMine && last != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(
                                Icons.done_all_rounded,
                                size: 15,
                                color: last.readBy.any((id) => id != userId)
                                    ? MiyuColors.accent
                                    : (isDark
                                        ? MiyuColors.darkTextSecondary
                                        : MiyuColors.lightTextSecondary),
                              ),
                            ),
                          Expanded(
                            child: Text(
                              preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.2,
                                height: 1.3,
                                fontWeight: chat.unreadCount > 0 ? FontWeight.w600 : FontWeight.w400,
                                color: chat.unreadCount > 0
                                    ? (isDark ? Colors.white : Colors.black87)
                                    : (isDark
                                        ? MiyuColors.darkTextSecondary
                                        : MiyuColors.lightTextSecondary),
                              ),
                            ),
                          ),
                          if (chat.unreadCount > 0)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              constraints: const BoxConstraints(minWidth: 20),
                              decoration: BoxDecoration(
                                gradient: MiyuColors.aurora,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                chat.unreadCount > 99 ? '99+' : '${chat.unreadCount}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 260.ms, delay: (index.clamp(0, 8) * 28).ms).slideX(begin: 0.03);
  }

  Future<void> _showMenu(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(chatListProvider.notifier);
    final repository = ref.read(chatRepositoryProvider);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? MiyuColors.darkElevated : Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      MiyuAvatar(name: chat.title, imageUrl: chat.avatarUrl, size: 38, seed: chat.avatarSeed),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          chat.title,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                SettingsTile(
                  icon: chat.pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                  title: chat.pinned ? 'Unpin conversation' : 'Pin conversation',
                  onTap: () async {
                    Navigator.of(context).pop();
                    notifier.setPinnedLocal(chat.id, !chat.pinned);
                    try {
                      await repository.setPinned(chat.id, !chat.pinned);
                    } catch (_) {
                      notifier.setPinnedLocal(chat.id, chat.pinned);
                    }
                  },
                ),
                SettingsTile(
                  icon: chat.muted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                  title: chat.muted ? 'Unmute notifications' : 'Mute notifications',
                  onTap: () async {
                    Navigator.of(context).pop();
                    notifier.setMutedLocal(chat.id, !chat.muted);
                    try {
                      await repository.setMuted(chat.id, !chat.muted);
                    } catch (_) {
                      notifier.setMutedLocal(chat.id, chat.muted);
                    }
                  },
                ),
                SettingsTile(
                  icon: chat.archived ? Icons.unarchive_outlined : Icons.archive_outlined,
                  title: chat.archived ? 'Unarchive' : 'Archive',
                  onTap: () async {
                    Navigator.of(context).pop();
                    notifier.setArchivedLocal(chat.id, !chat.archived);
                    try {
                      await repository.setArchived(chat.id, !chat.archived);
                    } catch (_) {
                      notifier.setArchivedLocal(chat.id, chat.archived);
                    }
                  },
                ),
                if (!chat.isGroup)
                  SettingsTile(
                    icon: Icons.delete_outline_rounded,
                    title: 'Delete conversation',
                    destructive: true,
                    onTap: () async {
                      Navigator.of(context).pop();
                      final confirmed = await MiyuDialogs.confirm(
                        context,
                        title: 'Delete conversation?',
                        message: 'This removes the conversation and its messages for both of you.',
                        confirmLabel: 'Delete',
                        destructive: true,
                      );
                      if (!confirmed) return;
                      notifier.removeChat(chat.id);
                      try {
                        await repository.deleteChat(chat.id);
                      } catch (_) {
                        notifier.load(silent: true);
                      }
                    },
                  ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MiyuColors.coral.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MiyuColors.coral.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: MiyuColors.coral, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12.5, color: MiyuColors.coral, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
