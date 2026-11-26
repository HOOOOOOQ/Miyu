import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/api_exception.dart';
import '../models/user.dart';
import 'chat_list_provider.dart';
import 'core_providers.dart';

class ContactsState {
  const ContactsState({
    this.query = '',
    this.results = const [],
    this.searching = false,
    this.hasSearched = false,
    this.recentPeers = const [],
    this.error,
  });

  final String query;
  final List<User> results;
  final bool searching;
  final bool hasSearched;
  final List<User> recentPeers;
  final String? error;

  ContactsState copyWith({
    String? query,
    List<User>? results,
    bool? searching,
    bool? hasSearched,
    List<User>? recentPeers,
    String? error,
    bool clearError = false,
  }) {
    return ContactsState(
      query: query ?? this.query,
      results: results ?? this.results,
      searching: searching ?? this.searching,
      hasSearched: hasSearched ?? this.hasSearched,
      recentPeers: recentPeers ?? this.recentPeers,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ContactsController extends StateNotifier<ContactsState> {
  ContactsController({required Ref ref}) : _ref = ref, super(const ContactsState(hasSearched: false));

  final Ref _ref;
  Timer? _debounce;

  /// People you already talk to, derived from the chat list — makes Contacts
  /// useful before typing anything.
  void syncFromChats(List chats) {
    final seen = <String>{};
    final peers = <User>[];
    for (final chat in chats) {
      final User? peer = chat.peer;
      if (peer == null) continue;
      if (seen.add(peer.id)) peers.add(peer);
    }
    state = state.copyWith(recentPeers: peers);
  }

  void setQuery(String query) {
    state = state.copyWith(query: query);
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      state = state.copyWith(results: const [], hasSearched: false, searching: false);
      return;
    }
    state = state.copyWith(searching: true);
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    try {
      final users = await _ref.read(chatRepositoryProvider).searchUsers(query.trim());
      if (state.query != query) return;
      state = state.copyWith(results: users, searching: false, hasSearched: true, clearError: true);
    } on ApiException catch (error) {
      if (state.query != query) return;
      state = state.copyWith(searching: false, hasSearched: true, error: error.friendlyMessage);
    }
  }

  Future<void> refreshResults() => _search(state.query);

  Future<void> block(User user) async {
    await _ref.read(chatRepositoryProvider).blockUser(user.id);
    state = state.copyWith(results: state.results.where((u) => u.id != user.id).toList());
  }

  Future<void> report(User user, String reason) async {
    await _ref.read(chatRepositoryProvider).reportUser(user.id, reason);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final contactsProvider = StateNotifierProvider<ContactsController, ContactsState>((ref) {
  final controller = ContactsController(ref: ref);
  ref.listen(chatListProvider, (previous, next) {
    controller.syncFromChats(next.chats);
  }, fireImmediately: true);
  return controller;
});

/// Tracks whether this user has blocked a specific peer (for profile sheets).
final blockedStateProvider = FutureProvider.family<bool, String>((ref, userId) async {
  final data = await ref.watch(chatRepositoryProvider).getUser(userId);
  return data.iBlockedThem;
});
