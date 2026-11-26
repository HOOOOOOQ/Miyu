import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/api_exception.dart';
import '../models/chat.dart';
import '../models/message.dart';
import 'core_providers.dart';
import 'session_provider.dart';

class ChatListState {
  const ChatListState({
    this.chats = const [],
    this.loading = false,
    this.refreshing = false,
    this.error,
    this.searchQuery = '',
    this.showArchived = false,
  });

  final List<Chat> chats;
  final bool loading;
  final bool refreshing;
  final String? error;
  final String searchQuery;
  final bool showArchived;

  bool get isEmpty => !loading && chats.isEmpty;

  List<Chat> get visibleChats {
    final active = chats.where((chat) => chat.archived == showArchived).toList();
    if (searchQuery.trim().isEmpty) return active;
    final query = searchQuery.toLowerCase();
    return active
        .where((chat) =>
            chat.title.toLowerCase().contains(query) ||
            (chat.group?.description.toLowerCase().contains(query) ?? false) ||
            (chat.peer?.username.toLowerCase().contains(query) ?? false))
        .toList();
  }

  int get totalUnread => chats.fold(0, (sum, chat) => sum + chat.unreadCount);
  int get archivedCount => chats.where((chat) => chat.archived).length;

  ChatListState copyWith({
    List<Chat>? chats,
    bool? loading,
    bool? refreshing,
    String? error,
    bool clearError = false,
    String? searchQuery,
    bool? showArchived,
  }) {
    return ChatListState(
      chats: chats ?? this.chats,
      loading: loading ?? this.loading,
      refreshing: refreshing ?? this.refreshing,
      error: clearError ? null : (error ?? this.error),
      searchQuery: searchQuery ?? this.searchQuery,
      showArchived: showArchived ?? this.showArchived,
    );
  }
}

class ChatListController extends StateNotifier<ChatListState> {
  ChatListController({required Ref ref})
      : _ref = ref,
        super(const ChatListState(loading: true));

  final Ref _ref;
  Timer? _refreshDebounce;

  Future<void> load({bool silent = false}) async {
    if (!silent) state = state.copyWith(loading: true, clearError: true);
    try {
      final chats = await _ref.read(chatRepositoryProvider).listChats(includeArchived: true);
      final sorted = _sorted(chats);
      state = state.copyWith(chats: sorted, loading: false, refreshing: false, clearError: true);
    } on ApiException catch (error) {
      state = state.copyWith(
        loading: false,
        refreshing: false,
        error: error.friendlyMessage,
      );
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(refreshing: true);
    await load(silent: true);
  }

  List<Chat> _sorted(List<Chat> chats) {
    final sorted = [...chats];
    sorted.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      final aTime = a.lastActivity ?? a.lastMessage?.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.lastActivity ?? b.lastMessage?.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return sorted;
  }

  void setSearchQuery(String query) => state = state.copyWith(searchQuery: query);

  void toggleArchived() => state = state.copyWith(showArchived: !state.showArchived);

  Chat? chatById(String id) {
    for (final chat in state.chats) {
      if (chat.id == id) return chat;
    }
    return null;
  }

  /// Upsert a chat fetched individually (e.g. after creating a conversation).
  void upsertChat(Chat chat) {
    final existing = state.chats.where((c) => c.id != chat.id).toList();
    // Merge: preserve existing flags when the new payload lacks them.
    state = state.copyWith(chats: _sorted([chat, ...existing]));
  }

  /// Realtime: a new message arrived. Bumps the chat, increments unread when
  /// the viewer is not currently inside the conversation.
  void applyIncomingMessage(Message message, {required String currentUserId, String? activeChatId}) {
    final index = state.chats.indexWhere((chat) => chat.id == message.conversationId);
    if (index == -1) {
      _scheduleRefresh();
      return;
    }
    final chat = state.chats[index];
    final isMine = message.senderId == currentUserId;
    final viewing = activeChatId == message.conversationId;
    final updated = chat.copyWith(
      lastMessage: message,
      lastActivity: message.createdAt ?? DateTime.now(),
      unreadCount: isMine || viewing ? 0 : chat.unreadCount + 1,
    );
    final chats = [...state.chats];
    chats[index] = updated;
    state = state.copyWith(chats: _sorted(chats));
  }

  void applyLastMessageUpdate(String chatId, Message message) {
    final index = state.chats.indexWhere((chat) => chat.id == chatId);
    if (index == -1) return;
    final chats = [...state.chats];
    chats[index] = chats[index].copyWith(
      lastMessage: message,
      lastActivity: message.createdAt ?? DateTime.now(),
    );
    state = state.copyWith(chats: _sorted(chats));
  }

  void clearUnread(String chatId) {
    final index = state.chats.indexWhere((chat) => chat.id == chatId);
    if (index == -1 || state.chats[index].unreadCount == 0) return;
    final chats = [...state.chats];
    chats[index] = chats[index].copyWith(unreadCount: 0);
    state = state.copyWith(chats: chats);
  }

  void setPinnedLocal(String chatId, bool pinned) {
    final index = state.chats.indexWhere((chat) => chat.id == chatId);
    if (index == -1) return;
    final chats = [...state.chats];
    chats[index] = chats[index].copyWith(pinned: pinned);
    state = state.copyWith(chats: _sorted(chats));
  }

  void setArchivedLocal(String chatId, bool archived) {
    final index = state.chats.indexWhere((chat) => chat.id == chatId);
    if (index == -1) return;
    final chats = [...state.chats];
    chats[index] = chats[index].copyWith(archived: archived);
    state = state.copyWith(chats: chats);
  }

  void setMutedLocal(String chatId, bool muted) {
    final index = state.chats.indexWhere((chat) => chat.id == chatId);
    if (index == -1) return;
    final chats = [...state.chats];
    chats[index] = chats[index].copyWith(muted: muted);
    state = state.copyWith(chats: chats);
  }

  void removeChat(String chatId) {
    state = state.copyWith(chats: state.chats.where((chat) => chat.id != chatId).toList());
  }

  void updatePresence(String userId, bool isOnline, DateTime? lastSeen) {
    var changed = false;
    final chats = state.chats.map((chat) {
      if (chat.peerId != userId) return chat;
      changed = true;
      final profiles = chat.participantProfiles
          .map((p) => p.id == userId
              ? p.copyWith(isOnline: isOnline, lastSeen: lastSeen ?? p.lastSeen)
              : p)
          .toList();
      return chat.copyWith(participantProfiles: profiles);
    }).toList();
    if (changed) state = state.copyWith(chats: chats);
  }

  /// Batch refresh coalescing — new conversations arrive without their own event.
  void _scheduleRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 400), () => load(silent: true));
  }

  void reset() {
    _refreshDebounce?.cancel();
    state = const ChatListState(loading: false);
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    super.dispose();
  }
}

final chatListProvider = StateNotifierProvider<ChatListController, ChatListState>((ref) {
  final controller = ChatListController(ref: ref);
  // Auto-load when a session exists; reset when logged out.
  ref.listen<SessionState>(sessionProvider, (previous, next) {
    if (next.isAuthenticated && previous?.isAuthenticated != true) {
      controller.load();
    } else if (!next.isAuthenticated && previous?.isAuthenticated == true) {
      controller.reset();
    }
  }, fireImmediately: true);
  return controller;
});

/// Tracks which conversation is currently open (drives unread suppression).
final activeChatIdProvider = StateProvider<String?>((ref) => null);
