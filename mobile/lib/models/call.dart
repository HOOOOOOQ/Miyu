import 'user.dart';

enum CallType { voice, video }

CallType callTypeFromString(String? value) => value == 'video' ? CallType.video : CallType.voice;

enum CallStatus { ringing, ongoing, ended, missed, rejected, cancelled, busy, failed, answered }

CallStatus callStatusFromString(String? value) {
  switch (value) {
    case 'ongoing':
      return CallStatus.ongoing;
    case 'answered':
      return CallStatus.answered;
    case 'ended':
      return CallStatus.ended;
    case 'missed':
      return CallStatus.missed;
    case 'rejected':
      return CallStatus.rejected;
    case 'cancelled':
      return CallStatus.cancelled;
    case 'busy':
      return CallStatus.busy;
    case 'failed':
      return CallStatus.failed;
    default:
      return CallStatus.ringing;
  }
}

class CallSession {
  const CallSession({
    required this.id,
    required this.callerId,
    required this.receiverIds,
    required this.callType,
    required this.status,
    this.conversationId,
    this.startedAt,
    this.answeredAt,
    this.endedAt,
    this.duration = 0,
    this.peer,
    this.direction = 'outgoing',
    this.createdAt,
  });

  final String id;
  final String callerId;
  final List<String> receiverIds;
  final CallType callType;
  final CallStatus status;
  final String? conversationId;
  final DateTime? startedAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;
  final int duration;
  final User? peer;
  final String direction; // incoming | outgoing
  final DateTime? createdAt;

  /// Timestamp used by the history list: the call's creation time, falling
  /// back to when it started/ended for records created before that field.
  DateTime? get sortTime => createdAt ?? startedAt ?? answeredAt ?? endedAt;

  bool get isVideo => callType == CallType.video;
  bool get isRinging => status == CallStatus.ringing;
  bool get isActive => status == CallStatus.ongoing || status == CallStatus.answered;
  bool get isMissed => status == CallStatus.missed || (direction == 'incoming' && status == CallStatus.cancelled);

  String get otherUserId {
    if (direction == 'outgoing') {
      return receiverIds.isNotEmpty ? receiverIds.first : '';
    }
    return callerId;
  }

  factory CallSession.fromJson(Map<String, dynamic> json, {String? peerId}) {
    return CallSession(
      id: (json['id'] ?? '').toString(),
      callerId: (json['callerId'] ?? '').toString(),
      receiverIds: (json['receiverIds'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      callType: callTypeFromString(json['callType']?.toString()),
      status: callStatusFromString(json['status']?.toString()),
      conversationId: json['conversationId']?.toString(),
      startedAt: json['startedAt'] == null
          ? null
          : DateTime.tryParse(json['startedAt'].toString())?.toLocal(),
      answeredAt: json['answeredAt'] == null
          ? null
          : DateTime.tryParse(json['answeredAt'].toString())?.toLocal(),
      endedAt: json['endedAt'] == null ? null : DateTime.tryParse(json['endedAt'].toString())?.toLocal(),
      duration: json['duration'] is num ? (json['duration'] as num).toInt() : 0,
      direction: (json['direction'] ?? 'outgoing').toString(),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'].toString())?.toLocal(),
    );
  }

  CallSession copyWith({User? peer, CallStatus? status}) => CallSession(
        id: id,
        callerId: callerId,
        receiverIds: receiverIds,
        callType: callType,
        status: status ?? this.status,
        conversationId: conversationId,
        startedAt: startedAt,
        answeredAt: answeredAt,
        endedAt: endedAt,
        duration: duration,
        peer: peer ?? this.peer,
        direction: direction,
        createdAt: createdAt,
      );
}

