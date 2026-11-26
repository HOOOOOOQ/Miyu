import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/miyu_colors.dart';
import '../../models/user.dart';
import '../../providers/chat_list_provider.dart';
import '../../providers/contacts_provider.dart';
import '../../providers/group_provider.dart';
import '../../routing/routes.dart';
import '../../shared/widgets/miyu_avatar.dart';
import '../../shared/widgets/miyu_dialogs.dart';
import '../../shared/widgets/miyu_scaffold.dart';

/// Two-step group creation: name the group, then pick members.
class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _searchController = TextEditingController();
  final Set<String> _selected = {};
  bool _createStep = true;
  bool _creating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_selected.isEmpty) {
      MiyuDialogs.toast(context, 'Select at least one member');
      return;
    }
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      MiyuDialogs.toast(context, 'Give your group a name');
      return;
    }
    setState(() => _creating = true);
    final result = await ref.read(groupControllerProvider.notifier).create(
          name: name,
          description: _descriptionController.text.trim(),
          memberIds: _selected.toList(),
        );
    if (!mounted) return;
    setState(() => _creating = false);
    if (result.group == null) {
      await MiyuDialogs.showError(context, result.error ?? 'Could not create the group');
      return;
    }
    await ref.read(chatListProvider.notifier).refresh();
    if (!mounted) return;
    context.pushReplacement(MiyuRoutes.chatFor(result.group!.conversationId ?? ''));
  }

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(contactsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final query = _searchController.text.trim().toLowerCase();
    final candidates = [...contacts.recentPeers, ...contacts.results];
    final filtered = candidates
        .where((u) => query.isEmpty ||
            u.displayName.toLowerCase().contains(query) ||
            u.username.toLowerCase().contains(query))
        .toList();
    final unique = <String, User>{for (final u in filtered) u.id: u}.values.toList();

    return MiyuScaffold(
      appBar: AppBar(
        title: const Text('New group'),
        actions: [
          TextButton(
            onPressed: _createStep ? () => setState(() => _createStep = false) : _create,
            child: Text(_createStep ? 'Next' : (_creating ? 'Creating…' : 'Create')),
          ),
        ],
      ),
      body: SafeArea(
        child: _createStep
            ? Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          gradient: MiyuColors.aurora,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: const Icon(Icons.groups_rounded, color: Colors.white, size: 40),
                      ),
                    ),
                    const SizedBox(height: 26),
                    TextField(
                      controller: _nameController,
                      autofocus: true,
                      maxLength: 80,
                      decoration: const InputDecoration(
                        labelText: 'Group name',
                        hintText: 'Weekend crew',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descriptionController,
                      maxLength: 300,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        hintText: 'What is this group about?',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => setState(() => _createStep = false),
                        child: const Text('Choose members'),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Search people',
                        prefixIcon: Icon(Icons.search_rounded, size: 20),
                      ),
                    ),
                  ),
                  if (_selected.isNotEmpty)
                    SizedBox(
                      height: 78,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: unique
                            .where((u) => _selected.contains(u.id))
                            .map(
                              (user) => Padding(
                                padding: const EdgeInsets.all(6),
                                child: GestureDetector(
                                  onTap: () => setState(() => _selected.remove(user.id)),
                                  child: Column(
                                    children: [
                                      Stack(
                                        children: [
                                          MiyuAvatar(
                                            name: user.displayName,
                                            imageUrl: user.photoURL,
                                            size: 44,
                                            seed: user.id,
                                          ),
                                          const Positioned(
                                            right: 0,
                                            bottom: 0,
                                            child: CircleAvatar(
                                              radius: 8,
                                              backgroundColor: MiyuColors.coral,
                                              child: Icon(Icons.close_rounded,
                                                  size: 10, color: Colors.white),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      SizedBox(
                                        width: 56,
                                        child: Text(
                                          user.displayName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  Expanded(
                    child: unique.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(30),
                              child: Text(
                                'Find people first from Contacts, or search above.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: unique.length,
                            itemBuilder: (context, index) {
                              final user = unique[index];
                              final selected = _selected.contains(user.id);
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                leading: MiyuAvatar(
                                  name: user.displayName,
                                  imageUrl: user.photoURL,
                                  size: 42,
                                  showPresence: true,
                                  isOnline: user.isOnline,
                                  seed: user.id,
                                ),
                                title: Text(user.displayName),
                                subtitle: Text('@${user.username}'),
                                trailing: Checkbox(
                                  value: selected,
                                  activeColor: MiyuColors.accent,
                                  onChanged: (value) {
                                    setState(() {
                                      if (value == true) {
                                        _selected.add(user.id);
                                      } else {
                                        _selected.remove(user.id);
                                      }
                                    });
                                  },
                                ),
                                onTap: () {
                                  setState(() {
                                    if (selected) {
                                      _selected.remove(user.id);
                                    } else {
                                      _selected.add(user.id);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                  ),
                  if (_creating && isDark)
                    const LinearProgressIndicator(minHeight: 2),
                ],
              ),
      ),
    );
  }
}
