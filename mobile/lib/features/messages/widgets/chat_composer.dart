import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/miyu_colors.dart';
import '../../../models/message.dart';

/// Glass input bar: attach, text, emoji, voice, send.
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.onSendText,
    required this.onPickImage,
    required this.onPickVideo,
    required this.onPickDocument,
    required this.onStartTyping,
    required this.onStopTyping,
    required this.onMicToggle,
    this.replyTo,
    this.editing,
    this.onCancelReply,
    this.onCancelEdit,
    this.isRecording = false,
    this.recordingDuration = Duration.zero,
    this.onStopRecording,
    this.onCancelRecording,
  });

  final ValueChanged<String> onSendText;
  final VoidCallback onPickImage;
  final VoidCallback onPickVideo;
  final VoidCallback onPickDocument;
  final VoidCallback onStartTyping;
  final VoidCallback onStopTyping;
  final VoidCallback onMicToggle;
  final Message? replyTo;
  final Message? editing;
  final VoidCallback? onCancelReply;
  final VoidCallback? onCancelEdit;
  final bool isRecording;
  final Duration recordingDuration;
  final VoidCallback? onStopRecording;
  final VoidCallback? onCancelRecording;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;
  bool _showAttach = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) widget.onStopTyping();
    });
  }

  @override
  void didUpdateWidget(covariant ChatComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editing != null && oldWidget.editing?.id != widget.editing?.id) {
      _controller.text = widget.editing!.content;
      _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
      _focusNode.requestFocus();
    }
    if (widget.editing == null && oldWidget.editing != null) {
      _controller.clear();
    }
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
    if (hasText) {
      widget.onStartTyping();
    } else {
      widget.onStopTyping();
    }
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    widget.onSendText(text);
    _controller.clear();
    widget.onStopTyping();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.isRecording) {
      return _RecordingBar(
        duration: widget.recordingDuration,
        onStop: widget.onStopRecording,
        onCancel: widget.onCancelRecording,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? MiyuColors.darkSurface.withValues(alpha: 0.94)
            : Colors.white.withValues(alpha: 0.96),
        border: Border(
          top: BorderSide(
            color: isDark ? MiyuColors.darkBorder : MiyuColors.lightBorder,
            width: 0.8,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.replyTo != null) _ContextBar.reply(reply: widget.replyTo!, onClose: widget.onCancelReply),
            if (widget.editing != null) _ContextBar.edit(message: widget.editing!, onClose: widget.onCancelEdit),
            if (_showAttach) _AttachTray(
              onImage: () {
                setState(() => _showAttach = false);
                widget.onPickImage();
              },
              onVideo: () {
                setState(() => _showAttach = false);
                widget.onPickVideo();
              },
              onDocument: () {
                setState(() => _showAttach = false);
                widget.onPickDocument();
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _CircleButton(
                    icon: _showAttach ? Icons.close_rounded : Icons.add_rounded,
                    onTap: () => setState(() => _showAttach = !_showAttach),
                    tooltip: 'Attach media',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 140),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        minLines: 1,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        keyboardType: TextInputType.multiline,
                        style: const TextStyle(fontSize: 15),
                        decoration: InputDecoration(
                          hintText: widget.editing != null ? 'Edit message…' : 'Message',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          filled: true,
                          fillColor: isDark ? MiyuColors.darkElevated : MiyuColors.lightElevated,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: const BorderSide(color: MiyuColors.accent, width: 1.2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                    child: _hasText || widget.editing != null
                        ? _SendButton(
                            editing: widget.editing != null,
                            onTap: _send,
                          )
                        : _CircleButton(
                            icon: Icons.mic_none_rounded,
                            onTap: widget.onMicToggle,
                            tooltip: 'Record voice message',
                            accent: true,
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

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.accent = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final button = Material(
      color: accent
          ? MiyuColors.accent
          : (isDark ? MiyuColors.darkElevated : MiyuColors.lightElevated),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            size: 23,
            color: accent ? Colors.white : (isDark ? Colors.white70 : Colors.black54),
          ),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.editing, required this.onTap});

  final bool editing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MiyuColors.accent,
      shape: const CircleBorder(),
      elevation: 6,
      shadowColor: MiyuColors.accent.withValues(alpha: 0.5),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            editing ? Icons.check_rounded : Icons.arrow_upward_rounded,
            size: 23,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _ContextBar extends StatelessWidget {
  const _ContextBar.reply({required this.reply, this.onClose})
      : editing = null,
        message = reply;

  const _ContextBar.edit({required this.editing, this.onClose})
      : reply = null,
        message = editing;

  final Message? reply;
  final Message? editing;
  final Message? message;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = editing != null;
    final target = message;
    final preview = isEditing
        ? target?.content ?? ''
        : target == null
            ? ''
            : target.messageType == MessageType.text
                ? target.content
                : target.messageType == MessageType.image
                    ? 'Photo'
                    : target.messageType == MessageType.audio
                        ? 'Voice message'
                        : 'Attachment';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      color: isDark
          ? MiyuColors.accent.withValues(alpha: 0.10)
          : MiyuColors.accent.withValues(alpha: 0.06),
      child: Row(
        children: [
          Icon(
            isEditing ? Icons.edit_rounded : Icons.reply_rounded,
            size: 18,
            color: MiyuColors.accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isEditing ? 'Editing message' : 'Replying to message',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: MiyuColors.accent,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _AttachTray extends StatelessWidget {
  const _AttachTray({required this.onImage, required this.onVideo, required this.onDocument});

  final VoidCallback onImage;
  final VoidCallback onVideo;
  final VoidCallback onDocument;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, (1 - value) * 12), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(
          children: [
            _AttachAction(icon: Icons.photo_rounded, label: 'Photo', onTap: onImage),
            const SizedBox(width: 22),
            _AttachAction(icon: Icons.videocam_rounded, label: 'Video', onTap: onVideo),
            const SizedBox(width: 22),
            _AttachAction(icon: Icons.attach_file_rounded, label: 'File', onTap: onDocument),
          ],
        ),
      ),
    );
  }
}

class _AttachAction extends StatelessWidget {
  const _AttachAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: MiyuColors.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: MiyuColors.accent, size: 24),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _RecordingBar extends StatelessWidget {
  const _RecordingBar({required this.duration, this.onStop, this.onCancel});

  final Duration duration;
  final VoidCallback? onStop;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final seconds = duration.inSeconds;
    final label = '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
        '${(seconds % 60).toString().padLeft(2, '0')}';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? MiyuColors.darkSurface : Colors.white,
        border: Border(
          top: BorderSide(color: isDark ? MiyuColors.darkBorder : MiyuColors.lightBorder, width: 0.8),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              onPressed: onCancel,
              icon: const Icon(Icons.delete_outline_rounded, color: MiyuColors.coral),
              tooltip: 'Cancel recording',
            ),
            const _PulsingDot(),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: _LiveWave()),
            const SizedBox(width: 12),
            Material(
              color: MiyuColors.accent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onStop,
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(Icons.stop_rounded, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0).animate(_controller),
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(color: MiyuColors.coral, shape: BoxShape.circle),
      ),
    );
  }
}

class _LiveWave extends StatelessWidget {
  const _LiveWave();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(14, (index) {
        final height = 6.0 + ((index * 7) % 20);
        return Container(
          width: 3,
          height: height,
          decoration: BoxDecoration(
            color: MiyuColors.accent.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}
