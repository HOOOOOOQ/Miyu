import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/miyu_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/message.dart';
import '../../../shared/widgets/miyu_avatar.dart';

/// Single message bubble handling every message type, reactions, receipts,
/// replies, forwarding and deletion states.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.currentUserId,
    required this.showAvatar,
    this.showSenderName = false,
    this.onLongPress,
    this.onDoubleTap,
    this.onReactionTap,
    this.onRetry,
    this.onMediaTap,
    this.highlighted = false,
  });

  final Message message;
  final bool isMine;
  final String? currentUserId;
  final bool showAvatar;
  final bool showSenderName;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;
  final ValueChanged<String>? onReactionTap;
  final VoidCallback? onRetry;
  final VoidCallback? onMediaTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    if (message.messageType == MessageType.system) {
      return _SystemMessage(message: message);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Uses the shared helper so the cap matches other responsive widgets.
    final maxWidth = math.min(MediaQuery.of(context).size.width * 0.74, 520.0);
    final reactions = message.reactionSummary;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isMine ? 18 : 6),
      bottomRight: Radius.circular(isMine ? 6 : 18),
    );

    return Padding(
      padding: EdgeInsets.only(
        left: isMine ? 46 : 12,
        right: isMine ? 12 : 28,
        top: 2,
        bottom: reactions.isEmpty ? 2 : 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMine)
            SizedBox(
              width: 34,
              child: showAvatar && message.sender != null
                  ? MiyuAvatar(
                      name: message.sender!.displayName,
                      imageUrl: message.sender!.photoURL,
                      size: 30,
                      seed: message.sender!.id,
                    )
                  : const SizedBox.shrink(),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (showSenderName && !isMine && message.sender != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 6, bottom: 3),
                    child: Text(
                      message.sender!.displayName,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: MiyuColors.avatarColorFor(message.sender!.id),
                      ),
                    ),
                  ),
                GestureDetector(
                  onLongPress: onLongPress,
                  onDoubleTap: onDoubleTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    decoration: BoxDecoration(
                      gradient: isMine
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF8B7CFF), Color(0xFF6C5CE7)],
                            )
                          : null,
                      color: isMine ? null : (isDark ? MiyuColors.darkElevated : Colors.white),
                      borderRadius: radius,
                      border: isMine
                          ? null
                          : Border.all(
                              color: highlighted
                                  ? MiyuColors.accent
                                  : (isDark ? MiyuColors.darkBorder : MiyuColors.lightBorder),
                              width: highlighted ? 1.4 : 0.8,
                            ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: radius,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (message.isDeleted)
                            _DeletedBody(isMine: isMine)
                          else ...[
                            if (message.replyToPreview != null)
                              _ReplyPreview(reply: message.replyToPreview!, isMine: isMine),
                            _MessageBody(
                              message: message,
                              isMine: isMine,
                              onMediaTap: onMediaTap,
                              onRetry: onRetry,
                            ),
                            if (message.forwardedFrom != null)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.forward_rounded,
                                      size: 11,
                                      color: isMine
                                          ? Colors.white70
                                          : (isDark
                                              ? MiyuColors.darkTextSecondary
                                              : MiyuColors.lightTextSecondary),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Forwarded',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontStyle: FontStyle.italic,
                                        color: isMine
                                            ? Colors.white70
                                            : (isDark
                                                ? MiyuColors.darkTextSecondary
                                                : MiyuColors.lightTextSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            _MetaRow(
                              message: message,
                              isMine: isMine,
                              currentUserId: currentUserId,
                              onRetry: onRetry,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (reactions.isNotEmpty)
                  Transform.translate(
                    offset: const Offset(0, -6),
                    child: Wrap(
                      spacing: 4,
                      children: reactions.entries.map((entry) {
                        final mine = message.myReaction(currentUserId) == entry.key;
                        return GestureDetector(
                          onTap: () => onReactionTap?.call(entry.key),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? MiyuColors.darkSurface : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: mine
                                    ? MiyuColors.accent
                                    : (isDark ? MiyuColors.darkBorder : MiyuColors.lightBorder),
                                width: mine ? 1.2 : 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(entry.key, style: const TextStyle(fontSize: 12)),
                                if (entry.value > 1) ...[
                                  const SizedBox(width: 3),
                                  Text(
                                    '${entry.value}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? MiyuColors.darkTextSecondary
                                          : MiyuColors.lightTextSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
          if (isMine) const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _MessageBody extends StatelessWidget {
  const _MessageBody({
    required this.message,
    required this.isMine,
    this.onMediaTap,
    this.onRetry,
  });

  final Message message;
  final bool isMine;
  final VoidCallback? onMediaTap;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    switch (message.messageType) {
      case MessageType.image:
        return _ImageBody(message: message, isMine: isMine, onTap: onMediaTap);
      case MessageType.video:
        return _FileLikeBody(
          message: message,
          isMine: isMine,
          icon: Icons.play_circle_fill_rounded,
          label: 'Video',
          subtitle: Formatters.fileSize(message.mediaMeta?.fileSize),
          onTap: onMediaTap,
        );
      case MessageType.audio:
        return _AudioBody(message: message, isMine: isMine, onTap: onMediaTap);
      case MessageType.file:
        return _FileLikeBody(
          message: message,
          isMine: isMine,
          icon: Icons.insert_drive_file_rounded,
          label: message.mediaMeta?.fileName ?? 'Document',
          subtitle: Formatters.fileSize(message.mediaMeta?.fileSize),
          onTap: onMediaTap,
        );
      case MessageType.text:
      case MessageType.system:
        return Padding(
          padding: const EdgeInsets.fromLTRB(13, 8, 13, 2),
          child: Text(
            message.content,
            style: TextStyle(fontSize: 15, height: 1.35, color: isMine ? Colors.white : null),
          ),
        );
    }
  }
}

class _ImageBody extends StatelessWidget {
  const _ImageBody({required this.message, required this.isMine, this.onTap});

  final Message message;
  final bool isMine;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final aspect = (message.mediaMeta?.width != null && message.mediaMeta?.height != null)
        ? (message.mediaMeta!.width! / message.mediaMeta!.height!).clamp(0.55, 1.8)
        : 1.2;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: aspect.toDouble(),
            child: message.localFileUri != null
                ? Image.file(File(message.localFileUri!), fit: BoxFit.cover)
                : CachedNetworkImage(
                    imageUrl: message.mediaUrl ?? '',
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: isMine ? Colors.white12 : Colors.black12,
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: isMine ? Colors.white10 : Colors.black12,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: isMine ? Colors.white70 : Colors.grey,
                      ),
                    ),
                  ),
          ),
          if (message.sendState == SendState.sending)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.35),
                child: Center(
                  child: SizedBox(
                    width: 34,
                    height: 34,
                    child: CircularProgressIndicator(
                      value: message.uploadProgress >= 1 ? null : message.uploadProgress,
                      strokeWidth: 2.5,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FileLikeBody extends StatelessWidget {
  const _FileLikeBody({
    required this.message,
    required this.isMine,
    required this.icon,
    required this.label,
    this.subtitle,
    this.onTap,
  });

  final Message message;
  final bool isMine;
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 14, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isMine
                    ? Colors.white.withValues(alpha: 0.18)
                    : MiyuColors.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: isMine ? Colors.white : MiyuColors.accent, size: 22),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isMine ? Colors.white : null,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 11,
                        color: isMine ? Colors.white70 : Colors.grey,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioBody extends StatelessWidget {
  const _AudioBody({required this.message, required this.isMine, this.onTap});

  final Message message;
  final bool isMine;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final seconds = (message.mediaMeta?.duration ?? 0).round();
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 16, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.play_arrow_rounded,
              color: isMine ? Colors.white : MiyuColors.accent,
              size: 22,
            ),
            const SizedBox(width: 6),
            _Waveform(isMine: isMine),
            const SizedBox(width: 8),
            Text(
              Formatters.callDurationFromSeconds(seconds <= 0 ? 1 : seconds),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isMine ? Colors.white70 : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform({required this.isMine});

  final bool isMine;

  @override
  Widget build(BuildContext context) {
    const heights = [6.0, 12.0, 8.0, 16.0, 10.0, 18.0, 7.0, 13.0, 9.0, 15.0, 6.0, 11.0];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: heights
          .map((height) => Container(
                width: 2.4,
                height: height,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: (isMine ? Colors.white : MiyuColors.accent).withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ))
          .toList(),
    );
  }
}

class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({required this.reply, required this.isMine});

  final Message reply;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final previewText = reply.isDeleted
        ? 'Deleted message'
        : reply.messageType == MessageType.text
            ? reply.content
            : reply.messageType == MessageType.image
                ? 'Photo'
                : reply.messageType == MessageType.audio
                    ? 'Voice message'
                    : 'Attachment';
    return Container(
      margin: const EdgeInsets.fromLTRB(6, 6, 6, 0),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: isMine
            ? Colors.white.withValues(alpha: 0.16)
            : MiyuColors.accent.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: isMine ? Colors.white : MiyuColors.accent, width: 2.5),
        ),
      ),
      child: Text(
        previewText,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11.8,
          height: 1.3,
          color: isMine ? Colors.white.withValues(alpha: 0.85) : null,
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.message,
    required this.isMine,
    required this.currentUserId,
    this.onRetry,
  });

  final Message message;
  final bool isMine;
  final String? currentUserId;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isMine
        ? Colors.white.withValues(alpha: 0.72)
        : (isDark ? MiyuColors.darkTextSecondary : MiyuColors.lightTextSecondary);

    IconData? receiptIcon;
    Color? receiptColor;
    if (isMine) {
      if (message.sendState == SendState.sending) {
        receiptIcon = Icons.schedule_rounded;
      } else if (message.sendState == SendState.failed) {
        receiptIcon = Icons.error_outline_rounded;
        receiptColor = MiyuColors.coral;
      } else if (message.isReadByOther(currentUserId ?? '')) {
        receiptIcon = Icons.done_all_rounded;
        receiptColor = const Color(0xFFB9F5D0);
      } else if (message.isDeliveredToOther(currentUserId ?? '')) {
        receiptIcon = Icons.done_all_rounded;
      } else {
        receiptIcon = Icons.done_rounded;
      }
    }

    final textInsets = message.messageType == MessageType.text;

    return Padding(
      padding: EdgeInsets.fromLTRB(textInsets ? 13 : 10, 0, textInsets ? 10 : 8, textInsets ? 5 : 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (message.isEdited) ...[
            Text('edited', style: TextStyle(fontSize: 9.5, color: mutedColor)),
            const SizedBox(width: 4),
          ],
          Text(
            Formatters.messageTime(message.createdAt),
            style: TextStyle(fontSize: 9.5, color: mutedColor),
          ),
          if (receiptIcon != null) ...[
            const SizedBox(width: 3),
            if (message.sendState == SendState.failed && onRetry != null)
              GestureDetector(
                onTap: onRetry,
                child: Icon(receiptIcon, size: 14, color: receiptColor ?? mutedColor),
              )
            else
              Icon(receiptIcon, size: 13, color: receiptColor ?? mutedColor),
          ],
        ],
      ),
    );
  }
}

class _DeletedBody extends StatelessWidget {
  const _DeletedBody({required this.isMine});

  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 9, 13, 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.block_rounded, size: 13, color: isMine ? Colors.white60 : Colors.grey),
          const SizedBox(width: 5),
          Text(
            'This message was deleted',
            style: TextStyle(
              fontSize: 12.5,
              fontStyle: FontStyle.italic,
              color: isMine ? Colors.white60 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemMessage extends StatelessWidget {
  const _SystemMessage({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sender = message.sender?.displayName;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 40),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? MiyuColors.darkElevated : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          sender == null ? message.content : '$sender ${message.content}',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11.5,
            color: isDark ? MiyuColors.darkTextSecondary : MiyuColors.lightTextSecondary,
          ),
        ),
      ),
    );
  }
}
