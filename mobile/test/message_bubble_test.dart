import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miyu/core/theme/miyu_theme.dart';
import 'package:miyu/models/message.dart';
import 'package:miyu/models/user.dart';
import 'package:miyu/shared/widgets/miyu_avatar.dart';

import 'message_bubble_harness.dart';

Message sampleMessage({
  String id = 'm1',
  String senderId = 'me',
  MessageType type = MessageType.text,
  String content = 'Hello there',
  bool isDeleted = false,
  SendState sendState = SendState.sent,
  List<String> readBy = const ['me'],
}) =>
    Message(
      id: id,
      conversationId: 'c1',
      senderId: senderId,
      messageType: type,
      content: content,
      isDeleted: isDeleted,
      sendState: sendState,
      readBy: readBy,
      deliveredTo: readBy,
      createdAt: DateTime(2026, 5, 4, 9, 30),
      sender: User(
        id: senderId,
        displayName: senderId == 'me' ? 'Me' : 'Ayu',
        username: senderId,
      ),
    );

Widget host(Widget child) => MaterialApp(
      theme: MiyuTheme.dark(),
      home: Scaffold(body: child),
    );

void main() {
  group('Message list rendering', () {
    testWidgets('renders a text bubble with content and time', (tester) async {
      await tester.pumpWidget(host(MessageBubbleHarness(message: sampleMessage())));
      expect(find.text('Hello there'), findsOneWidget);
      expect(find.text('09:30'), findsOneWidget);
    });

    testWidgets('shows edited marker', (tester) async {
      final edited = sampleMessage().copyWith(editedAt: DateTime(2026, 5, 4, 9, 35));
      await tester.pumpWidget(host(MessageBubbleHarness(message: edited)));
      expect(find.text('edited'), findsOneWidget);
    });

    testWidgets('renders deleted placeholder without content', (tester) async {
      await tester.pumpWidget(host(MessageBubbleHarness(message: sampleMessage(isDeleted: true))));
      expect(find.text('This message was deleted'), findsOneWidget);
      expect(find.text('Hello there'), findsNothing);
    });

    testWidgets('renders voice duration', (tester) async {
      final voice = sampleMessage(type: MessageType.audio);
      await tester.pumpWidget(host(MessageBubbleHarness(message: voice)));
      expect(find.text('00:01'), findsOneWidget);
    });

    testWidgets('renders document name', (tester) async {
      final doc = Message(
        id: 'f1',
        conversationId: 'c1',
        senderId: 'me',
        messageType: MessageType.file,
        content: '',
        mediaUrl: 'https://example.com/x.pdf',
        mediaMeta: const MediaMeta(fileName: 'brief.pdf', fileSize: 2048),
        createdAt: DateTime(2026, 5, 4, 9, 30),
      );
      await tester.pumpWidget(host(MessageBubbleHarness(message: doc)));
      expect(find.text('brief.pdf'), findsOneWidget);
      expect(find.text('2.0 KB'), findsOneWidget);
    });

    testWidgets('renders reply preview', (tester) async {
      final original = Message(
        id: 'm0',
        conversationId: 'c1',
        senderId: 'me',
        messageType: MessageType.text,
        content: 'Original line',
        createdAt: DateTime(2026, 5, 4, 9, 29),
      );
      final reply = Message(
        id: 'm2',
        conversationId: 'c1',
        senderId: 'peer',
        messageType: MessageType.text,
        content: 'Replying now',
        replyToPreview: original,
        createdAt: DateTime(2026, 5, 4, 9, 31),
      );
      await tester.pumpWidget(host(MessageBubbleHarness(message: reply, currentUserId: 'me')));
      expect(find.text('Original line'), findsOneWidget);
      expect(find.text('Replying now'), findsOneWidget);
    });

    testWidgets('renders forwarded marker', (tester) async {
      final forwarded = Message(
        id: 'm3',
        conversationId: 'c1',
        senderId: 'me',
        messageType: MessageType.text,
        content: 'Shared',
        forwardedFrom: 'm1',
        createdAt: DateTime(2026, 5, 4, 9, 30),
      );
      await tester.pumpWidget(host(MessageBubbleHarness(message: forwarded)));
      expect(find.text('Forwarded'), findsOneWidget);
    });

    testWidgets('renders reaction chips', (tester) async {
      final reacted = sampleMessage().copyWith(reactions: const [
        MessageReaction(userId: 'peer', emoji: '🔥'),
        MessageReaction(userId: 'me', emoji: '🔥'),
      ]);
      await tester.pumpWidget(host(MessageBubbleHarness(message: reacted)));
      expect(find.text('🔥'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('system messages render as centered notices', (tester) async {
      final system = sampleMessage(
        type: MessageType.system,
        content: 'created the group "Crew"',
        senderId: 'me',
      );
      await tester.pumpWidget(host(MessageBubbleHarness(message: system)));
      expect(find.text('Me created the group "Crew"'), findsOneWidget);
    });

    testWidgets('avatar falls back to initials', (tester) async {
      await tester.pumpWidget(host(const MiyuAvatar(name: 'Ayu Putri', size: 44)));
      expect(find.text('AP'), findsOneWidget);
    });
  });
}
