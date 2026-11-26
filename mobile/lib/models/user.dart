class User {
  const User({
    required this.id,
    required this.displayName,
    required this.username,
    this.email,
    this.photoURL,
    this.bio = '',
    this.isOnline = false,
    this.lastSeen,
    this.showOnlineStatus = true,
    this.showLastSeen = true,
    this.notificationsEnabled = true,
    this.createdAt,
  });

  final String id;
  final String displayName;
  final String username;
  final String? email;
  final String? photoURL;
  final String bio;
  final bool isOnline;
  final DateTime? lastSeen;
  final bool showOnlineStatus;
  final bool showLastSeen;
  final bool notificationsEnabled;
  final DateTime? createdAt;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      displayName: (json['displayName'] ?? 'Miyu user').toString(),
      username: (json['username'] ?? '').toString(),
      email: json['email']?.toString(),
      photoURL: json['photoURL']?.toString(),
      bio: (json['bio'] ?? '').toString(),
      isOnline: json['isOnline'] == true,
      lastSeen: _parseDate(json['lastSeen']),
      showOnlineStatus: json['showOnlineStatus'] != false,
      showLastSeen: json['showLastSeen'] != false,
      notificationsEnabled: json['notificationsEnabled'] != false,
      createdAt: _parseDate(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'username': username,
        'email': email,
        'photoURL': photoURL,
        'bio': bio,
        'isOnline': isOnline,
        'lastSeen': lastSeen?.toIso8601String(),
        'showOnlineStatus': showOnlineStatus,
        'showLastSeen': showLastSeen,
        'notificationsEnabled': notificationsEnabled,
        'createdAt': createdAt?.toIso8601String(),
      };

  User copyWith({
    String? displayName,
    String? username,
    String? photoURL,
    String? bio,
    bool? isOnline,
    DateTime? lastSeen,
    bool? showOnlineStatus,
    bool? showLastSeen,
    bool? notificationsEnabled,
  }) {
    return User(
      id: id,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      email: email,
      photoURL: photoURL ?? this.photoURL,
      bio: bio ?? this.bio,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      showOnlineStatus: showOnlineStatus ?? this.showOnlineStatus,
      showLastSeen: showLastSeen ?? this.showLastSeen,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      createdAt: createdAt,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }
}

class BlockedUser {
  const BlockedUser({
    required this.id,
    required this.displayName,
    required this.username,
    this.photoURL,
    this.blockedAt,
  });

  final String id;
  final String displayName;
  final String username;
  final String? photoURL;
  final DateTime? blockedAt;

  factory BlockedUser.fromJson(Map<String, dynamic> json) => BlockedUser(
        id: (json['id'] ?? '').toString(),
        displayName: (json['displayName'] ?? 'Blocked user').toString(),
        username: (json['username'] ?? '').toString(),
        photoURL: json['photoURL']?.toString(),
        blockedAt: json['blockedAt'] == null ? null : DateTime.tryParse(json['blockedAt'].toString()),
      );
}
