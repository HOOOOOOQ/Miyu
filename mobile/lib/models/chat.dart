import 'group.dart';
import 'message.dart';
import 'user.dart';

class Chat {
  const Chat({
    required this.id,
    required this.conversationType,
    this.participants = const [],
    this.participantProfiles = const [],
    this.peerId,
    this.group,
    this.lastMessage,
    this.lastActivity,
    this.unreadCount = 0,
    this.pinned = false,
    this.archived = false,
    this.muted = false,
  });

  final String id;
  final String conversationType; // direct | group
  final List<String> participants;
  final List<User> participantProfiles;
  final String? peerId;
  final Group? group;
  final Message? lastMessage;
  final DateTime? lastActivity;
  final int unreadCount;
  final bool pinned;
  final bool archived;
  final bool muted;

  bool get isGroup => conversationType == 'group';

  /// The other user for a direct chat, matched from the participant list.
  User? get peer {
    if (isGroup) return null;
    if (peerId != null) {
      for (final profile in participantProfiles) {
        if (profile.id == peerId) return profile;
      }
    }
    for (final profile in participantProfiles) {
      return profile;
    }
    return null;
  }

  String get title {
    if (isGroup) return group?.name ?? 'Group';
    return peer?.displayName ?? 'Miyu user';
  }

  String? get avatarUrl => isGroup ? group?.avatar : peer?.photoURL;

  String get avatarSeed => isGroup ? (group?.id ?? id) : (peer?.id ?? id);

  bool get peerIsOnline => !isGroup && (peer?.isOnline ?? false);

  Chat copyWith({
    Group? group,
    Message? lastMessage,
    DateTime? lastActivity,
    int? unreadCount,
    bool? pinned,
    bool? archived,
    bool? muted,
    List<User>? participantProfiles,
    String? peerId,
  }) {
    return Chat(
      id: id,
      conversationType: conversationType,
      participants: participants,
      participantProfiles: participantProfiles ?? this.participantProfiles,
      peerId: peerId ?? this.peerId,
      group: group ?? this.group,
      lastMessage: lastMessage ?? this.lastMessage,
      lastActivity: lastActivity ?? this.lastActivity,
      unreadCount: unreadCount ?? this.unreadCount,
      pinned: pinned ?? this.pinned,
      archived: archived ?? this.archived,
      muted: muted ?? this.muted,
    );
  }

  factory Chat.fromJson(Map<String, dynamic> json) {
    final profiles = (json['participantProfiles'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(User.fromJson)
            .toList() ??
        const <User>[];
    return Chat(
      id: (json['id'] ?? '').toString(),
      conversationType: (json['conversationType'] ?? 'direct').toString(),
      participants: (json['participants'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      participantProfiles: profiles,
      peerId: json['peerId']?.toString(),
      group: json['group'] is Map<String, dynamic>
          ? Group.fromJson(json['group'] as Map<String, dynamic>)
          : null,
      lastMessage: json['lastMessage'] is Map<String, dynamic>
          ? Message.fromJson(json['lastMessage'] as Map<String, dynamic>)
          : null,
      lastActivity: json['lastActivity'] == null
          ? null
          : DateTime.tryParse(json['lastActivity'].toString())?.toLocal(),
      unreadCount: json['unreadCount'] is num ? (json['unreadCount'] as num).toInt() : 0,
      pinned: json['pinned'] == true,
      archived: json['archived'] == true,
      muted: json['muted'] == true,
    );
  }
}
