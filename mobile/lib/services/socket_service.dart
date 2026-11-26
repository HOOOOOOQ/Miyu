import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/app_config.dart';
import '../core/storage/secure_store.dart';

/// Names of every realtime event exchanged with the Miyu backend.
/// Keeping them in one place prevents typo drift between features.
class SocketEvents {
  SocketEvents._();

  static const connect = 'connect';
  static const disconnect = 'disconnect';
  static const connectError = 'connect_error';

  static const userOnline = 'user:online';
  static const userOffline = 'user:offline';
  static const userStatus = 'user:status';

  static const chatJoin = 'chat:join';
  static const chatLeave = 'chat:leave';

  static const messageSend = 'message:send';
  static const messageNew = 'message:new';
  static const messageDelivered = 'message:delivered';
  static const messageRead = 'message:read';
  static const messageEdit = 'message:edit';
  static const messageDelete = 'message:delete';
  static const messageReaction = 'message:reaction';

  static const typingStart = 'typing:start';
  static const typingStop = 'typing:stop';

  static const callIncoming = 'call:incoming';
  static const callRinging = 'call:ringing';
  static const callAccept = 'call:accept';
  static const callReject = 'call:reject';
  static const callOffer = 'call:offer';
  static const callAnswer = 'call:answer';
  static const callIceCandidate = 'call:ice-candidate';
  static const callEnd = 'call:end';
  static const callBusy = 'call:busy';

  static const groupCreated = 'group:created';
  static const groupUpdated = 'group:updated';
  static const groupMembers = 'group:members';
  static const groupDeleted = 'group:deleted';
}

enum SocketConnectionState { idle, connecting, connected, disconnected, failed }

/// Thin, reconnect-aware wrapper around socket_io_client.
/// Authentication happens once at connect time with the Miyu access token.
class SocketService {
  SocketService({required SecureStore secureStore}) : _secureStore = secureStore;

  final SecureStore _secureStore;
  io.Socket? _socket;

  final _stateController = StreamController<SocketConnectionState>.broadcast();
  Stream<SocketConnectionState> get connectionState => _stateController.stream;

  SocketConnectionState _state = SocketConnectionState.idle;
  SocketConnectionState get state => _state;

  final Map<String, List<Function(dynamic)>> _listeners = {};

  bool get isConnected => _socket?.connected ?? false;

  void _setState(SocketConnectionState next) {
    _state = next;
    if (!_stateController.isClosed) _stateController.add(next);
  }

  Future<void> connect() async {
    if (_socket != null && (_socket!.connected || _socket!.active)) return;
    final token = await _secureStore.readAccessToken();
    if (token == null || token.isEmpty) {
      _setState(SocketConnectionState.failed);
      return;
    }
    _setState(SocketConnectionState.connecting);
    final socket = io.io(
      AppConfig.normalizedSocketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .enableReconnection()
          .setReconnectionAttempts(50)
          .setReconnectionDelay(1200)
          .setReconnectionDelayMax(8000)
          .build(),
    );
    _socket = socket;

    socket.on(SocketEvents.connect, (_) {
      _setState(SocketConnectionState.connected);
      // Re-attach listeners after every (re)connect.
      for (final entry in _listeners.entries) {
        for (final listener in entry.value) {
          socket.off(entry.key, listener);
          socket.on(entry.key, listener);
        }
      }
    });
    socket.on(SocketEvents.disconnect, (_) => _setState(SocketConnectionState.disconnected));
    socket.on(SocketEvents.connectError, (_) => _setState(SocketConnectionState.failed));
    socket.connect();
  }

  /// Registers a typed listener and survives reconnects.
  void on<T>(String event, void Function(T payload) handler) {
    final wrapped = (dynamic data) {
      if (data is T) {
        handler(data);
      } else if (T == dynamic) {
        handler(data as T);
      }
    };
    _listeners.putIfAbsent(event, () => []).add(wrapped);
    _socket?.on(event, wrapped);
  }

  void off(String event) {
    for (final listener in _listeners[event] ?? <Function(dynamic)>[]) {
      _socket?.off(event, listener);
    }
    _listeners.remove(event);
  }

  void emit(String event, [dynamic payload]) {
    _socket?.emit(event, payload);
  }

  /// Emit with an acknowledgement callback. Resolves to null on timeout so
  /// callers can fall back to REST without hanging.
  Future<Map<String, dynamic>?> emitWithAck(
    String event,
    dynamic payload, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final socket = _socket;
    if (socket == null || !socket.connected) return null;
    final completer = Completer<Map<String, dynamic>?>();
    try {
      socket.emitWithAck(
        event,
        payload,
        ack: (dynamic response) {
          if (!completer.isCompleted) {
            completer.complete(response is Map ? Map<String, dynamic>.from(response) : null);
          }
        },
      );
    } catch (_) {
      if (!completer.isCompleted) completer.complete(null);
    }
    return completer.future.timeout(timeout, onTimeout: () => null);
  }

  void joinChat(String conversationId) {
    emit(SocketEvents.chatJoin, {'conversationId': conversationId});
  }

  void leaveChat(String conversationId) {
    emit(SocketEvents.chatLeave, {'conversationId': conversationId});
  }

  void startTyping(String conversationId) {
    emit(SocketEvents.typingStart, {'conversationId': conversationId});
  }

  void stopTyping(String conversationId) {
    emit(SocketEvents.typingStop, {'conversationId': conversationId});
  }

  Future<void> disconnect() async {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _setState(SocketConnectionState.idle);
  }

  Future<void> dispose() async {
    await disconnect();
    await _stateController.close();
  }
}
