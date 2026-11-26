import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/miyu_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/call.dart';
import '../../models/user.dart';
import '../../providers/call_provider.dart';
import '../../providers/calls_history_provider.dart';
import '../../providers/chat_list_provider.dart';
import '../../providers/session_provider.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/miyu_avatar.dart';
import '../../shared/widgets/miyu_dialogs.dart';
import '../../shared/widgets/section_header.dart';

class CallsScreen extends ConsumerStatefulWidget {
  const CallsScreen({super.key});

  @override
  ConsumerState<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends ConsumerState<CallsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(callHistoryProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(callHistoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: MiyuColors.accent,
        backgroundColor: isDark ? MiyuColors.darkSurface : Colors.white,
        onRefresh: () => ref.read(callHistoryProvider.notifier).load(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 110),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recent',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? MiyuColors.darkTextSecondary
                              : MiyuColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text('Calls', style: Theme.of(context).textTheme.headlineLarge),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Start a call',
                  onPressed: _startNewCall,
                  icon: const Icon(Icons.add_ic_call_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (history.loading && history.calls.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 120),
                child: MiyuLoading(message: 'Loading call history'),
              )
            else if (history.error != null && history.calls.isEmpty)
              EmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load calls',
                message: history.error,
                actionLabel: 'Retry',
                onAction: () => ref.read(callHistoryProvider.notifier).load(),
              )
            else if (history.calls.isEmpty)
              const EmptyState(
                icon: Icons.call_outlined,
                title: 'No calls yet',
                message: 'Voice and video calls you make or receive will appear here.',
              )
            else ...[
              const SectionHeader(title: 'History'),
              ...history.calls.map((call) {
                final isMine = ref.watch(currentUserIdProvider) == call.callerId;
                return _CallTile(call: call, outgoing: isMine);
              }),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _startNewCall() async {
    // Reuse the chat list as a quick contact picker.
    final chats = ref.read(chatListProvider).chats.where((chat) => !chat.isGroup && chat.peer != null).toList();
    if (chats.isEmpty) {
      MiyuDialogs.toast(context, 'Start a conversation first to call someone');
      return;
    }
    final userId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (context, controller) => Container(
            decoration: BoxDecoration(
              color: isDark ? MiyuColors.darkElevated : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text('Call someone', style: Theme.of(sheetContext).textTheme.titleLarge),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: chats.length,
                    itemBuilder: (context, index) {
                      final chat = chats[index];
                      return ListTile(
                        leading: MiyuAvatar(
                          name: chat.title,
                          imageUrl: chat.avatarUrl,
                          size: 42,
                          seed: chat.avatarSeed,
                        ),
                        title: Text(chat.title),
                        subtitle: Text('@${chat.peer?.username ?? ''}'),
                        onTap: () => Navigator.of(sheetContext).pop(chat.peer!.id),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (userId == null || !mounted) return;
    final chat = chats.firstWhere((c) => c.peer?.id == userId);
    _showCallTypeSheet(chat.peer!, chat.id);
  }

  Future<void> _showCallTypeSheet(User user, String conversationId) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
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
                SettingsTile(
                  icon: Icons.call_rounded,
                  title: 'Voice call',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _launchCall(user, CallType.voice, conversationId);
                  },
                ),
                SettingsTile(
                  icon: Icons.videocam_rounded,
                  title: 'Video call',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _launchCall(user, CallType.video, conversationId);
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

  Future<void> _launchCall(User user, CallType type, String conversationId) async {
    // CallScreen is pushed automatically by the router watcher.
    await ref.read(callControllerProvider.notifier).startCall(
          peer: user,
          callType: type,
          conversationId: conversationId,
        );
  }
}

class _CallTile extends ConsumerWidget {
  const _CallTile({required this.call, required this.outgoing});

  final CallSession call;
  final bool outgoing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final peer = call.peer;
    final missed = call.isMissed && !outgoing;
    final noAnswer = outgoing && call.status == CallStatus.cancelled;

    String subtitle;
    if (missed) {
      subtitle = 'Missed call';
    } else if (noAnswer) {
      subtitle = 'No answer';
    } else if (call.status == CallStatus.rejected) {
      subtitle = 'Declined';
    } else if (call.duration > 0) {
      subtitle = Formatters.callDurationFromSeconds(call.duration);
    } else {
      subtitle = '${outgoing ? 'Outgoing' : 'Incoming'} call';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isDark ? MiyuColors.darkSurface.withValues(alpha: 0.9) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            if (peer == null) return;
            ref.read(callControllerProvider.notifier).startCall(
                  peer: peer,
                  callType: call.callType,
                  conversationId: call.conversationId,
                );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? MiyuColors.darkBorder : MiyuColors.lightBorder,
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                MiyuAvatar(
                  name: peer?.displayName ?? 'Miyu',
                  imageUrl: peer?.photoURL,
                  size: 46,
                  seed: peer?.id ?? call.id,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        peer?.displayName ?? 'Miyu user',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: missed ? MiyuColors.coral : null,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            missed
                                ? Icons.call_missed_rounded
                                : outgoing
                                    ? Icons.call_made_rounded
                                    : Icons.call_received_rounded,
                            size: 13,
                            color: missed
                                ? MiyuColors.coral
                                : (isDark
                                    ? MiyuColors.darkTextSecondary
                                    : MiyuColors.lightTextSecondary),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${Formatters.chatTimestamp(call.createdAt)} · $subtitle',
                            style: TextStyle(
                              fontSize: 12,
                              color: missed
                                  ? MiyuColors.coral
                                  : (isDark
                                      ? MiyuColors.darkTextSecondary
                                      : MiyuColors.lightTextSecondary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    call.isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                    color: MiyuColors.accent,
                  ),
                  onPressed: peer == null
                      ? null
                      : () {
                          ref.read(callControllerProvider.notifier).startCall(
                                peer: peer,
                                callType: call.callType,
                                conversationId: call.conversationId,
                              );
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
