import 'package:flutter_test/flutter_test.dart';
import 'package:miyu/models/call.dart';
import 'package:miyu/models/chat.dart';
import 'package:miyu/models/message.dart';
import 'package:miyu/models/user.dart';

void main() {
  group('User model', () {
    test('parses a full API payload', () {
      final user = User.fromJson({
        'id': 'u1',
        'displayName': 'Miyu Tester',
        'username': 'miyutester',
        'email': 'test@example.com',
        'photoURL': 'https://example.com/a.jpg',
        'bio': 'hello',
        'isOnline': true,
        'lastSeen': '2026-01-01T10:00:00.000Z',
      });
      expect(user.id, 'u1');
      expect(user.isOnline, isTrue);
      expect(user.bio, 'hello');
      expect(user.lastSeen, isNotNull);
    });

    test('defaults when fields are missing', () {
      final user = User.fromJson({});
      expect(user.displayName, isNotEmpty);
      expect(user.isOnline, isFalse);
      expect(user.showOnlineStatus, isTrue);
    });

    test('copyWith preserves immutable identity', () {
      const user = User(id: 'u1', displayName: 'A', username: 'a');
      final updated = user.copyWith(displayName: 'B', isOnline: true);
      expect(updated.id, 'u1');
      expect(updated.displayName, 'B');
      expect(updated.isOnline, isTrue);
      expect(user.displayName, 'A');
    });
  });

  group('Message model', () {
    Message build({String senderId = 'me', List<String> readBy = const []}) => Message(
          id: 'm1',
          conversationId: 'c1',
          senderId: senderId,
          messageType: MessageType.text,
          content: 'hi',
          readBy: readBy,
          createdAt: DateTime.now(),
        );

    test('parses message types', () {
      expect(messageTypeFromString('image'), MessageType.image);
      expect(messageTypeFromString('video'), MessageType.video);
      expect(messageTypeFromString('audio'), MessageType.audio);
      expect(messageTypeFromString('file'), MessageType.file);
      expect(messageTypeFromString('system'), MessageType.system);
      expect(messageTypeFromString('unknown'), MessageType.text);
    });

    test('round-trips message type strings', () {
      for (final type in MessageType.values) {
        expect(messageTypeFromString(messageTypeToString(type)), type);
      }
    });

    test('detects read receipts from other users', () {
      expect(build(readBy: ['other']).isReadByOther('me'), isTrue);
      expect(build(readBy: ['me']).isReadByOther('me'), isFalse);
      expect(build(readBy: []).isReadByOther('me'), isFalse);
    });

    test('aggregates reactions by emoji', () {
      final message = build().copyWith(reactions: const [
        MessageReaction(userId: 'a', emoji: '👍'),
        MessageReaction(userId: 'b', emoji: '👍'),
        MessageReaction(userId: 'c', emoji: '❤️'),
      ]);
      expect(message.reactionSummary['👍'], 2);
      expect(message.reactionSummary['❤️'], 1);
      expect(message.myReaction('b'), '👍');
      expect(message.myReaction('z'), isNull);
    });

    test('parses server payload including reply preview', () {
      final message = Message.fromJson({
        'id': 'm2',
        'conversationId': 'c1',
        'senderId': 's1',
        'messageType': 'text',
        'content': 'reply',
        'replyTo': 'm1',
        'replyToPreview': {
          'id': 'm1',
          'conversationId': 'c1',
          'senderId': 's2',
          'messageType': 'text',
          'content': 'original',
        },
        'createdAt': '2026-01-01T10:00:00.000Z',
      });
      expect(message.replyToPreview?.content, 'original');
      expect(message.messageType, MessageType.text);
    });
  });

  group('Chat model', () {
    test('resolves the direct-chat peer from profiles', () {
      final chat = Chat.fromJson({
        'id': 'c1',
        'conversationType': 'direct',
        'participants': ['me', 'peer'],
        'peerId': 'peer',
        'participantProfiles': [
          {'id': 'peer', 'displayName': 'Peer', 'username': 'peer', 'isOnline': true},
        ],
        'unreadCount': 3,
        'pinned': true,
      });
      expect(chat.peer?.displayName, 'Peer');
      expect(chat.peerIsOnline, isTrue);
      expect(chat.unreadCount, 3);
      expect(chat.pinned, isTrue);
      expect(chat.isGroup, isFalse);
    });

    test('uses the group name for group chats', () {
      final chat = Chat.fromJson({
        'id': 'c2',
        'conversationType': 'group',
        'group': {'id': 'g1', 'name': 'Crew', 'members': ['a', 'b'], 'owner': 'a'},
      });
      expect(chat.isGroup, isTrue);
      expect(chat.title, 'Crew');
      expect(chat.peer, isNull);
    });
  });

  group('Call model', () {
    test('parses incoming missed calls', () {
      final call = CallSession.fromJson({
        'id': 'call1',
        'callerId': 'peer',
        'receiverIds': ['me'],
        'callType': 'video',
        'status': 'cancelled',
        'direction': 'incoming',
      });
      expect(call.isVideo, isTrue);
      expect(call.isMissed, isTrue);
      expect(call.otherUserId, 'peer');
    });

    test('parses completed calls with duration', () {
      final call = CallSession.fromJson({
        'id': 'call2',
        'callerId': 'me',
        'receiverIds': ['peer'],
        'callType': 'voice',
        'status': 'ended',
        'duration': 93,
      });
      expect(call.isVideo, isFalse);
      expect(call.duration, 93);
      expect(call.isActive, isFalse);
    });
  });
}
