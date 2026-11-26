import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/onboarding_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/calls/call_screen.dart';
import '../features/chats/new_chat_screen.dart';
import '../features/home/home_screen.dart';
import '../features/messages/chat_screen.dart';
import '../features/groups/create_group_screen.dart';
import '../features/groups/group_info_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/profile/user_profile_screen.dart';
import '../features/settings/about_screen.dart';
import '../features/settings/blocked_users_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/storage_screen.dart';
import '../providers/call_route_bridge.dart';
import '../providers/session_provider.dart';
import 'routes.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Auth-aware router. Redirects run against session state so deep links from
/// notifications land in the right place after login.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: MiyuRoutes.splash,
    refreshListenable: refresh,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final location = state.matchedLocation;
      final isPublic = location == MiyuRoutes.splash || location == MiyuRoutes.onboarding;

      switch (session.status) {
        case SessionStatus.checking:
          return location == MiyuRoutes.splash ? null : MiyuRoutes.splash;
        case SessionStatus.unauthenticated:
          if (isPublic && location == MiyuRoutes.onboarding) return null;
          return MiyuRoutes.onboarding;
        case SessionStatus.authenticated:
          if (isPublic) return MiyuRoutes.home;
          return null;
      }
    },
    routes: [
      GoRoute(
        path: MiyuRoutes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: MiyuRoutes.onboarding,
        pageBuilder: (_, state) => _fade(state, const OnboardingScreen()),
      ),
      GoRoute(
        path: MiyuRoutes.home,
        pageBuilder: (_, state) => _fade(state, const HomeScreen()),
      ),
      GoRoute(
        path: '${MiyuRoutes.chat}/:id',
        pageBuilder: (context, state) => _slide(
          state,
          ChatScreen(
            chatId: state.pathParameters['id']!,
            highlightMessageId: state.uri.queryParameters['messageId'],
          ),
        ),
      ),
      GoRoute(
        path: MiyuRoutes.newChat,
        pageBuilder: (_, state) => _slide(state, const NewChatScreen()),
      ),
      GoRoute(
        path: MiyuRoutes.newGroup,
        pageBuilder: (_, state) => _slide(state, const CreateGroupScreen()),
      ),
      GoRoute(
        path: '${MiyuRoutes.group}/:id',
        pageBuilder: (context, state) => _slide(
          state,
          GroupInfoScreen(groupId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: MiyuRoutes.profile,
        pageBuilder: (_, state) => _slide(state, const ProfileScreen()),
      ),
      GoRoute(
        path: '${MiyuRoutes.userProfile}/:id',
        pageBuilder: (context, state) => _slide(
          state,
          UserProfileScreen(userId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: MiyuRoutes.settings,
        pageBuilder: (_, state) => _slide(state, const SettingsScreen()),
      ),
      GoRoute(
        path: MiyuRoutes.about,
        pageBuilder: (_, state) => _slide(state, const AboutScreen()),
      ),
      GoRoute(
        path: MiyuRoutes.blocked,
        pageBuilder: (_, state) => _slide(state, const BlockedUsersScreen()),
      ),
      GoRoute(
        path: MiyuRoutes.storage,
        pageBuilder: (_, state) => _slide(state, const StorageScreen()),
      ),
      GoRoute(
        path: MiyuRoutes.call,
        pageBuilder: (_, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          opaque: false,
          child: const CallScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.explore_off_rounded, size: 48),
              const SizedBox(height: 16),
              Text('This page does not exist', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(state.uri.toString(), style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go(MiyuRoutes.home),
                child: const Text('Back to chats'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  bindCallRouting(ref: ref, router: router);
  return router;
});

Page<void> _fade(GoRouterState state, Widget child) => CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        child: child,
      ),
    );

Page<void> _slide(GoRouterState state, Widget child) => CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 340),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0.055, 0), end: Offset.zero).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );

/// Lets GoRouter re-run redirects whenever the session changes.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this._ref) {
    _ref.listen<SessionState>(
      sessionProvider,
      (previous, next) {
        if (previous?.status != next.status) notifyListeners();
      },
    );
  }

  final Ref _ref;
}
