import 'user.dart';

class GroupPermissions {
  const GroupPermissions({
    this.sendMessages = true,
    this.addMembers = true,
    this.editGroupInfo = false,
  });

  final bool sendMessages;
  final bool addMembers;
  final bool editGroupInfo;

  factory GroupPermissions.fromJson(Map<String, dynamic>? json) => GroupPermissions(
        sendMessages: json?['sendMessages'] != false,
        addMembers: json?['addMembers'] != false,
        editGroupInfo: json?['editGroupInfo'] == true,
      );

  Map<String, dynamic> toJson() => {
        'sendMessages': sendMessages,
        'addMembers': addMembers,
        'editGroupInfo': editGroupInfo,
      };
}

class Group {
  const Group({
    required this.id,
    required this.name,
    this.description = '',
    this.avatar,
    this.members = const [],
    this.admins = const [],
    required this.owner,
    this.conversationId,
    this.memberPermissions = const GroupPermissions(),
    this.memberProfiles = const [],
    this.createdAt,
  });

  final String id;
  final String name;
  final String description;
  final String? avatar;
  final List<String> members;
  final List<String> admins;
  final String owner;
  final String? conversationId;
  final GroupPermissions memberPermissions;
  final List<User> memberProfiles;
  final DateTime? createdAt;

  bool isAdmin(String? userId) => userId != null && admins.contains(userId);
  bool isOwner(String? userId) => userId != null && owner == userId;
  bool isMember(String? userId) => userId != null && members.contains(userId);

  factory Group.fromJson(Map<String, dynamic> json) => Group(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? 'Group').toString(),
        description: (json['description'] ?? '').toString(),
        avatar: json['avatar']?.toString(),
        members: (json['members'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        admins: (json['admins'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        owner: (json['owner'] ?? '').toString(),
        conversationId: json['conversationId']?.toString(),
        memberPermissions:
            GroupPermissions.fromJson(json['memberPermissions'] as Map<String, dynamic>?),
        memberProfiles: (json['memberProfiles'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(User.fromJson)
                .toList() ??
            const [],
        createdAt: json['createdAt'] == null ? null : DateTime.tryParse(json['createdAt'].toString()),
      );

  Group copyWith({
    String? name,
    String? description,
    String? avatar,
    List<String>? members,
    List<String>? admins,
    GroupPermissions? memberPermissions,
    List<User>? memberProfiles,
  }) {
    return Group(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      avatar: avatar ?? this.avatar,
      members: members ?? this.members,
      admins: admins ?? this.admins,
      owner: owner,
      conversationId: conversationId,
      memberPermissions: memberPermissions ?? this.memberPermissions,
      memberProfiles: memberProfiles ?? this.memberProfiles,
      createdAt: createdAt,
    );
  }
}
