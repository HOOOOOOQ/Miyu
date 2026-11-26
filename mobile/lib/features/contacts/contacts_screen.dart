import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/miyu_colors.dart';
import '../../models/user.dart';
import '../../providers/chat_list_provider.dart';
import '../../providers/contacts_provider.dart';
import '../../providers/core_providers.dart';
import '../../routing/routes.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/miyu_avatar.dart';
import '../../shared/widgets/responsive.dart';
import '../../shared/widgets/miyu_dialogs.dart';
import '../../shared/widgets/section_header.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openChatWith(User user) async {
    try {
      final chat = await ref.read(chatRepositoryProvider).createDirectChat(user.id);
      if (!mounted) return;
      ref.read(chatListProvider.notifier).upsertChat(chat);
      await context.push(MiyuRoutes.chatFor(chat.id));
    } catch (_) {
      if (!mounted) return;
      MiyuDialogs.toast(context, 'Could not open a conversation with ${user.displayName}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(contactsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showingSearch = state.query.trim().isNotEmpty;

    return SafeArea(
      bottom: false,
      child: ResponsiveBody(
        child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Find people',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? MiyuColors.darkTextSecondary : MiyuColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text('Contacts', style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 14),
                TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    ref.read(contactsProvider.notifier).setQuery(value);
                    setState(() {});
                  },
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search by name, username or email',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: state.searching
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : state.query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  ref.read(contactsProvider.notifier).setQuery('');
                                  setState(() {});
                                },
                              ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: showingSearch
                ? _SearchResults(
                    state: state,
                    onStartChat: _openChatWith,
                    onOpenProfile: (user) => context.push(MiyuRoutes.userProfileFor(user.id)),
                  )
                : _RecentPeers(
                    peers: state.recentPeers,
                    onStartChat: _openChatWith,
                    onOpenProfile: (user) => context.push(MiyuRoutes.userProfileFor(user.id)),
                  ),
          ),
        ],
        ),
      ),
    );
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({
    required this.state,
    required this.onStartChat,
    required this.onOpenProfile,
  });

  final ContactsState state;
  final ValueChanged<User> onStartChat;
  final ValueChanged<User> onOpenProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.searching && state.results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'Search failed',
        message: state.error,
        actionLabel: 'Retry',
        onAction: () => ref.read(contactsProvider.notifier).refreshResults(),
      );
    }
    if (state.hasSearched && state.results.isEmpty) {
      return EmptyState(
        icon: Icons.person_search_rounded,
        title: 'No one found',
        message: 'No Miyu users match "${state.query}". Try a username instead.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
      itemCount: state.results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final user = state.results[index];
        return _ContactRow(
          user: user,
          onTap: () => onOpenProfile(user),
          trailing: IconButton(
            tooltip: 'Message ${user.displayName}',
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: MiyuColors.accent),
            onPressed: () => onStartChat(user),
          ),
        );
      },
    );
  }
}

class _RecentPeers extends StatelessWidget {
  const _RecentPeers({
    required this.peers,
    required this.onStartChat,
    required this.onOpenProfile,
  });

  final List<User> peers;
  final ValueChanged<User> onStartChat;
  final ValueChanged<User> onOpenProfile;

  @override
  Widget build(BuildContext context) {
    if (peers.isEmpty) {
      return const EmptyState(
        icon: Icons.people_outline_rounded,
        title: 'Your people live here',
        message: 'Search for friends above or start a conversation from a chat.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
      children: [
        const SectionHeader(title: 'People you talk to'),
        ...peers.map(
          (user) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ContactRow(
              user: user,
              onTap: () => onOpenProfile(user),
              trailing: IconButton(
                tooltip: 'Message ${user.displayName}',
                icon: const Icon(Icons.chat_bubble_outline_rounded, color: MiyuColors.accent),
                onPressed: () => onStartChat(user),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.user, required this.onTap, this.trailing});

  final User user;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? MiyuColors.darkSurface : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
                name: user.displayName,
                imageUrl: user.photoURL,
                size: 46,
                showPresence: true,
                isOnline: user.isOnline,
                seed: user.id,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.bio.isNotEmpty ? user.bio : '@${user.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? MiyuColors.darkTextSecondary
                            : MiyuColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              trailing ?? const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }
}
