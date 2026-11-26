import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/api_exception.dart';
import '../models/group.dart';
import 'core_providers.dart';
import 'session_provider.dart';

class GroupController extends StateNotifier<AsyncValue<Group?>> {
  GroupController({required Ref ref}) : _ref = ref, super(const AsyncValue.data(null));

  final Ref _ref;

  Future<Group?> load(String groupId) async {
    state = const AsyncValue.loading();
    try {
      final group = await _ref.read(chatRepositoryProvider).getGroup(groupId);
      state = AsyncValue.data(group);
      return group;
    } on ApiException catch (error, stack) {
      state = AsyncValue.error(error.friendlyMessage, stack);
      return null;
    }
  }

  Future<({Group? group, String? error})> create({
    required String name,
    String description = '',
    required List<String> memberIds,
  }) async {
    try {
      final result = await _ref.read(chatRepositoryProvider).createGroup(
            name: name,
            description: description,
            memberIds: memberIds,
          );
      return (group: result.group, error: null);
    } on ApiException catch (error) {
      return (group: null, error: error.friendlyMessage);
    }
  }

  Future<String?> update(String groupId, Map<String, dynamic> updates) async {
    try {
      final group = await _ref.read(chatRepositoryProvider).updateGroup(groupId, updates);
      state = AsyncValue.data(group);
      return null;
    } on ApiException catch (error) {
      return error.friendlyMessage;
    }
  }

  Future<String?> addMembers(String groupId, List<String> memberIds) async {
    try {
      final group = await _ref.read(chatRepositoryProvider).addGroupMembers(groupId, memberIds);
      state = AsyncValue.data(group);
      return null;
    } on ApiException catch (error) {
      return error.friendlyMessage;
    }
  }

  Future<String?> removeMember(String groupId, String userId) async {
    try {
      final group = await _ref.read(chatRepositoryProvider).removeGroupMember(groupId, userId);
      state = AsyncValue.data(group);
      return null;
    } on ApiException catch (error) {
      return error.friendlyMessage;
    }
  }

  Future<String?> setAdmin(String groupId, String userId, {bool makeAdmin = true}) async {
    try {
      final group = await _ref
          .read(chatRepositoryProvider)
          .setGroupAdmin(groupId, userId, makeAdmin: makeAdmin);
      state = AsyncValue.data(group);
      return null;
    } on ApiException catch (error) {
      return error.friendlyMessage;
    }
  }

  Future<String?> leave(String groupId) async {
    try {
      await _ref.read(chatRepositoryProvider).leaveGroup(groupId);
      return null;
    } on ApiException catch (error) {
      return error.friendlyMessage;
    }
  }

  Future<String?> delete(String groupId) async {
    try {
      await _ref.read(chatRepositoryProvider).deleteGroup(groupId);
      return null;
    } on ApiException catch (error) {
      return error.friendlyMessage;
    }
  }
}

final groupControllerProvider =
    StateNotifierProvider.autoDispose<GroupController, AsyncValue<Group?>>((ref) {
  return GroupController(ref: ref);
});

/// Whether the current user is an admin of a group (used for menu gating).
final isGroupAdminProvider = Provider.family<bool, Group>((ref, group) {
  final userId = ref.watch(currentUserIdProvider);
  return group.isAdmin(userId);
});
