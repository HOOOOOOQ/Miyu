import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage/secure_store.dart';
import '../models/message.dart';
import '../services/socket_service.dart';
import 'call_provider.dart';
import 'chat_list_provider.dart';
import 'core_providers.dart';
import 'message_provider.dart';
import 'session_provider.dart';

/// Bridges Socket.IO events into Riverpod state. One global subscription is
/// created when the session becomes authenticated.
class RealtimeCoordinator {
  RealtimeCoordinator({required Ref ref}) : _ref = ref;

  final Ref _ref;
  final List<(String, void Function(dynamic))> _bound = [];
  StreamSubscription<SocketConnectionState>? _stateSub;
  StreamSubscription<Map<String, dynamic>>? _pushTapSub;
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    final socket = _ref.read(socketServiceProvider);
    await _bindAccessToken();
    await socket.connect();
    _stateSub = socket.connectionState.listen((state) {
      if (state == SocketConnectionState.connected) {
        _rejoinActiveChat();
      }
    });
    _bind(socket);
    _listenForPushTaps();
  }

  Future<void> _bindAccessToken() async {
    final SecureStore store = _ref.read(secureStoreProvider);
    final token = await store.readAccessToken();
    _ref.read(apiClientProvider).setTokens(accessToken: token);
  }

  void _listenForPushTaps() {
    final push = _ref.read(pushServiceProvider);
    _pushTapSub = push.onNotificationTap.listen((payload) {
      final type = payload['type'];
      if (type == 'incoming_call' && payload['callId'] != null) {
        _ref
            .read(callControllerProvider.notifier)
            .handlePushIncomingCall(payload['callId'] as String);
      }
    });
  }

  void _bind(SocketService socket) {
    void on<T>(String event, void Function(T data) handler) {
      socket.on<T>(event, handler);
      _bound.add((event, handler as void Function(dynamic)));
    }

    on<dynamic>(SocketEvents.messageNew, (data) {
      if (data is! Map) return;
      final raw = data['message'];
      if (raw is! Map) return;
      final message = Message.fromJson(Map<String, dynamic>.from(raw));
      _ref.read(chatListProvider.notifier).applyIncomingMessage(
            message,
            currentUserId: _ref.read(currentUserIdProvider) ?? '',
            activeChatId: _ref.read(activeChatIdProvider),
          );
      _activeMessageController(message.conversationId)?.onRemoteMessage(message);
    });

    on<dynamic>(SocketEvents.messageEdit, (data) {
      if (data is! Map) return;
      final conversationId = data['conversationId']?.toString() ?? '';
      final editedAt = data['editedAt'] == null ? null : DateTime.tryParse(data['editedAt'].toString());
      _activeMessageController(conversationId)?.onMessageEdited(
        data['messageId']?.toString() ?? '',
        data['content']?.toString() ?? '',
        editedAt,
      );
    });

    on<dynamic>(SocketEvents.messageDelete, (data) {
      if (data is! Map) return;
      final conversationId = data['conversationId']?.toString() ?? '';
      _activeMessageController(conversationId)?.onMessageDeleted(
        data['messageId']?.toString() ?? '',
        forEveryone: data['mode'] != 'me',
        forUserId: data['userId']?.toString(),
      );
    });

    on<dynamic>(SocketEvents.messageReaction, (data) {
      if (data is! Map) return;
      final conversationId = data['conversationId']?.toString() ?? '';
      final reactions = (data['reactions'] as List?)
              ?.whereType<Map>()
              .map((e) => MessageReaction.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          const <MessageReaction>[];
      _activeMessageController(conversationId)?.onReactionsUpdated(
        data['messageId']?.toString() ?? '',
        reactions,
      );
    });

    on<dynamic>(SocketEvents.messageRead, (data) {
      if (data is! Map) return;
      final conversationId = data['conversationId']?.toString() ?? '';
      final userId = data['userId']?.toString() ?? '';
      final ids = (data['messageIds'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
      _activeMessageController(conversationId)?.onReadUpdate(ids, userId);
    });

    on<dynamic>(SocketEvents.messageDelivered, (data) {
      if (data is! Map) return;
      final conversationId = data['conversationId']?.toString() ?? '';
      final userId = data['userId']?.toString() ?? '';
      final ids = (data['messageIds'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
      _activeMessageController(conversationId)?.onDeliveryUpdate(ids, userId);
    });

    on<dynamic>(SocketEvents.typingStart, (data) {
      if (data is! Map) return;
      final conversationId = data['conversationId']?.toString() ?? '';
      _activeMessageController(conversationId)?.setTypingUser(
        data['userId']?.toString() ?? '',
        data['displayName']?.toString() ?? 'Someone',
        true,
      );
    });

    on<dynamic>(SocketEvents.typingStop, (data) {
      if (data is! Map) return;
      final conversationId = data['conversationId']?.toString() ?? '';
      final userId = data['userId']?.toString() ?? '';
      _activeMessageController(conversationId)?.setTypingUser(userId, '', false);
    });

    on<dynamic>(SocketEvents.userStatus, (data) {
      if (data is! Map) return;
      final userId = data['userId']?.toString() ?? '';
      final isOnline = data['isOnline'] == true;
      final lastSeen =
          data['lastSeen'] == null ? null : DateTime.tryParse(data['lastSeen'].toString())?.toLocal();
      _ref.read(chatListProvider.notifier).updatePresence(userId, isOnline, lastSeen);
      _ref.read(callControllerProvider.notifier).updatePresence(userId, isOnline);
    });

    // ---- call signalling ------------------------------------------------
    final calls = _ref.read(callControllerProvider.notifier);
    on<dynamic>(SocketEvents.callIncoming, (data) {
      if (data is Map) calls.onIncomingCall(Map<String, dynamic>.from(data));
    });
    on<dynamic>(SocketEvents.callAccept, (data) {
      if (data is Map) calls.onCallAccepted(Map<String, dynamic>.from(data));
    });
    on<dynamic>(SocketEvents.callReject, (data) {
      if (data is Map) calls.onCallRejected(Map<String, dynamic>.from(data));
    });
    on<dynamic>(SocketEvents.callEnd, (data) {
      if (data is Map) calls.onRemoteCallEnded(Map<String, dynamic>.from(data));
    });
    on<dynamic>(SocketEvents.callBusy, (data) {
      if (data is Map) calls.onPeerBusy(Map<String, dynamic>.from(data));
    });
    on<dynamic>(SocketEvents.callOffer, (data) {
      if (data is Map) calls.onRemoteOffer(Map<String, dynamic>.from(data));
    });
    on<dynamic>(SocketEvents.callAnswer, (data) {
      if (data is Map) calls.onRemoteAnswer(Map<String, dynamic>.from(data));
    });
    on<dynamic>(SocketEvents.callIceCandidate, (data) {
      if (data is Map) calls.onRemoteIceCandidate(Map<String, dynamic>.from(data));
    });

  }

  dynamic? _activeMessageController(String conversationId) {
    if (_ref.read(activeChatIdProvider) != conversationId) return null;
    try {
      return _ref.read(messageControllerProvider(conversationId).notifier);
    } catch (_) {
      return null;
    }
  }

  void _rejoinActiveChat() {
    final active = _ref.read(activeChatIdProvider);
    if (active != null) _ref.read(socketServiceProvider).joinChat(active);
  }

  Future<void> stop() async {
    _started = false;
    await _stateSub?.cancel();
    await _pushTapSub?.cancel();
    final socket = _ref.read(socketServiceProvider);
    for (final (event, _) in _bound) {
      socket.off(event);
    }
    _bound.clear();
    await socket.disconnect();
    _ref.read(callControllerProvider.notifier).reset();
  }
}

final realtimeCoordinatorProvider = Provider<RealtimeCoordinator>((ref) {
  final coordinator = RealtimeCoordinator(ref: ref);
  ref.listen<SessionState>(sessionProvider, (previous, next) async {
    if (next.isAuthenticated && previous?.isAuthenticated != true) {
      await _ref_pushInitAndStart(ref, coordinator);
    } else if (!next.isAuthenticated && previous?.isAuthenticated == true) {
      await coordinator.stop();
    }
  }, fireImmediately: true);
  return coordinator;
});

Future<void> _ref_pushInitAndStart(Ref ref, RealtimeCoordinator coordinator) async {
  final push = ref.read(pushServiceProvider);
  await push.initialize();
  await push.registerCurrentDevice();
  await coordinator.start();
}
