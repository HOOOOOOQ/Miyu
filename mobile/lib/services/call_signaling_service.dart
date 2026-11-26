import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../core/network/api_client.dart';
import 'socket_service.dart';

/// Server-issued ICE configuration (STUN + TURN). TURN credentials are fetched
/// per session from the backend and never compiled into the APK.
class IceConfigService {
  IceConfigService({required ApiClient api}) : _api = api;

  final ApiClient _api;
  List<Map<String, dynamic>>? _cached;
  DateTime? _cachedAt;

  Future<List<Map<String, dynamic>>> getIceServers() async {
    if (_cached != null && _cachedAt != null) {
      if (DateTime.now().difference(_cachedAt!) < const Duration(minutes: 30)) {
        return _cached!;
      }
    }
    try {
      final response = await _api.get('/calls/ice-servers');
      final data = response['data'] as Map<String, dynamic>;
      final servers = (data['iceServers'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map((entry) {
                final urls = entry['urls'];
                return <String, dynamic>{
                  'urls': urls is List ? urls.map((e) => e.toString()).toList() : urls?.toString(),
                  if (entry['username'] != null) 'username': entry['username'],
                  if (entry['credential'] != null) 'credential': entry['credential'],
                };
              })
              .toList() ??
          const <Map<String, dynamic>>[];
      if (servers.isNotEmpty) {
        _cached = servers;
        _cachedAt = DateTime.now();
      }
      return servers;
    } catch (_) {
      return _fallback;
    }
  }

  static const List<Map<String, dynamic>> _fallback = [
    {'urls': ['stun:stun.l.google.com:19302', 'stun:stun1.l.google.com:19302']},
  ];
}

/// Builds and manages the RTCPeerConnection for a single call.
class PeerConnectionManager {
  PeerConnectionManager({required this.socket});

  final SocketService socket;
  RTCPeerConnection? _pc;
  final List<RTCIceCandidate> _pendingRemoteCandidates = [];
  bool _remoteDescriptionSet = false;

  final _localStreamController = StreamController<MediaStream>.broadcast();
  final _remoteStreamController = StreamController<MediaStream>.broadcast();
  final _stateController = StreamController<RTCPeerConnectionState>.broadcast();

  Stream<MediaStream> get localStreams => _localStreamController.stream;
  Stream<MediaStream> get remoteStreams => _remoteStreamController.stream;
  Stream<RTCPeerConnectionState> get connectionStates => _stateController.stream;

  MediaStream? localStream;
  MediaStream? remoteStream;
  RTCPeerConnectionState state = RTCPeerConnectionState.RTCPeerConnectionStateNew;

  Future<MediaStream> openLocalStream({required bool video}) async {
    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': video
          ? {
              'facingMode': 'user',
              'width': {'ideal': 1280},
              'height': {'ideal': 720},
              'frameRate': {'ideal': 30},
            }
          : false,
    });
    localStream = stream;
    if (!_localStreamController.isClosed) _localStreamController.add(stream);
    return stream;
  }

  Future<RTCPeerConnection> initializePeerConnection({
    required List<Map<String, dynamic>> iceServers,
    required String callId,
    required bool isCaller,
  }) async {
    final config = {
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
    };
    // Uses flutter_webrtc's top-level createPeerConnection (no name clash now).
    final pc = await createPeerConnection(config);
    _pc = pc;

    if (localStream != null) {
      for (final track in localStream!.getTracks()) {
        await pc.addTrack(track, localStream!);
      }
    }

    pc.onIceCandidate = (RTCIceCandidate candidate) {
      socket.emit(SocketEvents.callIceCandidate, {
        'callId': callId,
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      });
    };

    pc.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        remoteStream = event.streams.first;
        if (!_remoteStreamController.isClosed) _remoteStreamController.add(event.streams.first);
      }
    };

    pc.onConnectionState = (RTCPeerConnectionState next) {
      state = next;
      if (!_stateController.isClosed) _stateController.add(next);
    };

    pc.onIceConnectionState = (RTCIceConnectionState iceState) {
      if (iceState == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        _stateController.add(RTCPeerConnectionState.RTCPeerConnectionStateFailed);
      }
    };

    _isCaller = isCaller;
    return pc;
  }

  bool _isCaller = false;

  Future<RTCSessionDescription> createOffer() async {
    final pc = _pc;
    if (pc == null) throw StateError('Peer connection not initialized');
    final offer = await pc.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': true,
    });
    await pc.setLocalDescription(offer);
    return offer;
  }

  Future<RTCSessionDescription> createAnswer() async {
    final pc = _pc;
    if (pc == null) throw StateError('Peer connection not initialized');
    final answer = await pc.createAnswer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': true,
    });
    await pc.setLocalDescription(answer);
    return answer;
  }

  Future<void> applyRemoteOffer(Map<String, dynamic> sdp) async {
    final pc = _pc;
    if (pc == null) throw StateError('Peer connection not initialized');
    await pc.setRemoteDescription(
      RTCSessionDescription(sdp['sdp'] as String?, sdp['type'] as String?),
    );
    _remoteDescriptionSet = true;
    await _flushPendingCandidates();
  }

  Future<void> applyRemoteAnswer(Map<String, dynamic> sdp) async {
    final pc = _pc;
    if (pc == null) throw StateError('Peer connection not initialized');
    await pc.setRemoteDescription(
      RTCSessionDescription(sdp['sdp'] as String?, sdp['type'] as String?),
    );
    _remoteDescriptionSet = true;
    await _flushPendingCandidates();
  }

  Future<void> addRemoteCandidate(Map<String, dynamic> json) async {
    final pc = _pc;
    if (pc == null) return;
    final candidate = RTCIceCandidate(
      json['candidate'] as String?,
      json['sdpMid'] as String?,
      json['sdpMLineIndex'] is int
          ? json['sdpMLineIndex'] as int
          : int.tryParse('${json['sdpMLineIndex'] ?? 0}') ?? 0,
    );
    if (_remoteDescriptionSet) {
      await pc.addCandidate(candidate);
    } else {
      _pendingRemoteCandidates.add(candidate);
    }
  }

  Future<void> _flushPendingCandidates() async {
    final pc = _pc;
    if (pc == null) return;
    for (final candidate in _pendingRemoteCandidates) {
      await pc.addCandidate(candidate);
    }
    _pendingRemoteCandidates.clear();
  }

  bool get isCaller => _isCaller;

  Future<void> setMicrophoneEnabled(bool enabled) async {
    for (final track in localStream?.getAudioTracks() ?? []) {
      track.enabled = enabled;
    }
  }

  Future<void> setCameraEnabled(bool enabled) async {
    if (enabled && (localStream?.getVideoTracks() ?? []).isEmpty) {
      // Video was never negotiated (e.g. the receiver answered with audio
      // only). Enabling then means renegotiation, which is out of scope, so
      // the controller keeps the toggle honest instead of silently failing.
      throw StateError('No video track available for this call');
    }
    for (final track in localStream?.getVideoTracks() ?? []) {
      track.enabled = enabled;
    }
  }

  Future<void> switchCamera() async {
    final tracks = localStream?.getVideoTracks() ?? [];
    if (tracks.isEmpty) return;
    await Helper.switchCamera(tracks.first);
  }

  Future<void> close() async {
    try {
      for (final track in localStream?.getTracks() ?? []) {
        await track.stop();
      }
      await localStream?.dispose();
    } catch (_) {}
    localStream = null;
    try {
      await _pc?.close();
    } catch (_) {}
    _pc = null;
    remoteStream = null;
    _remoteDescriptionSet = false;
    _pendingRemoteCandidates.clear();
    await _localStreamController.close();
    await _remoteStreamController.close();
    await _stateController.close();
  }
}
