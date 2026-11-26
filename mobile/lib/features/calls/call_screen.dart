import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/miyu_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/call_provider.dart';
import '../../shared/widgets/miyu_avatar.dart';

/// Full-screen call experience. Distinct layouts for voice and video, with a
/// shared ring/connecting/active/ended state machine driven by CallController.
class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
  }


  @override
  Widget build(BuildContext context) {
    final state = ref.watch(callControllerProvider);
    final controller = ref.read(callControllerProvider.notifier);
    final peer = state.peer;

    ref.listen<CallState>(callControllerProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error && _isLivePhase(next.phase)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), duration: const Duration(seconds: 2)),
        );
      }
      if (next.phase == CallPhase.ended || next.phase == CallPhase.failed) {
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (!mounted) return;
          controller.reset();
          if (context.canPop()) context.pop();
        });
      }
    });

    if (state.phase == CallPhase.idle) {
      return const SizedBox.shrink();
    }

    final isVideoActive = state.isVideo && state.phase != CallPhase.incomingRinging;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (isVideoActive && state.remoteRenderer != null)
            RTCVideoView(
              state.remoteRenderer!,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              mirror: false,
            )
          else
            _GradientBackdrop(seed: peer?.id ?? state.call?.id ?? 'miyu'),
          if (isVideoActive && state.remoteRenderer != null)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.72),
                  ],
                  stops: const [0, 0.28, 0.62, 1],
                ),
              ),
            ),
          SafeArea(
            child: Column(
              children: [
                _CallHeader(state: state),
                const Spacer(),
                if (!isVideoActive) _VoiceHero(state: state),
                const Spacer(),
                _CallStatus(state: state),
                const SizedBox(height: 26),
                _CallControls(state: state),
                const SizedBox(height: 36),
              ],
            ),
          ),
          if (isVideoActive && state.localRenderer != null)
            Positioned(
              right: 16,
              top: MediaQuery.of(context).padding.top + 70,
              child: _LocalPreview(
                renderer: state.localRenderer!,
                cameraOff: state.isCameraOff,
                mirror: state.isFrontCamera,
              ),
            ),
        ],
      ),
    );
  }
}

bool _isLivePhase(CallPhase phase) =>
    phase == CallPhase.outgoingRinging ||
    phase == CallPhase.incomingRinging ||
    phase == CallPhase.connecting ||
    phase == CallPhase.active;

class _GradientBackdrop extends StatelessWidget {
  const _GradientBackdrop({required this.seed});

  final String seed;

  @override
  Widget build(BuildContext context) {
    final color = MiyuColors.avatarColorFor(seed);
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF0B0B0F)),
        Positioned(
          top: -120,
          left: -80,
          child: _Orb(color: color.withValues(alpha: 0.55), size: 360),
        ),
        Positioned(
          bottom: -140,
          right: -100,
          child: _Orb(color: MiyuColors.accentDeep.withValues(alpha: 0.42), size: 380),
        ),
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

class _CallHeader extends StatelessWidget {
  const _CallHeader({required this.state});

  final CallState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                ),
                child: Row(
                  children: [
                    Icon(
                      state.isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                      size: 13,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      state.isVideo ? 'Miyu Video' : 'Miyu Voice',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          if (state.phase == CallPhase.connecting)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VoiceHero extends StatelessWidget {
  const _VoiceHero({required this.state});

  final CallState state;

  @override
  Widget build(BuildContext context) {
    final peer = state.peer;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PulseRing(
          active: state.phase == CallPhase.outgoingRinging || state.phase == CallPhase.incomingRinging,
          child: MiyuAvatar(
            name: peer?.displayName ?? 'Miyu',
            imageUrl: peer?.photoURL,
            size: 132,
            seed: peer?.id,
          ),
        ),
        const SizedBox(height: 26),
        Text(
          peer?.displayName ?? 'Miyu user',
          style: const TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
            color: Colors.white,
          ),
        ),
        if (peer != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '@${peer.username}',
              style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.55)),
            ),
          ),
      ],
    );
  }
}

class _PulseRing extends StatelessWidget {
  const _PulseRing({required this.child, required this.active});

  final Widget child;
  final bool active;

  @override
  Widget build(BuildContext context) {
    if (!active) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1800),
      onEnd: () {},
      builder: (context, value, _) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 180 + value * 60,
              height: 180 + value * 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: (1 - value) * 0.35),
                  width: 2,
                ),
              ),
            ),
            Container(
              width: 170 + value * 40,
              height: 170 + value * 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: MiyuColors.accent.withValues(alpha: (1 - value) * 0.18),
              ),
            ),
            child,
          ],
        );
      },
    );
  }
}

class _LocalPreview extends StatelessWidget {
  const _LocalPreview({
    required this.renderer,
    required this.cameraOff,
    required this.mirror,
  });

  final RTCVideoRenderer renderer;
  final bool cameraOff;
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: RTCVideoView(renderer, mirror: mirror),
            ),
          ),
        ),
      ),
      child: Container(
        width: 100,
        height: 140,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: cameraOff
            ? Container(
                color: const Color(0xFF1A1A24),
                child: const Icon(Icons.videocam_off_rounded, color: Colors.white54),
              )
            : RTCVideoView(renderer, mirror: mirror, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
      ),
    );
  }
}

class _CallStatus extends StatelessWidget {
  const _CallStatus({required this.state});

  final CallState state;

  @override
  Widget build(BuildContext context) {
    String text;
    Color color = Colors.white.withValues(alpha: 0.72);
    switch (state.phase) {
      case CallPhase.outgoingRinging:
        text = 'Ringing…';
        break;
      case CallPhase.incomingRinging:
        text = state.isVideo ? 'Incoming video call' : 'Incoming voice call';
        color = Colors.white;
        break;
      case CallPhase.connecting:
        text = 'Connecting…';
        break;
      case CallPhase.active:
        text = Formatters.callDuration(state.duration);
        break;
      case CallPhase.ended:
        text = state.error ?? 'Call ended';
        break;
      case CallPhase.failed:
        text = state.error ?? 'Call failed';
        color = MiyuColors.coral;
        break;
      case CallPhase.idle:
        text = '';
        break;
    }

    return Column(
      children: [
        if (state.phase == CallPhase.active)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(right: 8),
                decoration: const BoxDecoration(
                  color: MiyuColors.mint,
                  shape: BoxShape.circle,
                ),
              ),
              Text(
                'Connected · $text',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          )
        else
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        if (state.phase == CallPhase.incomingRinging && state.peer != null) ...[
          const SizedBox(height: 10),
          Text(
            state.peer!.displayName,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ],
      ],
    );
  }
}

class _CallControls extends ConsumerWidget {
  const _CallControls({required this.state});

  final CallState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(callControllerProvider.notifier);
    final incoming = state.phase == CallPhase.incomingRinging;
    final showInCallControls =
        state.phase == CallPhase.active || state.phase == CallPhase.connecting;

    if (incoming) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _RoundButton(
              icon: Icons.call_end_rounded,
              label: 'Decline',
              background: MiyuColors.coral,
              onTap: controller.rejectCall,
              size: 68,
            ),
            _RoundButton(
              icon: state.isVideo ? Icons.videocam_rounded : Icons.call_rounded,
              label: 'Accept',
              background: MiyuColors.mint,
              onTap: controller.acceptCall,
              size: 68,
            ),
          ],
        ),
      );
    }

    if (state.phase == CallPhase.ended || state.phase == CallPhase.failed) {
      return const SizedBox(height: 68);
    }

    return Column(
      children: [
        if (showInCallControls)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _GlassToggle(
                  icon: state.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  label: state.isMuted ? 'Unmute' : 'Mute',
                  active: state.isMuted,
                  onTap: controller.toggleMute,
                ),
                _GlassToggle(
                  icon: state.isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                  label: 'Speaker',
                  active: state.isSpeakerOn,
                  onTap: controller.toggleSpeaker,
                ),
                if (state.isVideo) ...[
                  _GlassToggle(
                    icon: state.isCameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                    label: 'Camera',
                    active: !state.isCameraOff,
                    onTap: controller.toggleCamera,
                  ),
                  _GlassToggle(
                    icon: Icons.cameraswitch_rounded,
                    label: 'Flip',
                    active: false,
                    onTap: controller.switchCamera,
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 26),
        _RoundButton(
          icon: Icons.call_end_rounded,
          label: 'End',
          background: MiyuColors.coral,
          onTap: controller.hangup,
          size: 66,
        ),
      ],
    );
  }
}

class _GlassToggle extends StatelessWidget {
  const _GlassToggle({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Material(
              color: active ? Colors.white : Colors.white.withValues(alpha: 0.12),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: SizedBox(
                  width: 54,
                  height: 54,
                  child: Icon(
                    icon,
                    size: 23,
                    color: active ? Colors.black87 : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          label,
          style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.7)),
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.background,
    required this.onTap,
    this.size = 60,
  });

  final IconData icon;
  final String label;
  final Color background;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: background,
          shape: const CircleBorder(),
          elevation: 10,
          shadowColor: background.withValues(alpha: 0.5),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, color: Colors.white, size: size * 0.44),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7)),
        ),
      ],
    );
  }
}
