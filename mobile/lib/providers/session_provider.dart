import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/api_exception.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import 'core_providers.dart';

enum SessionStatus { checking, authenticated, unauthenticated }

class SessionState {
  const SessionState({required this.status, this.user, this.error, this.isRestoring = false});

  final SessionStatus status;
  final User? user;
  final String? error;
  final bool isRestoring;

  bool get isAuthenticated => status == SessionStatus.authenticated && user != null;

  SessionState copyWith({
    SessionStatus? status,
    User? user,
    String? error,
    bool? isRestoring,
    bool clearError = false,
  }) {
    return SessionState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: clearError ? null : (error ?? this.error),
      isRestoring: isRestoring ?? this.isRestoring,
    );
  }
}

class SessionController extends StateNotifier<SessionState> {
  SessionController({required AuthService authService, required Ref ref})
      : _authService = authService,
        _ref = ref,
        super(const SessionState(status: SessionStatus.checking));

  final AuthService _authService;
  final Ref _ref;

  /// Called from the splash screen: restores a stored session if one exists.
  Future<void> bootstrap() async {
    state = state.copyWith(status: SessionStatus.checking, isRestoring: true, clearError: true);
    try {
      final user = await _authService.restoreSession();
      if (user == null) {
        state = const SessionState(status: SessionStatus.unauthenticated);
      } else {
        state = SessionState(status: SessionStatus.authenticated, user: user);
      }
    } on ApiException catch (error) {
      if (error.isNetworkError) {
        // Offline start: keep tokens, surface a retryable error state.
        state = SessionState(
          status: SessionStatus.unauthenticated,
          error: 'You appear to be offline. Reconnect and try again.',
        );
      } else {
        state = SessionState(status: SessionStatus.unauthenticated, error: error.friendlyMessage);
      }
    } catch (_) {
      state = const SessionState(status: SessionStatus.unauthenticated);
    }
  }

  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isRestoring: true, clearError: true);
    try {
      final result = await _authService.signInWithGoogle();
      state = SessionState(status: SessionStatus.authenticated, user: result.user);
      return true;
    } on ApiException catch (error) {
      state = state.copyWith(
        status: SessionStatus.unauthenticated,
        isRestoring: false,
        error: error.code == 'SIGN_IN_CANCELLED' ? null : error.friendlyMessage,
      );
      return false;
    } catch (error) {
      state = state.copyWith(
        status: SessionStatus.unauthenticated,
        isRestoring: false,
        error: 'Sign-in failed. Please try again.',
      );
      return false;
    }
  }

  Future<void> signOut() async {
    final push = _ref.read(pushServiceProvider);
    await push.unregisterCurrentDevice().catchError((_) {});
    await _authService.signOut();
    state = const SessionState(status: SessionStatus.unauthenticated);
  }

  /// Called when the API layer exhausts a refresh attempt.
  Future<void> handleExpiredSession() async {
    if (state.status == SessionStatus.unauthenticated) return;
    await _authService.signOut();
    state = const SessionState(
      status: SessionStatus.unauthenticated,
      error: 'Your session expired. Please sign in again.',
    );
  }

  void updateUser(User user) {
    if (state.user?.id != user.id) return;
    state = state.copyWith(user: user);
  }

  void clearError() => state = state.copyWith(clearError: true);
}

final sessionProvider = StateNotifierProvider<SessionController, SessionState>((ref) {
  final controller = SessionController(
    authService: ref.watch(authServiceProvider),
    ref: ref,
  );
  // When refresh fails the API client asks us to clear the session.
  ref.watch(apiClientProvider).onSessionExpired = controller.handleExpiredSession;
  return controller;
});

final currentUserProvider = Provider<User?>((ref) => ref.watch(sessionProvider).user);
final currentUserIdProvider = Provider<String?>((ref) => ref.watch(sessionProvider).user?.id);
