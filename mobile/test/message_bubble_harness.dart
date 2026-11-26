import 'package:flutter/material.dart';
import 'package:miyu/features/messages/widgets/message_bubble.dart';
import 'package:miyu/models/message.dart';

/// Minimal host so bubble rendering can be tested without a ProviderScope
/// or network access.
class MessageBubbleHarness extends StatelessWidget {
  const MessageBubbleHarness({
    super.key,
    required this.message,
    this.currentUserId = 'me',
  });

  final Message message;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    return MessageBubble(
      message: message,
      isMine: message.senderId == currentUserId,
      currentUserId: currentUserId,
      showAvatar: true,
    );
  }
}
