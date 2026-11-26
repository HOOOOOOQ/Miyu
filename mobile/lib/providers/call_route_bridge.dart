import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../routing/routes.dart';
import 'call_provider.dart';

/// Pushes the full-screen call route whenever a call becomes active
/// (incoming, outgoing, or accepted) and pops it when the call is over.
///
/// Kept separate from the router definition so `app_router.dart` can import it
/// without creating a provider cycle.
void bindCallRouting({required Ref ref, required GoRouter router}) {
  bool screenOpen = false;

  void openCallScreen() {
    if (screenOpen) return;
    final location = router.routerDelegate.currentConfiguration.uri.path;
    if (location == MiyuRoutes.call) {
      screenOpen = true;
      return;
    }
    screenOpen = true;
    router.push(MiyuRoutes.call);
  }

  void closeCallScreen() {
    if (!screenOpen) return;
    screenOpen = false;
    final location = router.routerDelegate.currentConfiguration.uri.path;
    if (location == MiyuRoutes.call) {
      router.pop();
    }
  }

  ref.listen<CallState>(callControllerProvider, (previous, next) {
    final phase = next.phase;
    final callInProgress = phase == CallPhase.outgoingRinging ||
        phase == CallPhase.incomingRinging ||
        phase == CallPhase.connecting ||
        phase == CallPhase.active;
    if (callInProgress) {
      openCallScreen();
    } else if (phase == CallPhase.idle) {
      closeCallScreen();
    }
  }, fireImmediately: true);
}
