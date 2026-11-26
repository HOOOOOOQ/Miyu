import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/errors/api_exception.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../services/socket_service.dart';
import 'chat_list_provider.dart';
import 'core_providers.dart';
import 'session_provider.dart';

class ChatRoomState {
  const ChatRoomState({
    this.messages = const [],
    this.loading = true,
    this.loadingMore = false,
    this.hasMore = false,
    this.nextCursor,
    this.error,
    this.typingUsers = const {},
    this.replyTo,
    this.editingMessage,
  });

  /// Oldest → newest. Local pending messages appear at the end.
  final List<Message> messages;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final String? nextCursor;
  final String? error;
  final Map<String, String> typingUsers; // userId → displayName
  final Message? replyTo;
  final Message? editingMessage;

  bool get isTyping => typingUsers.isNotEmpty;

  ChatRoomState copyWith({
    List<Message>? messages,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    String? nextCursor,
    String? error,
    bool clearError = false,
    Map<String, String>? typingUsers,
    Message? replyTo,
    Message? editingMessage,
    bool clearReply = false,
    bool clearEditing = false,
  }) {
    return ChatRoomState(
      messages: messages ?? this.messages,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor ?? this.nextCursor,
      error: clearError ? null : (error ?? this.error),
      typingUsers: typingUsers ?? this.typingUsers,
      replyTo: clearReply ? null : (replyTo ?? this.replyTo),
      editingMessage: clearEditing ? null : (editingMessage ?? this.editingMessage),
    );
  }
}

class MessageController extends StateNotifier<ChatRoomState> {
  MessageController({
    required this.chatId,
    required Ref ref,
    required this.currentUser,
  })  : _ref = ref,
        super(const ChatRoomState());

  final String chatId;
  final Ref _ref;
  final User? currentUser;

  final _uuid = const Uuid();
  Timer? _typingStopTimer;
  bool _typingSent = false;

  String get _userId => currentUser?.id ?? '';

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final result = await _ref.read(chatRepositoryProvider).listMessages(chatId);
      state = state.copyWith(
        messages: result.messages,
        loading: false,
        hasMore: result.hasMore,
        nextCursor: result.nextCursor,
        clearError: true,
      );
    } on ApiException catch (error) {
      state = state.copyWith(loading: false, error: error.friendlyMessage);
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore) return;
    state = state.copyWith(loadingMore: true);
    try {
      final result = await _ref
          .read(chatRepositoryProvider)
          .listMessages(chatId, cursor: state.nextCursor);
      state = state.copyWith(
        messages: [...result.messages, ...state.messages],
        loadingMore: false,
        hasMore: result.hasMore,
        nextCursor: result.nextCursor,
      );
    } on ApiException catch (error) {
      state = state.copyWith(loadingMore: false, error: error.friendlyMessage);
    }
  }

  // ------------------------------------------------------------- sending
  Future<void> _send({
    required String messageType,
    String content = '',
    String? mediaUrl,
    Map<String, dynamic>? mediaMeta,
    String? localFileUri,
  }) async {
    final user = currentUser;
    if (user == null) return;
    final clientId = _uuid.v4();
    final replyTarget = state.replyTo;

    final optimistic = Message(
      id: 'local-$clientId',
      conversationId: chatId,
      senderId: user.id,
      messageType: messageTypeFromString(messageType),
      content: content,
      mediaUrl: mediaUrl,
      mediaMeta: mediaMeta == null ? null : MediaMeta.fromJson(mediaMeta),
      clientMessageId: clientId,
      replyToId: replyTarget?.id,
      replyToPreview: replyTarget,
      createdAt: DateTime.now(),
      sender: user,
      sendState: SendState.sending,
      localFileUri: localFileUri,
    );
    state = state.copyWith(
      messages: [...state.messages, optimistic],
      clearReply: true,
      clearEditing: true,
    );

    final socket = _ref.read(socketServiceProvider);
    final payload = <String, dynamic>{
      'conversationId': chatId,
      'clientMessageId': clientId,
      'messageType': messageType,
      'content': content,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
      if (mediaMeta != null) 'mediaMeta': mediaMeta,
      if (replyTarget != null) 'replyTo': replyTarget.id,
    };

    Map<String, dynamic>? ack;
    if (socket.isConnected) {
      ack = await socket.emitWithAck(SocketEvents.messageSend, payload);
    }
    if (ack != null && ack['ok'] == true && ack['message'] is Map) {
      _confirmOptimistic(clientId, Message.fromJson(ack['message'] as Map<String, dynamic>));
      return;
    }
    // Socket offline or rejected — fall back to REST so nothing is lost.
    try {
      final saved = await _ref.read(chatRepositoryProvider).sendMessage(
            chatId: chatId,
            messageType: messageType,
            content: content,
            mediaUrl: mediaUrl,
            mediaMeta: mediaMeta,
            replyTo: replyTarget?.id,
            clientMessageId: clientId,
          );
      _confirmOptimistic(clientId, saved);
    } on ApiException catch (error) {
      _markFailed(clientId, error.friendlyMessage);
    }
  }

  Future<void> sendText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final editing = state.editingMessage;
    if (editing != null) {
      await _submitEdit(editing, trimmed);
      return;
    }
    await _send(messageType: 'text', content: trimmed);
  }

  Future<void> sendMedia({
    required String messageType,
    required String mediaUrl,
    Map<String, dynamic>? mediaMeta,
    String caption = '',
    String? localFileUri,
  }) =>
      _send(
        messageType: messageType,
        content: caption,
        mediaUrl: mediaUrl,
        mediaMeta: mediaMeta,
        localFileUri: localFileUri,
      );

  void _confirmOptimistic(String clientId, Message saved) {
    final messages = state.messages.map((message) {
      if (message.clientMessageId != clientId) return message;
      return saved.copyWith(sendState: SendState.sent);
    }).toList();
    // Drop any duplicate the socket already inserted.
    final seen = <String>{};
    final deduped = <Message>[];
    for (final message in messages) {
      if (message.clientMessageId != clientId && message.id == saved.id) continue;
      if (!seen.add(message.id)) continue;
      deduped.add(message);
    }
    state = state.copyWith(messages: deduped);
    _ref.read(chatListProvider.notifier).applyLastMessageUpdate(chatId, saved);
  }

  void _markFailed(String clientId, String error) {
    state = state.copyWith(
      messages: state.messages
          .map((message) =>
              message.clientMessageId == clientId ? message.copyWith(sendState: SendState.failed) : message)
          .toList(),
      error: error,
    );
  }

  Future<void> retry(Message message) async {
    if (message.clientMessageId == null) return;
    state = state.copyWith(messages: state.messages.where((m) => m.id != message.id).toList());
    await _send(
      messageType: messageTypeToString(message.messageType),
      content: message.content,
      mediaUrl: message.mediaUrl,
      mediaMeta: message.mediaMeta?.toJson(),
      localFileUri: message.localFileUri,
    );
  }

  // -------------------------------------------------------------- editing
  Future<void> _submitEdit(Message editing, String content) async {
    final previous = editing.content;
    state = state.copyWith(
      messages: state.messages
          .map((m) => m.id == editing.id ? m.copyWith(content: content, editedAt: DateTime.now()) : m)
          .toList(),
      clearEditing: true,
    );
    try {
      final updated = await _ref.read(chatRepositoryProvider).editMessage(editing.id, content);
      state = state.copyWith(
        messages: state.messages.map((m) => m.id == updated.id ? updated : m).toList(),
      );
    } on ApiException catch (error) {
      state = state.copyWith(
        messages: state.messages
            .map((m) => m.id == editing.id ? m.copyWith(content: previous) : m)
            .toList(),
        error: error.friendlyMessage,
      );
    }
  }

  void startEditing(Message message) => state = state.copyWith(editingMessage: message, clearReply: true);
  void cancelEditing() => state = state.copyWith(clearEditing: true);

  // -------------------------------------------------------------- deleting
  Future<void> deleteMessage(Message message, {String mode = 'everyone'}) async {
    final snapshot = state.messages;
    if (mode == 'me') {
      state = state.copyWith(messages: snapshot.where((m) => m.id != message.id).toList());
    } else {
      state = state.copyWith(
        messages: snapshot
            .map((m) => m.id == message.id
                ? m.copyWith(isDeleted: true, content: '', mediaUrl: null)
                : m)
            .toList(),
      );
    }
    try {
      await _ref.read(chatRepositoryProvider).deleteMessage(message.id, mode: mode);
    } on ApiException catch (error) {
      state = state.copyWith(messages: snapshot, error: error.friendlyMessage);
    }
  }

  // ------------------------------------------------------------- reactions
  Future<void> toggleReaction(Message message, String emoji) async {
    final current = message.myReaction(_userId);
    final next = current == emoji ? null : emoji;
    final reactions = [...message.reactions];
    reactions.removeWhere((r) => r.userId == _userId);
    if (next != null) reactions.add(MessageReaction(userId: _userId, emoji: next));
    _patchMessage(message.id, (m) => m.copyWith(reactions: reactions));
    try {
      await _ref.read(chatRepositoryProvider).reactToMessage(message.id, next);
    } on ApiException catch (error) {
      _patchMessage(message.id, (_) => message);
      state = state.copyWith(error: error.friendlyMessage);
    }
  }

  // --------------------------------------------------------------- forward
  Future<bool> forward(Message message, List<String> targetChatIds) async {
    try {
      await _ref.read(chatRepositoryProvider).forwardMessage(message.id, targetChatIds);
      _ref.read(chatListProvider.notifier).refresh();
      return true;
    } on ApiException catch (error) {
      state = state.copyWith(error: error.friendlyMessage);
      return false;
    }
  }

  void setReplyTo(Message? message) =>
      message == null ? state = state.copyWith(clearReply: true) : state = state.copyWith(replyTo: message, clearEditing: true);

  // ---------------------------------------------------------------- typing
  void notifyTyping() {
    final socket = _ref.read(socketServiceProvider);
    if (!_typingSent) {
      _typingSent = true;
      socket.startTyping(chatId);
    }
    _typingStopTimer?.cancel();
    _typingStopTimer = Timer(const Duration(milliseconds: 1800), () {
      _typingSent = false;
      socket.stopTyping(chatId);
    });
  }

  void stopTyping() {
    _typingStopTimer?.cancel();
    if (_typingSent) {
      _typingSent = false;
      _ref.read(socketServiceProvider).stopTyping(chatId);
    }
  }

  // -------------------------------------------------------- realtime hooks
  void onRemoteMessage(Message message) {
    if (message.conversationId != chatId) return;
    // Replace an optimistic copy produced by our own REST fallback.
    if (message.clientMessageId != null) {
      final index = state.messages
          .indexWhere((m) => m.clientMessageId == message.clientMessageId && m.isPending);
      if (index != -1) {
        final messages = [...state.messages];
        messages[index] = message.copyWith(sendState: SendState.sent);
        state = state.copyWith(messages: messages);
        return;
      }
    }
    if (state.messages.any((m) => m.id == message.id)) return;
    state = state.copyWith(messages: [...state.messages, message]);
    if (message.senderId != _userId) {
      // Mark read immediately while the conversation is open.
      _ref.read(chatRepositoryProvider).markRead(chatId).catchError((_) {});
    }
  }

  void onMessageEdited(String messageId, String content, DateTime? editedAt) {
    _patchMessage(messageId, (m) => m.copyWith(content: content, editedAt: editedAt ?? DateTime.now()));
  }

  void onMessageDeleted(String messageId, {bool forEveryone = true, String? forUserId}) {
    if (forEveryone) {
      _patchMessage(messageId, (m) => m.copyWith(isDeleted: true, content: '', mediaUrl: null));
    } else if (forUserId == _userId) {
      state = state.copyWith(messages: state.messages.where((m) => m.id != messageId).toList());
    }
  }

  void onReactionsUpdated(String messageId, List<MessageReaction> reactions) {
    _patchMessage(messageId, (m) => m.copyWith(reactions: reactions));
  }

  void onDeliveryUpdate(List<String> messageIds, String userId) {
    final ids = messageIds.toSet();
    state = state.copyWith(
      messages: state.messages
          .map((m) => ids.contains(m.id) && !m.deliveredTo.contains(userId)
              ? m.copyWith(deliveredTo: [...m.deliveredTo, userId])
              : m)
          .toList(),
    );
  }

  void onReadUpdate(List<String> messageIds, String userId) {
    final ids = messageIds.toSet();
    state = state.copyWith(
      messages: state.messages
          .map((m) => ids.contains(m.id) && !m.readBy.contains(userId)
              ? m.copyWith(readBy: [...m.readBy, userId], deliveredTo: [...m.deliveredTo, userId])
              : m)
          .toList(),
    );
  }

  void setTypingUser(String userId, String displayName, bool typing) {
    if (userId == _userId) return;
    final next = {...state.typingUsers};
    if (typing) {
      next[userId] = displayName;
    } else {
      next.remove(userId);
    }
    state = state.copyWith(typingUsers: next);
  }

  void _patchMessage(String id, Message Function(Message) transform) {
    final messages = state.messages.map((m) => m.id == id ? transform(m) : m).toList();
    state = state.copyWith(messages: messages);
  }

  Future<void> markRead() async {
    try {
      await _ref.read(chatRepositoryProvider).markRead(chatId);
    } catch (_) {}
  }

  @override
  void dispose() {
    _typingStopTimer?.cancel();
    if (_typingSent) {
      _ref.read(socketServiceProvider).stopTyping(chatId);
    }
    super.dispose();
  }
}

final messageControllerProvider =
    StateNotifierProvider.autoDispose.family<MessageController, ChatRoomState, String>((ref, chatId) {
  final controller = MessageController(
    chatId: chatId,
    ref: ref,
    currentUser: ref.watch(currentUserProvider),
  );
  controller.load();
  return controller;
});
