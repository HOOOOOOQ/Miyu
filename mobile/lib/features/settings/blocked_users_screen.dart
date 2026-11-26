import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/miyu_colors.dart';
import '../../models/user.dart';
import '../../providers/core_providers.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/miyu_avatar.dart';
import '../../shared/widgets/miyu_dialogs.dart';
import '../../shared/widgets/miyu_scaffold.dart';

final blockedUsersProvider = FutureProvider<List<BlockedUser>>((ref) async {
  final data = await ref.watch(chatRepositoryProvider).me();
  return data.blocked;
});

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocked = ref.watch(blockedUsersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MiyuScaffold(
      appBar: AppBar(title: const Text('Blocked users')),
      body: SafeArea(
        child: blocked.when(
          loading: () => const MiyuLoading(message: 'Loading blocked users'),
          error: (error, _) => Center(child: Text(error.toString())),
          data: (users) {
            if (users.isEmpty) {
              return const EmptyState(
                icon: Icons.block_rounded,
                title: 'No blocked users',
                message: 'People you block will appear here. They cannot message or call you.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
              itemCount: users.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final user = users[index];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? MiyuColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark ? MiyuColors.darkBorder : MiyuColors.lightBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      MiyuAvatar(name: user.displayName, imageUrl: user.photoURL, size: 44, seed: user.id),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName,
                              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '@${user.username}',
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
                      TextButton(
                        onPressed: () async {
                          try {
                            await ref.read(chatRepositoryProvider).unblockUser(user.id);
                            ref.invalidate(blockedUsersProvider);
                          } catch (_) {
                            if (context.mounted) MiyuDialogs.toast(context, 'Could not unblock');
                          }
                        },
                        child: const Text('Unblock'),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
