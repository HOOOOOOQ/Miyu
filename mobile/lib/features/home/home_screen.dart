import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/chat_list_provider.dart';
import '../../providers/calls_history_provider.dart';
import '../../providers/realtime_provider.dart';
import '../../shared/widgets/glass_bottom_nav.dart';
import '../../shared/widgets/miyu_scaffold.dart';
import '../calls/calls_screen.dart';
import '../chats/chats_screen.dart';
import '../contacts/contacts_screen.dart';
import '../settings/settings_screen.dart';

/// Root shell with a floating glass navigation bar. Uses an IndexedStack so
/// tab state (scroll position, search) survives switching.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _index = 0;

  static const _items = [
    GlassNavItem(label: 'Chats', icon: Icons.chat_bubble_outline_rounded, activeIcon: Icons.chat_bubble_rounded),
    GlassNavItem(label: 'Calls', icon: Icons.call_outlined, activeIcon: Icons.call_rounded),
    GlassNavItem(label: 'Contacts', icon: Icons.people_outline_rounded, activeIcon: Icons.people_rounded),
    GlassNavItem(label: 'Settings', icon: Icons.settings_outlined, activeIcon: Icons.settings_rounded),
  ];

  @override
  void initState() {
    super.initState();
    // Keep the realtime coordinator alive for the whole authenticated session.
    ref.read(realtimeCoordinatorProvider);
  }

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(chatListProvider.select((state) => state.totalUnread));
    final missedCalls = ref.watch(callHistoryProvider.select(
      (state) => state.calls.where((call) => call.isMissed).length,
    ));

    return MiyuScaffold(
      showGlow: true,
      bottomNavigationBar: GlassBottomNav(
        currentIndex: _index,
        items: _items,
        unreadBadge: unread,
        callsBadge: missedCalls,
        onSelect: (index) => setState(() => _index = index),
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          ChatsScreen(),
          CallsScreen(),
          ContactsScreen(),
          SettingsScreen(embedded: true),
        ],
      ),
    );
  }
}
