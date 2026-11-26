import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/miyu_colors.dart';
import '../../models/user.dart';
import '../../providers/chat_list_provider.dart';
import '../../providers/contacts_provider.dart';
import '../../providers/core_providers.dart';
import '../../routing/routes.dart';
import '../../shared/widgets/miyu_avatar.dart';
import '../../shared/widgets/miyu_dialogs.dart';
import '../../shared/widgets/miyu_scaffold.dart';
import '../../shared/widgets/section_header.dart';

/// Start a 1:1 conversation or jump into group creation.
class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({super.key});

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  final _controller = TextEditingController();
  bool _opening = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openWith(User user) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final chat = await ref.read(chatRepositoryProvider).createDirectChat(user.id);
      ref.read(chatListProvider.notifier).upsertChat(chat);
      if (!mounted) return;
      context.pushReplacement(MiyuRoutes.chatFor(chat.id));
    } catch (_) {
      if (!mounted) return;
      MiyuDialogs.toast(context, 'Could not start a chat with ${user.displayName}');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(contactsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MiyuScaffold(
      appBar: AppBar(
        title: const Text('New conversation'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: (value) => ref.read(contactsProvider.notifier).setQuery(value),
                decoration: const InputDecoration(
                  hintText: 'Search people on Miyu',
                  prefixIcon: Icon(Icons.search_rounded, size: 20),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  Material(
                    color: MiyuColors.accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => context.push(MiyuRoutes.newGroup),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: MiyuColors.accent,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.group_add_rounded, color: Colors.white),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'New group',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Bring several people into one conversation',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_controller.text.trim().isEmpty)
                    const SectionHeader(title: 'People you know'),
                  if (contacts.recentPeers.isEmpty && _controller.text.trim().isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Text(
                        'No recent people yet. Search by name or @username.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ...(() {
                    final query = _controller.text.trim();
                    final list = query.isEmpty
                        ? contacts.recentPeers
                        : [
                            ...contacts.results,
                            ...contacts.recentPeers.where(
                              (p) => p.displayName.toLowerCase().contains(query.toLowerCase()) &&
                                  !contacts.results.any((r) => r.id == p.id),
                            ),
                          ];
                    return list.map(
                      (user) => ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        leading: MiyuAvatar(
                          name: user.displayName,
                          imageUrl: user.photoURL,
                          size: 44,
                          showPresence: true,
                          isOnline: user.isOnline,
                          seed: user.id,
                        ),
                        title: Text(
                          user.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                        ),
                        subtitle: Text(
                          '@${user.username}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? MiyuColors.darkTextSecondary
                                : MiyuColors.lightTextSecondary,
                          ),
                        ),
                        onTap: _opening ? null : () => _openWith(user),
                      ),
                    );
                  })(),
                  if (contacts.searching)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
