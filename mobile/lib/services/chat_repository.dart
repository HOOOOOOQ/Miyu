import '../core/network/api_client.dart';
import '../models/call.dart';
import '../models/chat.dart';
import '../models/group.dart';
import '../models/message.dart';
import '../models/user.dart';

/// REST facade for chats, messages, groups, users, calls and notifications.
/// Realtime delivery is handled separately by SocketService; every method here
/// maps 1:1 to a documented backend route.
class ChatRepository {
  ChatRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  Map<String, dynamic> _data(Map<String, dynamic> response) =>
      (response['data'] as Map<String, dynamic>?) ?? const {};

  // ---------------------------------------------------------------- account
  Future<({User user, List<BlockedUser> blocked})> me() async {
    final data = _data(await _api.get('/users/me'));
    return (
      user: User.fromJson(data['user'] as Map<String, dynamic>),
      blocked: (data['blockedUsers'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(BlockedUser.fromJson)
              .toList() ??
          const [],
    );
  }

  Future<User> updateProfile(Map<String, dynamic> updates) async {
    final data = _data(await _api.patch('/users/me', data: updates));
    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<void> deleteAccount() => _api.delete('/users/me');

  Future<List<User>> searchUsers(String query) async {
    final data = _data(await _api.get('/users/search', query: {'q': query}));
    return (data['users'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(User.fromJson)
            .toList() ??
        const [];
  }

  Future<({User user, bool iBlockedThem, bool theyBlockedMe})> getUser(String id) async {
    final data = _data(await _api.get('/users/$id'));
    return (
      user: User.fromJson(data['user'] as Map<String, dynamic>),
      iBlockedThem: data['iBlockedThem'] == true,
      theyBlockedMe: data['theyBlockedMe'] == true,
    );
  }

  Future<void> blockUser(String userId, {String? reason}) =>
      _api.post('/users/$userId/block', data: {if (reason != null) 'reason': reason});

  Future<void> unblockUser(String userId) => _api.delete('/users/$userId/block');

  Future<void> reportUser(String userId, String reason) =>
      _api.post('/users/$userId/report', data: {'reason': reason});

  // ------------------------------------------------------------------ chats
  Future<List<Chat>> listChats({bool includeArchived = false}) async {
    final data = _data(
      await _api.get('/chats', query: {'includeArchived': includeArchived.toString()}),
    );
    return (data['chats'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(Chat.fromJson)
            .toList() ??
        const [];
  }

  Future<Chat> createDirectChat(String participantId) async {
    final data = _data(await _api.post('/chats', data: {'participantId': participantId}));
    return Chat.fromJson(data['chat'] as Map<String, dynamic>);
  }

  Future<Chat> getChat(String chatId) async {
    final data = _data(await _api.get('/chats/$chatId'));
    return Chat.fromJson(data['chat'] as Map<String, dynamic>);
  }

  Future<void> deleteChat(String chatId) => _api.delete('/chats/$chatId');

  Future<void> setArchived(String chatId, bool archived) =>
      _api.post('/chats/$chatId/archive', data: {'archive': archived});

  Future<void> setPinned(String chatId, bool pinned) =>
      _api.post('/chats/$chatId/pin', data: {'pin': pinned});

  Future<void> setMuted(String chatId, bool muted) =>
      _api.post('/chats/$chatId/mute', data: {'mute': muted});

  // --------------------------------------------------------------- messages
  Future<({List<Message> messages, String? nextCursor, bool hasMore})> listMessages(
    String chatId, {
    String? cursor,
    int limit = 30,
  }) async {
    final data = _data(await _api.get('/chats/$chatId/messages', query: {
      'limit': limit,
      if (cursor != null) 'cursor': cursor,
    }));
    final messages = (data['messages'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(Message.fromJson)
            .toList() ??
        const <Message>[];
    return (
      messages: messages,
      nextCursor: data['nextCursor']?.toString(),
      hasMore: data['hasMore'] == true,
    );
  }

  /// REST send — used as a fallback when the realtime socket is offline.
  Future<Message> sendMessage({
    required String chatId,
    required String messageType,
    String content = '',
    String? mediaUrl,
    Map<String, dynamic>? mediaMeta,
    String? replyTo,
    String? clientMessageId,
  }) async {
    final data = _data(await _api.post('/messages', data: {
      'conversationId': chatId,
      'messageType': messageType,
      'content': content,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
      if (mediaMeta != null) 'mediaMeta': mediaMeta,
      if (replyTo != null) 'replyTo': replyTo,
      if (clientMessageId != null) 'clientMessageId': clientMessageId,
    }));
    return Message.fromJson(data['message'] as Map<String, dynamic>);
  }

  Future<Message> editMessage(String messageId, String content) async {
    final data = _data(await _api.patch('/messages/$messageId', data: {'content': content}));
    return Message.fromJson(data['message'] as Map<String, dynamic>);
  }

  Future<void> deleteMessage(String messageId, {String mode = 'everyone'}) =>
      _api.delete('/messages/$messageId', data: {'mode': mode});

  Future<void> reactToMessage(String messageId, String? emoji) =>
      _api.post('/messages/$messageId/reactions', data: {'emoji': emoji});

  Future<List<Message>> forwardMessage(String messageId, List<String> chatIds) async {
    final data = _data(await _api.post(
      '/messages/$messageId/forward',
      data: {'conversationIds': chatIds},
    ));
    return (data['messages'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(Message.fromJson)
            .toList() ??
        const [];
  }

  Future<void> markRead(String chatId) => _api.post('/chats/$chatId/read');
  Future<void> markDelivered(String chatId) => _api.post('/chats/$chatId/delivered');

  // ----------------------------------------------------------------- groups
  Future<({Group group, String conversationId})> createGroup({
    required String name,
    String description = '',
    required List<String> memberIds,
    String? avatar,
  }) async {
    final data = _data(await _api.post('/groups', data: {
      'name': name,
      'description': description,
      'memberIds': memberIds,
      if (avatar != null) 'avatar': avatar,
    }));
    return (
      group: Group.fromJson(data['group'] as Map<String, dynamic>),
      conversationId: data['conversationId'].toString(),
    );
  }

  Future<Group> getGroup(String groupId) async {
    final data = _data(await _api.get('/groups/$groupId'));
    return Group.fromJson(data['group'] as Map<String, dynamic>);
  }

  Future<Group> updateGroup(String groupId, Map<String, dynamic> updates) async {
    final data = _data(await _api.patch('/groups/$groupId', data: updates));
    return Group.fromJson(data['group'] as Map<String, dynamic>);
  }

  Future<Group> addGroupMembers(String groupId, List<String> memberIds) async {
    final data =
        _data(await _api.post('/groups/$groupId/members', data: {'memberIds': memberIds}));
    return Group.fromJson(data['group'] as Map<String, dynamic>);
  }

  Future<Group> removeGroupMember(String groupId, String userId) async {
    final data = _data(await _api.delete('/groups/$groupId/members/$userId'));
    return Group.fromJson(data['group'] as Map<String, dynamic>);
  }

  Future<Group> setGroupAdmin(String groupId, String userId, {bool makeAdmin = true}) async {
    final data = _data(await _api.post('/groups/$groupId/admins', data: {
      'userId': userId,
      'makeAdmin': makeAdmin,
    }));
    return Group.fromJson(data['group'] as Map<String, dynamic>);
  }

  Future<void> leaveGroup(String groupId) => _api.post('/groups/$groupId/leave');

  Future<void> deleteGroup(String groupId) => _api.delete('/groups/$groupId');

  // ------------------------------------------------------------------ calls
  Future<CallSession> startCall({
    required String receiverId,
    required CallType callType,
    String? conversationId,
  }) async {
    final data = _data(await _api.post('/calls', data: {
      'receiverIds': [receiverId],
      'callType': callType == CallType.video ? 'video' : 'voice',
      if (conversationId != null) 'conversationId': conversationId,
    }));
    final call = CallSession.fromJson(data['call'] as Map<String, dynamic>, peerId: receiverId);
    final caller = data['caller'];
    final peer = caller is Map<String, dynamic> ? User.fromJson(caller) : null;
    return call.copyWith(peer: peer);
  }

  Future<void> acceptCall(String callId) => _api.post('/calls/$callId/accept');
  Future<void> rejectCall(String callId) => _api.post('/calls/$callId/reject');
  Future<void> endCall(String callId, {String? status}) =>
      _api.post('/calls/$callId/end', data: {if (status != null) 'status': status});
  Future<void> markCallBusy(String callId) => _api.post('/calls/$callId/busy');

  Future<List<CallSession>> callHistory() async {
    final data = _data(await _api.get('/calls/history'));
    return (data['calls'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map((json) {
              final call = CallSession.fromJson(json);
              final peers = json['direction'] == 'outgoing' ? json['receivers'] : null;
              final caller = json['caller'];
              User? peer;
              if (peers is List && peers.isNotEmpty && peers.first is Map<String, dynamic>) {
                peer = User.fromJson(peers.first as Map<String, dynamic>);
              } else if (caller is Map<String, dynamic>) {
                peer = User.fromJson(caller);
              }
              return call.copyWith(peer: peer);
            })
            .toList() ??
        const [];
  }

  Future<CallSession> getCall(String callId) async {
    final data = _data(await _api.get('/calls/$callId'));
    return CallSession.fromJson(data['call'] as Map<String, dynamic>);
  }

  // ---------------------------------------------------------- notifications
  Future<void> markAllNotificationsRead() => _api.post('/notifications/read-all');
}
