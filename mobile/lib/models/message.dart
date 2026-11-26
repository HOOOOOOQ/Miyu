import 'user.dart';

enum MessageType { text, image, video, file, audio, system }

MessageType messageTypeFromString(String? value) {
  switch (value) {
    case 'image':
      return MessageType.image;
    case 'video':
      return MessageType.video;
    case 'file':
      return MessageType.file;
    case 'audio':
      return MessageType.audio;
    case 'system':
      return MessageType.system;
    default:
      return MessageType.text;
  }
}

String messageTypeToString(MessageType type) {
  switch (type) {
    case MessageType.image:
      return 'image';
    case MessageType.video:
      return 'video';
    case MessageType.file:
      return 'file';
    case MessageType.audio:
      return 'audio';
    case MessageType.system:
      return 'system';
    case MessageType.text:
      return 'text';
  }
}

enum SendState { sending, sent, failed }

class MessageReaction {
  const MessageReaction({required this.userId, required this.emoji});

  final String userId;
  final String emoji;

  factory MessageReaction.fromJson(Map<String, dynamic> json) => MessageReaction(
        userId: (json['user'] ?? '').toString(),
        emoji: (json['emoji'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {'user': userId, 'emoji': emoji};
}

class MediaMeta {
  const MediaMeta({
    this.fileName,
    this.fileSize,
    this.mimeType,
    this.width,
    this.height,
    this.duration,
    this.thumbnailUrl,
  });

  final String? fileName;
  final int? fileSize;
  final String? mimeType;
  final double? width;
  final double? height;
  final double? duration;
  final String? thumbnailUrl;

  factory MediaMeta.fromJson(Map<String, dynamic> json) => MediaMeta(
        fileName: json['fileName']?.toString(),
        fileSize: json['fileSize'] is num ? (json['fileSize'] as num).toInt() : null,
        mimeType: json['mimeType']?.toString(),
        width: json['width'] is num ? (json['width'] as num).toDouble() : null,
        height: json['height'] is num ? (json['height'] as num).toDouble() : null,
        duration: json['duration'] is num ? (json['duration'] as num).toDouble() : null,
        thumbnailUrl: json['thumbnailUrl']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'fileName': fileName,
        'fileSize': fileSize,
        'mimeType': mimeType,
        'width': width,
        'height': height,
        'duration': duration,
        'thumbnailUrl': thumbnailUrl,
      };
}

class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.messageType,
    this.content = '',
    this.mediaUrl,
    this.mediaMeta,
    this.clientMessageId,
    this.replyToId,
    this.replyToPreview,
    this.forwardedFrom,
    this.reactions = const [],
    this.deliveredTo = const [],
    this.readBy = const [],
    this.editedAt,
    this.isDeleted = false,
    this.createdAt,
    this.sender,
    this.sendState = SendState.sent,
    this.localFileUri,
    this.uploadProgress = 1,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final MessageType messageType;
  final String content;
  final String? mediaUrl;
  final MediaMeta? mediaMeta;
  final String? clientMessageId;
  final String? replyToId;
  final Message? replyToPreview;
  final String? forwardedFrom;
  final List<MessageReaction> reactions;
  final List<String> deliveredTo;
  final List<String> readBy;
  final DateTime? editedAt;
  final bool isDeleted;
  final DateTime? createdAt;
  final User? sender;

  // Local-only UI state
  final SendState sendState;
  final String? localFileUri;
  final double uploadProgress;

  bool get isPending => id.startsWith('local-');
  bool get isEdited => editedAt != null;

  bool isReadByOther(String currentUserId) =>
      readBy.any((id) => id != currentUserId) && !isPending;

  bool isDeliveredToOther(String currentUserId) =>
      deliveredTo.any((id) => id != currentUserId) && !isPending;

  /// Grouped emoji reactions: `{'👍': 2}`.
  Map<String, int> get reactionSummary {
    final summary = <String, int>{};
    for (final reaction in reactions) {
      summary[reaction.emoji] = (summary[reaction.emoji] ?? 0) + 1;
    }
    return summary;
  }

  String? myReaction(String? userId) {
    if (userId == null) return null;
    for (final reaction in reactions) {
      if (reaction.userId == userId) return reaction.emoji;
    }
    return null;
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    final replyRaw = json['replyToPreview'];
    return Message(
      id: (json['id'] ?? '').toString(),
      conversationId: (json['conversationId'] ?? '').toString(),
      senderId: (json['senderId'] ?? '').toString(),
      messageType: messageTypeFromString(json['messageType']?.toString()),
      content: (json['content'] ?? '').toString(),
      mediaUrl: json['mediaUrl']?.toString(),
      mediaMeta: json['mediaMeta'] is Map<String, dynamic>
          ? MediaMeta.fromJson(json['mediaMeta'] as Map<String, dynamic>)
          : null,
      clientMessageId: json['clientMessageId']?.toString(),
      replyToId: json['replyTo']?.toString(),
      replyToPreview: replyRaw is Map<String, dynamic> ? Message.fromJson(replyRaw) : null,
      forwardedFrom: json['forwardedFrom']?.toString(),
      reactions: (json['reactions'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(MessageReaction.fromJson)
              .toList() ??
          const [],
      deliveredTo: (json['deliveredTo'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      readBy: (json['readBy'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      editedAt: json['editedAt'] == null ? null : DateTime.tryParse(json['editedAt'].toString())?.toLocal(),
      isDeleted: json['isDeleted'] == true,
      createdAt: json['createdAt'] == null ? null : DateTime.tryParse(json['createdAt'].toString())?.toLocal(),
      sender: json['sender'] is Map<String, dynamic> ? User.fromJson(json['sender'] as Map<String, dynamic>) : null,
    );
  }

  Message copyWith({
    String? id,
    String? content,
    List<MessageReaction>? reactions,
    List<String>? deliveredTo,
    List<String>? readBy,
    DateTime? editedAt,
    bool? isDeleted,
    SendState? sendState,
    double? uploadProgress,
    String? mediaUrl,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId,
      senderId: senderId,
      messageType: messageType,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaMeta: mediaMeta,
      clientMessageId: clientMessageId,
      replyToId: replyToId,
      replyToPreview: replyToPreview,
      forwardedFrom: forwardedFrom,
      reactions: reactions ?? this.reactions,
      deliveredTo: deliveredTo ?? this.deliveredTo,
      readBy: readBy ?? this.readBy,
      editedAt: editedAt ?? this.editedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt,
      sender: sender,
      sendState: sendState ?? this.sendState,
      localFileUri: localFileUri,
      uploadProgress: uploadProgress ?? this.uploadProgress,
    );
  }
}
