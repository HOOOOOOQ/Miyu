import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';

import '../../core/errors/api_exception.dart';
import '../../core/theme/miyu_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/call.dart';
import '../../models/chat.dart';
import '../../models/message.dart';
import '../../providers/call_provider.dart';
import '../../providers/chat_list_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/message_provider.dart';
import '../../providers/session_provider.dart';
import '../../routing/routes.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/miyu_avatar.dart';
import '../../shared/widgets/miyu_dialogs.dart';
import '../../shared/widgets/miyu_scaffold.dart';
import 'widgets/chat_composer.dart';
import 'widgets/message_bubble.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.chatId, this.highlightMessageId});

  final String chatId;

  /// When opened from a notification, the referenced bubble flashes briefly.
  final String? highlightMessageId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();
  Chat? _chat;
  bool _loadingChat = true;
  String? _chatError;
  bool _recording = false;
  Duration _recordingDuration = Duration.zero;
  StreamSubscription<Duration>? _recordingSub;
  String? _highlightedMessageId;

  @override
  void initState() {
    super.initState();
    ref.read(activeChatIdProvider.notifier).state = widget.chatId;
    _loadChat();
    if (widget.highlightMessageId != null) {
      _highlightedMessageId = widget.highlightMessageId;
      // Clear the flash after the user has had a moment to spot it.
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _highlightedMessageId = null);
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(socketServiceProvider).joinChat(widget.chatId);
      _markRead();
    });
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadChat() async {
    try {
      final chat = await ref.read(chatRepositoryProvider).getChat(widget.chatId);
      if (!mounted) return;
      setState(() {
        _chat = chat;
        _loadingChat = false;
      });
      ref.read(chatListProvider.notifier).upsertChat(chat);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingChat = false;
        _chatError = error is ApiException ? error.friendlyMessage : 'Could not open this conversation.';
      });
    }
  }

  void _markRead() {
    ref.read(chatRepositoryProvider).markRead(widget.chatId).catchError((_) {});
    ref.read(chatListProvider.notifier).clearUnread(widget.chatId);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 80) {
      // List is reversed: reaching max extent means we hit the oldest page.
      ref.read(messageControllerProvider(widget.chatId).notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _recordingSub?.cancel();
    ref.read(activeChatIdProvider.notifier).state = null;
    ref.read(socketServiceProvider).leaveChat(widget.chatId);
    _scrollController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------- media flows
  Future<void> _pickImage() async {
    final media = ref.read(mediaServiceProvider);
    try {
      final uploaded = await media.pickAndUploadImage();
      if (uploaded == null) return;
      await ref.read(messageControllerProvider(widget.chatId).notifier).sendMedia(
            messageType: 'image',
            mediaUrl: uploaded.url,
            mediaMeta: uploaded.toMediaMeta(),
          );
    } catch (error) {
      if (!mounted) return;
      MiyuDialogs.toast(context, error.toString().replaceFirst('ApiException', 'Upload failed'));
    }
  }

  Future<void> _pickVideo() async {
    final media = ref.read(mediaServiceProvider);
    try {
      final uploaded = await media.pickAndUploadVideo();
      if (uploaded == null) return;
      await ref.read(messageControllerProvider(widget.chatId).notifier).sendMedia(
            messageType: 'video',
            mediaUrl: uploaded.url,
            mediaMeta: uploaded.toMediaMeta(),
          );
    } catch (_) {
      if (!mounted) return;
      MiyuDialogs.toast(context, 'Could not upload that video');
    }
  }

  Future<void> _pickDocument() async {
    final media = ref.read(mediaServiceProvider);
    try {
      final uploaded = await media.pickAndUploadDocument();
      if (uploaded == null) return;
      await ref.read(messageControllerProvider(widget.chatId).notifier).sendMedia(
            messageType: 'file',
            mediaUrl: uploaded.url,
            mediaMeta: uploaded.toMediaMeta(),
          );
    } catch (_) {
      if (!mounted) return;
      MiyuDialogs.toast(context, 'Could not upload that file');
    }
  }

  Future<void> _toggleRecording() async {
    final recorder = ref.read(voiceRecorderProvider);
    if (!_recording) {
      final started = await recorder.start();
      if (!started) {
        if (!mounted) return;
        MiyuDialogs.toast(context, 'Microphone permission is required');
        return;
      }
      setState(() {
        _recording = true;
        _recordingDuration = Duration.zero;
      });
      _recordingSub = recorder.ticks.listen((duration) {
        if (mounted) setState(() => _recordingDuration = duration);
      });
    }
  }

  Future<void> _stopRecording({bool cancel = false}) async {
    final recorder = ref.read(voiceRecorderProvider);
    _recordingSub?.cancel();
    final result = await recorder.stop();
    setState(() => _recording = false);
    if (cancel || result == null) return;
    if (result.duration.inSeconds < 1) {
      if (mounted) MiyuDialogs.toast(context, 'Hold longer to record a message');
      return;
    }
    try {
      final uploaded = await ref.read(mediaServiceProvider).uploadVoiceNote(
            result.path,
            durationSeconds: result.duration.inMilliseconds / 1000,
          );
      await ref.read(messageControllerProvider(widget.chatId).notifier).sendMedia(
            messageType: 'audio',
            mediaUrl: uploaded.url,
            mediaMeta: uploaded.toMediaMeta(),
          );
    } catch (_) {
      if (mounted) MiyuDialogs.toast(context, 'Could not upload the voice message');
    }
  }

  // ------------------------------------------------------------ call flows
  Future<void> _startCall(CallType type) async {
    final chat = _chat;
    final peer = chat?.peer;
    if (peer == null) return;
    // Navigation is handled centrally by callRouteWatchProvider.
    await ref.read(callControllerProvider.notifier).startCall(
          peer: peer,
          callType: type,
          conversationId: widget.chatId,
        );
  }

  // ------------------------------------------------------------ reactions
  Future<void> _showMessageActions(Message message) async {
    final controller = ref.read(messageControllerProvider(widget.chatId).notifier);
    final isMine = message.senderId == ref.read(currentUserIdProvider);
    final emojis = ['❤️', '😂', '👍', '🔥', '😮', '🙏'];

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
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!message.isDeleted)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: emojis
                          .map((emoji) => GestureDetector(
                                onTap: () {
                                  Navigator.of(sheetContext).pop();
                                  controller.toggleReaction(message, emoji);
                                },
                                child: Text(emoji, style: const TextStyle(fontSize: 25)),
                              ))
                          .toList(),
                    ),
                  ),
                if (!message.isDeleted) const Divider(height: 1),
                if (!message.isDeleted)
                  _ActionRow(
                    icon: Icons.reply_rounded,
                    label: 'Reply',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      controller.setReplyTo(message);
                    },
                  ),
                if (!message.isDeleted)
                  _ActionRow(
                    icon: Icons.forward_rounded,
                    label: 'Forward',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _showForwardPicker(message);
                    },
                  ),
                if (isMine && !message.isDeleted && message.messageType == MessageType.text)
                  _ActionRow(
                    icon: Icons.edit_rounded,
                    label: 'Edit',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      controller.startEditing(message);
                    },
                  ),
                if (isMine && !message.isDeleted)
                  _ActionRow(
                    icon: Icons.copy_rounded,
                    label: 'Copy text',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      Clipboard.setData(ClipboardData(text: message.content));
                      MiyuDialogs.toast(context, 'Copied');
                    },
                  ),
                if (!message.isDeleted)
                  _ActionRow(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete for me',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      controller.deleteMessage(message, mode: 'me');
                    },
                  ),
                if (isMine && !message.isDeleted)
                  _ActionRow(
                    icon: Icons.delete_forever_rounded,
                    label: 'Delete for everyone',
                    destructive: true,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      controller.deleteMessage(message, mode: 'everyone');
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

  Future<void> _showForwardPicker(Message message) async {
    final chats = ref.read(chatListProvider).chats.where((chat) => chat.id != widget.chatId).toList();
    if (chats.isEmpty) {
      MiyuDialogs.toast(context, 'No other conversations to forward to');
      return;
    }
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          maxChildSize: 0.9,
          minChildSize: 0.35,
          builder: (context, scrollController) => Container(
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
                Text('Forward to', style: Theme.of(sheetContext).textTheme.titleLarge),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
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
                        title: Text(chat.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(chat.isGroup ? 'Group' : '@${chat.peer?.username ?? 'user'}'),
                        onTap: () => Navigator.of(sheetContext).pop(chat.id),
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
    if (selected == null) return;
    final ok = await ref
        .read(messageControllerProvider(widget.chatId).notifier)
        .forward(message, [selected]);
    if (!mounted) return;
    MiyuDialogs.toast(context, ok ? 'Forwarded' : 'Could not forward that message');
  }

  Future<void> _openMedia(Message message) async {
    if (message.mediaUrl == null) return;
    if (message.messageType == MessageType.file) {
      try {
        final dir = Directory.systemTemp;
        final path = '${dir.path}/${message.mediaMeta?.fileName ?? 'miyu-file'}';
        final file = File(path);
        if (!await file.exists()) {
          final client = HttpClient();
          final request = await client.getUrl(Uri.parse(message.mediaUrl!));
          final response = await request.close();
          await response.pipe(file.openWrite());
          client.close();
        }
        await OpenFilex.open(path);
      } catch (_) {
        if (mounted) MiyuDialogs.toast(context, 'Could not open that file');
      }
      return;
    }
    if (message.messageType == MessageType.image) {
      if (!mounted) return;
      await Navigator.of(context).push(
        PageRouteBuilder(
          opaque: false,
          barrierColor: Colors.black,
          pageBuilder: (_, __, ___) => _ImageViewer(url: message.mediaUrl!),
        ),
      );
      return;
    }
    // Video / audio: hand off to the platform player.
    try {
      await OpenFilex.open(message.mediaUrl!);
    } catch (_) {
      if (mounted) MiyuDialogs.toast(context, 'Could not open that media');
    }
  }

  void _scrollToLatest() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(messageControllerProvider(widget.chatId));
    final userId = ref.watch(currentUserIdProvider);

    // Keep the list pinned to the newest message when one arrives.
    ref.listen<ChatRoomState>(messageControllerProvider(widget.chatId), (previous, next) {
      if (previous != null && next.messages.length > previous.messages.length) {
        final lastMessage = next.messages.isEmpty ? null : next.messages.last;
        if (lastMessage?.senderId == userId) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLatest());
        }
        _markRead();
      }
    });

    final chat = _chat;

    // Surface a failed conversation load with a retry instead of an empty shell.
    if (_chatError != null && chat == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_rounded, size: 42, color: MiyuColors.coral.withValues(alpha: 0.9)),
                const SizedBox(height: 14),
                Text(
                  _chatError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14.5, color: MiyuColors.darkTextSecondary),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _chatError = null;
                      _loadingChat = true;
                    });
                    _loadChat();
                  },
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        toolbarHeight: 62,
        leadingWidth: 44,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
          onPressed: () => context.pop(),
        ),
        title: GestureDetector(
          onTap: () {
            if (chat == null) return;
            if (chat.isGroup && chat.group != null) {
              context.push(MiyuRoutes.groupFor(chat.group!.id));
            } else if (chat.peer != null) {
              context.push(MiyuRoutes.userProfileFor(chat.peer!.id));
            }
          },
          child: Row(
            children: [
              MiyuAvatar(
                name: chat?.title ?? (_loadingChat ? 'Loading…' : 'Chat'),
                imageUrl: chat?.avatarUrl,
                size: 40,
                showPresence: chat != null && !chat.isGroup,
                isOnline: chat?.peerIsOnline ?? false,
                seed: chat?.avatarSeed,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      chat?.title ?? 'Loading…',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 1),
                    _PresenceLine(chat: chat, typingUsers: room.typingUsers),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (chat != null && !chat.isGroup) ...[
            IconButton(
              tooltip: 'Voice call',
              icon: const Icon(Icons.call_outlined, size: 23),
              onPressed: () => _startCall(CallType.voice),
            ),
            IconButton(
              tooltip: 'Video call',
              icon: const Icon(Icons.videocam_outlined, size: 24),
              onPressed: () => _startCall(CallType.video),
            ),
          ],
          if (chat != null && chat.isGroup && chat.group != null)
            IconButton(
              tooltip: 'Group info',
              icon: const Icon(Icons.info_outline_rounded, size: 22),
              onPressed: () => context.push(MiyuRoutes.groupFor(chat.group!.id)),
            ),
        ],
      ),
      body: MiyuBackdrop(
        showGlow: false,
        child: Column(
          children: [
            Expanded(
              child: _buildMessageList(room, userId, chat),
            ),
            if (chat != null)
              ChatComposer(
                onSendText: (text) {
                  ref.read(messageControllerProvider(widget.chatId).notifier).sendText(text);
                },
                onPickImage: _pickImage,
                onPickVideo: _pickVideo,
                onPickDocument: _pickDocument,
                onStartTyping: () =>
                    ref.read(messageControllerProvider(widget.chatId).notifier).notifyTyping(),
                onStopTyping: () =>
                    ref.read(messageControllerProvider(widget.chatId).notifier).stopTyping(),
                onMicToggle: _toggleRecording,
                replyTo: room.replyTo,
                editing: room.editingMessage,
                onCancelReply: () =>
                    ref.read(messageControllerProvider(widget.chatId).notifier).setReplyTo(null),
                onCancelEdit: () =>
                    ref.read(messageControllerProvider(widget.chatId).notifier).cancelEditing(),
                isRecording: _recording,
                recordingDuration: _recordingDuration,
                onStopRecording: () => _stopRecording(),
                onCancelRecording: () => _stopRecording(cancel: true),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(ChatRoomState room, String? userId, Chat? chat) {
    if (room.loading) return const MiyuLoading(message: 'Loading messages');
    if (room.error != null && room.messages.isEmpty) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Messages unavailable',
        message: room.error,
        actionLabel: 'Retry',
        onAction: () => ref.read(messageControllerProvider(widget.chatId).notifier).load(),
      );
    }
    if (room.messages.isEmpty) {
      return EmptyState(
        icon: Icons.waving_hand_rounded,
        title: 'Say hello',
        message: chat?.isGroup == true
            ? 'This is the start of the group. Send the first message.'
            : 'This is the beginning of your conversation with ${chat?.title ?? 'them'}.',
      );
    }

    final grouped = _groupByDay(room.messages);

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
      itemCount: grouped.length + (room.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (room.hasMore && index == grouped.length) {
          return room.loadingMore
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : const SizedBox(height: 8);
        }
        final entry = grouped[index];
        if (entry.isDivider) {
          return _DayDivider(label: entry.label ?? '');
        }
        final message = entry.message!;
        final previous = index + 1 < grouped.length ? grouped[index + 1].message : null;
        final showAvatar = message.senderId != userId &&
            (previous == null || previous.senderId != message.senderId);
        final isMine = message.senderId == userId;

        return MessageBubble(
          message: message,
          isMine: isMine,
          currentUserId: userId,
          showAvatar: showAvatar,
          showSenderName: (chat?.isGroup ?? false) && !isMine && showAvatar,
          highlighted: _highlightedMessageId != null && _highlightedMessageId == message.id,
          onLongPress: () => _showMessageActions(message),
          onDoubleTap: () => ref
              .read(messageControllerProvider(widget.chatId).notifier)
              .toggleReaction(message, '❤️'),
          onReactionTap: (emoji) => ref
              .read(messageControllerProvider(widget.chatId).notifier)
              .toggleReaction(message, emoji),
          onRetry: message.sendState == SendState.failed
              ? () => ref
                  .read(messageControllerProvider(widget.chatId).notifier)
                  .retry(message)
              : null,
          onMediaTap: () => _openMedia(message),
        );
      },
    );
  }

  /// Builds a reversed list of day-divider + message entries.
  List<_ListEntry> _groupByDay(List<Message> messages) {
    final entries = <_ListEntry>[];
    String? lastDay;
    for (final message in messages) {
      final created = message.createdAt ?? DateTime.now();
      final dayKey = '${created.year}-${created.month}-${created.day}';
      if (dayKey != lastDay) {
        entries.add(_ListEntry.divider(Formatters.dayDivider(created)));
        lastDay = dayKey;
      }
      entries.add(_ListEntry.message(message));
    }
    return entries.reversed.toList();
  }
}

class _ListEntry {
  const _ListEntry._({this.label, this.message});

  factory _ListEntry.divider(String label) => _ListEntry._(label: label);
  factory _ListEntry.message(Message message) => _ListEntry._(message: message);

  final String? label;
  final Message? message;

  bool get isDivider => label != null;
}

class _DayDivider extends StatelessWidget {
  const _DayDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? MiyuColors.darkSurface.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? MiyuColors.darkTextSecondary : MiyuColors.lightTextSecondary,
          ),
        ),
      ),
    );
  }
}

class _PresenceLine extends StatelessWidget {
  const _PresenceLine({this.chat, this.typingUsers = const {}});

  final Chat? chat;
  final Map<String, String> typingUsers;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String text;
    Color? color;

    if (typingUsers.isNotEmpty) {
      final names = typingUsers.values.toList();
      text = names.length == 1 ? '${names.first} is typing…' : '${names.length} people are typing…';
      color = MiyuColors.accent;
    } else if (chat == null) {
      text = 'Loading';
    } else if (chat!.isGroup) {
      final count = chat!.group?.members.length ?? chat!.participants.length;
      text = '$count members';
    } else {
      final peer = chat!.peer;
      if (peer == null) {
        text = '';
      } else if (peer.isOnline && peer.showOnlineStatus) {
        text = 'Online';
        color = MiyuColors.mint;
      } else if (peer.showLastSeen) {
        text = Formatters.lastSeen(peer.lastSeen);
      } else {
        text = 'Last seen recently';
      }
    }

    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        color: color ?? (isDark ? MiyuColors.darkTextSecondary : MiyuColors.lightTextSecondary),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        size: 21,
        color: destructive ? MiyuColors.coral : MiyuColors.accent,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: destructive ? MiyuColors.coral : null,
        ),
      ),
      onTap: onTap,
    );
  }
}

class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 5,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
            errorBuilder: (_, __, ___) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }
}

/// Public helper used by tests to render a single bubble without a session.
Widget buildBubbleForTest({
  required Message message,
  required String userId,
}) =>
    MessageBubble(
      message: message,
      isMine: message.senderId == userId,
      currentUserId: userId,
      showAvatar: true,
    );
