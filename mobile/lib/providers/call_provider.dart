import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../models/call.dart';
import '../models/user.dart';
import '../services/call_signaling_service.dart';
import '../services/socket_service.dart';
import 'core_providers.dart';

enum CallPhase {
  idle,
  outgoingRinging,
  incomingRinging,
  connecting,
  active,
  ended,
  failed,
}

class CallState {
  const CallState({
    this.phase = CallPhase.idle,
    this.call,
    this.peer,
    this.isMuted = false,
    this.isCameraOff = false,
    this.isFrontCamera = true,
    this.isSpeakerOn = false,
    this.duration = Duration.zero,
    this.error,
    this.localRenderer,
    this.remoteRenderer,
  });

  final CallPhase phase;
  final CallSession? call;
  final User? peer;
  final bool isMuted;
  final bool isCameraOff;
  final bool isFrontCamera;
  final bool isSpeakerOn;
  final Duration duration;
  final String? error;
  final RTCVideoRenderer? localRenderer;
  final RTCVideoRenderer? remoteRenderer;

  bool get isVideo => call?.callType == CallType.video;
  bool get isIncoming => phase == CallPhase.incomingRinging;
  bool get isConnecting => phase == CallPhase.connecting;
  bool get isActive => phase == CallPhase.active;
  bool get isRinging => phase == CallPhase.outgoingRinging || phase == CallPhase.incomingRinging;

  CallState copyWith({
    CallPhase? phase,
    CallSession? call,
    User? peer,
    bool? isMuted,
    bool? isCameraOff,
    bool? isFrontCamera,
    bool? isSpeakerOn,
    Duration? duration,
    String? error,
    bool clearError = false,
    RTCVideoRenderer? localRenderer,
    RTCVideoRenderer? remoteRenderer,
  }) {
    return CallState(
      phase: phase ?? this.phase,
      call: call ?? this.call,
      peer: peer ?? this.peer,
      isMuted: isMuted ?? this.isMuted,
      isCameraOff: isCameraOff ?? this.isCameraOff,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      duration: duration ?? this.duration,
      error: clearError ? null : (error ?? this.error),
      localRenderer: localRenderer ?? this.localRenderer,
      remoteRenderer: remoteRenderer ?? this.remoteRenderer,
    );
  }
}

/// Owns the complete call lifecycle: signalling, media, and UI state.
class CallController extends StateNotifier<CallState> {
  CallController({required Ref ref})
      : _ref = ref,
        super(const CallState());

  final Ref _ref;
  PeerConnectionManager? _peer;
  Timer? _durationTimer;
  Timer? _ringTimeout;
  bool _offerSent = false;
  bool _acceptedLocally = false;
  final Set<String> _presence = {};

  /// Exposed for tests and diagnostics.
  bool get offerSent => _offerSent;
  bool get acceptedLocally => _acceptedLocally;
  Set<String> get onlinePeers => Set.unmodifiable(_presence);

  SocketService get _socket => _ref.read(socketServiceProvider);

  void updatePresence(String userId, bool isOnline) {
    if (isOnline) {
      _presence.add(userId);
    } else {
      _presence.remove(userId);
    }
    if (isOnline && state.call != null && state.phase == CallPhase.outgoingRinging) {
      // Push ICE restart signalling as soon as the callee appears online.
      _ringTimeout?.cancel();
      _startRingTimeout();
    }
  }

  // ------------------------------------------------------------- outgoing
  Future<void> startCall({required User peer, required CallType callType, String? conversationId}) async {
    if (state.phase != CallPhase.idle) {
      state = state.copyWith(error: 'You are already in a call');
      return;
    }
    state = CallState(phase: CallPhase.outgoingRinging, peer: peer, isSpeakerOn: callType == CallType.video);
    try {
      final call = await _ref.read(chatRepositoryProvider).startCall(
            receiverId: peer.id,
            callType: callType,
            conversationId: conversationId,
          );
      state = state.copyWith(call: call, peer: peer, phase: CallPhase.outgoingRinging);
      await _prepareLocalMedia(callType == CallType.video);
      _startRingTimeout();
    } catch (error) {
      state = state.copyWith(phase: CallPhase.failed, error: 'Could not start the call. Try again.');
      await _cleanup();
    }
  }

  void _startRingTimeout() {
    _ringTimeout?.cancel();
    _ringTimeout = Timer(const Duration(seconds: 45), () async {
      if (state.phase != CallPhase.outgoingRinging) return;
      await _endCall(status: 'missed', silent: true);
      if (state.phase != CallPhase.idle) {
        state = state.copyWith(phase: CallPhase.ended, error: 'No answer');
      }
    });
  }

  Future<PeerConnectionManager?> _prepareLocalMedia(bool video) async {
    final peer = PeerConnectionManager(socket: _socket);
    _peer = peer;
    final localRenderer = RTCVideoRenderer();
    await localRenderer.initialize();
    final remoteRenderer = RTCVideoRenderer();
    await remoteRenderer.initialize();
    state = state.copyWith(localRenderer: localRenderer, remoteRenderer: remoteRenderer);

    try {
      final stream = await peer.openLocalStream(video: video);
      localRenderer.srcObject = stream;
      peer.remoteStreams.listen((remote) {
        remoteRenderer.srcObject = remote;
      });
      return peer;
    } catch (error) {
      state = state.copyWith(
        phase: CallPhase.failed,
        error: 'Camera and microphone permission are required for calls.',
      );
      await _cleanup();
      return null;
    }
  }

  // ------------------------------------------------------------- incoming
  void onIncomingCall(Map<String, dynamic> payload) {
    if (state.phase != CallPhase.idle) {
      final callId = (payload['call'] as Map?)?['id']?.toString();
      if (callId != null) {
        _socket.emit(SocketEvents.callBusy, {'callId': callId});
      }
      return;
    }
    final callJson = payload['call'];
    if (callJson is! Map) return;
    final callerJson = payload['caller'];
    final call = CallSession.fromJson(
      Map<String, dynamic>.from(callJson),
      peerId: callerJson is Map ? callerJson['id']?.toString() : null,
    ).copyWith(
      peer: callerJson is Map ? User.fromJson(Map<String, dynamic>.from(callerJson)) : null,
    );
    state = CallState(
      phase: CallPhase.incomingRinging,
      call: call,
      peer: call.peer,
      isSpeakerOn: false,
    );
    // Warm the microphone/camera up while ringing so the answer can be sent
    // the moment the user taps Accept. A denial surfaces on accept instead.
    unawaited(_prepareLocalMedia(call.callType == CallType.video));
    _ringTimeout?.cancel();
    _ringTimeout = Timer(const Duration(seconds: 45), () {
      if (state.phase == CallPhase.incomingRinging) unawaited(rejectCall());
    });
  }

  /// Called from an FCM tap when the app was backgrounded and the socket
  /// event was missed. Pulls authoritative state from the backend.
  Future<void> handlePushIncomingCall(String callId) async {
    if (state.phase != CallPhase.idle) return;
    try {
      final call = await _ref.read(chatRepositoryProvider).getCall(callId);
      if (call.isRinging) {
        state = CallState(phase: CallPhase.incomingRinging, call: call, peer: call.peer);
        unawaited(_prepareLocalMedia(call.callType == CallType.video));
      }
    } catch (_) {}
  }

  // ------------------------------------------------------------ answering
  Future<void> acceptCall() async {
    final call = state.call;
    if (call == null) return;
    state = state.copyWith(phase: CallPhase.connecting, clearError: true);
    _ringTimeout?.cancel();
    _acceptedLocally = true;
    try {
      await _ref.read(chatRepositoryProvider).acceptCall(call.id);
      // Media is prepared (or already warm from ringing) so the answer can
      // carry our tracks; the offer handler reuses this manager.
      var prepared = _peer;
      if (prepared == null || prepared.localStream == null) {
        prepared = await _prepareLocalMedia(call.callType == CallType.video);
      }
      if (prepared == null) return;
      _startDurationTimer();
    } catch (_) {
      state = state.copyWith(phase: CallPhase.failed, error: 'Could not answer the call.');
      await _cleanup();
    }
  }

  Future<void> rejectCall() async {
    final call = state.call;
    if (call == null) {
      state = const CallState();
      return;
    }
    _ringTimeout?.cancel();
    try {
      await _ref.read(chatRepositoryProvider).rejectCall(call.id);
    } catch (_) {}
    state = const CallState(phase: CallPhase.ended);
    await _cleanup();
  }

  Future<void> hangup() => _endCall(status: null);

  Future<void> _endCall({String? status, bool silent = false}) async {
    final call = state.call;
    _durationTimer?.cancel();
    _ringTimeout?.cancel();
    if (call != null && !silent) {
      try {
        await _ref.read(chatRepositoryProvider).endCall(call.id, status: status);
      } catch (_) {}
    }
    state = state.copyWith(phase: CallPhase.ended);
    await _cleanup();
  }

  // ------------------------------------------------------ remote handlers
  Future<void> onCallAccepted(Map<String, dynamic> payload) async {
    final call = state.call;
    if (call == null) return;
    final acceptedId = (payload['call'] as Map?)?['id']?.toString();
    if (acceptedId != null && acceptedId != call.id) return;
    if (state.phase != CallPhase.outgoingRinging && state.phase != CallPhase.connecting) return;
    state = state.copyWith(phase: CallPhase.connecting, clearError: true);
    _startDurationTimer();

    final peer = _peer;
    if (peer == null) return;
    try {
      // Tracks must be attached before the offer is created, otherwise the
      // SDP has no m-lines and the answer cannot be applied by the remote.
      final iceServers = await _ref.read(iceConfigProvider).getIceServers();
      await peer.initializePeerConnection(
        iceServers: iceServers,
        callId: call.id,
        isCaller: true,
      );
      final offer = await peer.createOffer();
      _socket.emit(SocketEvents.callOffer, {
        'callId': call.id,
        'sdp': {'sdp': offer.sdp, 'type': offer.type},
      });
      _offerSent = true;
    } catch (_) {
      state = state.copyWith(phase: CallPhase.failed, error: 'Could not establish the call.');
      await _cleanup();
      await _safeEnd(call.id);
    }
  }

  /// Best-effort server-side teardown used after local media failures so the
  /// other side never keeps ringing or shows a zombie call.
  Future<void> _safeEnd(String callId) async {
    try {
      await _ref.read(chatRepositoryProvider).endCall(callId);
    } catch (_) {}
  }

  void onCallRejected(Map<String, dynamic> payload) {
    _durationTimer?.cancel();
    _ringTimeout?.cancel();
    state = state.copyWith(phase: CallPhase.ended, error: 'Call declined');
    _cleanup();
  }

  void onRemoteCallEnded(Map<String, dynamic> payload) {
    _durationTimer?.cancel();
    _ringTimeout?.cancel();
    state = state.copyWith(phase: CallPhase.ended);
    _cleanup();
  }

  void onPeerBusy(Map<String, dynamic> payload) {
    _ringTimeout?.cancel();
    state = state.copyWith(phase: CallPhase.ended, error: 'User is on another call');
    _cleanup();
  }

  Future<void> onRemoteOffer(Map<String, dynamic> payload) async {
    final call = state.call;
    if (call == null) return;
    final sdp = payload['sdp'];
    if (sdp is! Map) return;
    if (_peer == null) {
      // Offer arrived before local media was prepared (e.g. cold start from a
      // push); set it up and retry once.
      final prepared = await _prepareLocalMedia(call.callType == CallType.video);
      if (prepared == null) return;
      return onRemoteOffer(payload);
    }
    final peer = _peer!;
    try {
      if (peer.state == RTCPeerConnectionState.RTCPeerConnectionStateNew) {
        if (peer.localStream == null) {
          // Accepted from a push tap: media was never prepared.
          final prepared = await _prepareLocalMedia(call.callType == CallType.video);
          if (prepared == null) return;
          return onRemoteOffer(payload);
        }
        final iceServers = await _ref.read(iceConfigProvider).getIceServers();
        await peer.initializePeerConnection(
          iceServers: iceServers,
          callId: call.id,
          isCaller: false,
        );
      }
      await peer.applyRemoteOffer(Map<String, dynamic>.from(sdp));
      final answer = await peer.createAnswer();
      _socket.emit(SocketEvents.callAnswer, {
        'callId': call.id,
        'sdp': {'sdp': answer.sdp, 'type': answer.type},
      });
      state = state.copyWith(phase: CallPhase.active);
    } catch (_) {
      state = state.copyWith(phase: CallPhase.failed, error: 'Media connection failed.');
      await _cleanup();
      await _safeEnd(call.id);
    }
  }

  Future<void> onRemoteAnswer(Map<String, dynamic> payload) async {
    final peer = _peer;
    final sdp = payload['sdp'];
    if (peer == null || sdp is! Map) return;
    try {
      await peer.applyRemoteAnswer(Map<String, dynamic>.from(sdp));
      state = state.copyWith(phase: CallPhase.active);
    } catch (_) {
      state = state.copyWith(phase: CallPhase.failed, error: 'Media connection failed.');
      await _cleanup();
      if (state.call != null) await _safeEnd(state.call!.id);
    }
  }

  Future<void> onRemoteIceCandidate(Map<String, dynamic> payload) async {
    final peer = _peer;
    final candidate = payload['candidate'];
    if (peer == null || candidate is! Map) return;
    try {
      await peer.addRemoteCandidate(Map<String, dynamic>.from(candidate));
    } catch (_) {}
  }

  // ------------------------------------------------------------- controls
  Future<void> toggleMute() async {
    final next = !state.isMuted;
    await _peer?.setMicrophoneEnabled(!next);
    state = state.copyWith(isMuted: next);
  }

  Future<void> toggleCamera() async {
    final next = !state.isCameraOff;
    // Turning the camera back on requires a video track; if the call was set
    // up audio-only we explain instead of showing a black preview.
    if (!next && state.call?.callType != CallType.video) {
      state = state.copyWith(error: 'This call has no video');
      return;
    }
    try {
      await _peer?.setCameraEnabled(!next);
      state = state.copyWith(isCameraOff: next);
    } catch (_) {
      state = state.copyWith(error: 'Camera is not available on this call');
    }
  }

  Future<void> switchCamera() async {
    await _peer?.switchCamera();
    state = state.copyWith(isFrontCamera: !state.isFrontCamera);
  }

  void toggleSpeaker() => state = state.copyWith(isSpeakerOn: !state.isSpeakerOn);

  void _startDurationTimer() {
    _durationTimer?.cancel();
    final startedAt = DateTime.now();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.phase == CallPhase.connecting || state.phase == CallPhase.active) {
        state = state.copyWith(duration: DateTime.now().difference(startedAt));
      } else {
        _durationTimer?.cancel();
      }
    });
  }

  Future<void> _cleanup() async {
    _durationTimer?.cancel();
    _ringTimeout?.cancel();
    _offerSent = false;
    _acceptedLocally = false;
    final local = state.localRenderer;
    final remote = state.remoteRenderer;
    await _peer?.close();
    _peer = null;
    local?.srcObject = null;
    remote?.srcObject = null;
    await local?.dispose();
    await remote?.dispose();
  }

  /// Clears terminal state back to idle (called when leaving the call screen).
  void reset() {
    if (state.phase == CallPhase.ended || state.phase == CallPhase.failed) {
      state = const CallState();
    }
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _ringTimeout?.cancel();
    _peer?.close();
    super.dispose();
  }
}

final callControllerProvider = StateNotifierProvider<CallController, CallState>((ref) {
  return CallController(ref: ref);
});
