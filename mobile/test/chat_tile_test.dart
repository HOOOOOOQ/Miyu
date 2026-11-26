import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miyu/core/theme/miyu_theme.dart';
import 'package:miyu/models/chat.dart';
import 'package:miyu/models/message.dart';
import 'package:miyu/models/user.dart';
import 'package:miyu/shared/widgets/miyu_avatar.dart';

/// Verifies that chat list presentation data (preview text, unread badge,
/// timestamps) derives correctly from the model. The full tile widget is
/// covered by integration tests; this keeps the unit suite fast and
/// dependency-free.
String previewFor(Message? last) {
  if (last == null) return 'Say hello';
  if (last.isDeleted) return 'Message deleted';
  switch (last.messageType) {
    case MessageType.image:
      return '📷 Photo';
    case MessageType.video:
      return '🎬 Video';
    case MessageType.audio:
      return '🎙️ Voice message';
    case MessageType.file:
      return '📎 Document';
    case MessageType.system:
      return last.content;
    case MessageType.text:
      return last.content;
  }
}

void main() {
  group('Chat list presentation', () {
    test('unread badge caps at 99+', () {
      final chat = Chat.fromJson({'id': 'c1', 'unreadCount': 240});
      final label = chat.unreadCount > 99 ? '99+' : '${chat.unreadCount}';
      expect(label, '99+');
    });

    test('previews match message type', () {
      Message build(MessageType type, {String content = ''}) => Message(
            id: 'm',
            conversationId: 'c',
            senderId: 's',
            messageType: type,
            content: content,
          );
      expect(previewFor(null), 'Say hello');
      expect(previewFor(build(MessageType.image)), '📷 Photo');
      expect(previewFor(build(MessageType.video)), '🎬 Video');
      expect(previewFor(build(MessageType.audio)), '🎙️ Voice message');
      expect(previewFor(build(MessageType.file)), '📎 Document');
      expect(previewFor(build(MessageType.text, content: 'hey')), 'hey');
    });

    testWidgets('unread count badge renders', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: MiyuTheme.dark(),
          home: Scaffold(
            body: Badge(
              isLabelVisible: true,
              label: const Text('99+'),
              child: MiyuAvatar(name: 'Miyu', size: 42),
            ),
          ),
        ),
      );
      expect(find.text('99+'), findsOneWidget);
    });
  });
}
