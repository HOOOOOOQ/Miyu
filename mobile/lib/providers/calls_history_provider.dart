import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/api_exception.dart';
import '../models/call.dart';
import 'core_providers.dart';
import 'session_provider.dart';

class CallHistoryState {
  const CallHistoryState({this.calls = const [], this.loading = true, this.error});

  final List<CallSession> calls;
  final bool loading;
  final String? error;

  CallHistoryState copyWith({
    List<CallSession>? calls,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return CallHistoryState(
      calls: calls ?? this.calls,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class CallHistoryController extends StateNotifier<CallHistoryState> {
  CallHistoryController({required Ref ref}) : _ref = ref, super(const CallHistoryState());

  final Ref _ref;

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final calls = await _ref.read(chatRepositoryProvider).callHistory();
      state = CallHistoryState(calls: calls, loading: false);
    } on ApiException catch (error) {
      state = state.copyWith(loading: false, error: error.friendlyMessage);
    }
  }

  void prepend(CallSession call) {
    state = state.copyWith(calls: [call, ...state.calls]);
  }
}

final callHistoryProvider =
    StateNotifierProvider<CallHistoryController, CallHistoryState>((ref) {
  final controller = CallHistoryController(ref: ref);
  ref.listen(sessionProvider, (previous, next) {
    if (next.isAuthenticated) controller.load();
  }, fireImmediately: true);
  return controller;
});
