import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/network/api_client.dart';
import '../core/utils/formatters.dart';

/// Handles FCM registration, token sync, and notification presentation.
///
/// Incoming-call pushes use a high-importance channel with a full-screen
/// intent when the device is locked. A terminated app cannot guarantee
/// real-time ringing with plain FCM data messages; see docs/WEBRTC_SETUP.md
/// for the foreground-service follow-up required for 100% call reliability.
class PushService {
  PushService({required ApiClient api}) : _api = api;

  final ApiClient _api;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  static const _callChannelId = 'miyu_calls';
  static const _messagesChannelId = 'miyu_messages';
  static const _generalChannelId = 'miyu_general';

  bool _initialized = false;
  String? _token;
  final _tapController = StreamController<Map<String, dynamic>>.broadcast();

  /// Emits payloads when the user taps a notification (foreground, background
  /// or cold start). The router maps these to deep links.
  Stream<Map<String, dynamic>> get onNotificationTap => _tapController.stream;

  String? get token => _token;

  Future<bool> initialize() async {
    if (_initialized) return true;
    try {
      await Firebase.initializeApp();
    } catch (error) {
      debugPrint('[Push] Firebase not configured: $error');
      return false;
    }
    try {
      await _createChannels();
      await _local.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/ic_notification'),
        ),
        onDidReceiveNotificationResponse: (response) {
          final payload = _decodePayload(response.payload);
          if (payload.isNotEmpty) _tapController.add(payload);
        },
      );
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _tapController.add({...message.data.map((k, v) => MapEntry(k, v.toString()))});
      });
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        _tapController.add({...initial.data.map((k, v) => MapEntry(k, v.toString()))});
      }
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      _token = await FirebaseMessaging.instance.getToken();
      FirebaseMessaging.instance.onTokenRefresh.listen((next) {
        _token = next;
        _syncToken(next);
      });
      _initialized = true;
      return true;
    } catch (error) {
      debugPrint('[Push] init failed: $error');
      return false;
    }
  }

  Future<void> _createChannels() async {
    final android = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _messagesChannelId,
        'Messages',
        description: 'New messages from your Miyu conversations',
        importance: Importance.high,
      ),
    );
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _callChannelId,
        'Calls',
        description: 'Incoming voice and video calls',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _generalChannelId,
        'General',
        description: 'Group activity and account updates',
        importance: Importance.defaultImportance,
      ),
    );
  }

  Future<void> _syncToken(String nextToken) async {
    try {
      await _api.post('/users/devices', data: {
        'fcmToken': nextToken,
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'deviceName': 'Miyu Android',
      });
    } catch (error) {
      debugPrint('[Push] token sync failed: $error');
    }
  }

  /// Call after login so the backend can target this device.
  Future<void> registerCurrentDevice() async {
    if (!_initialized) await initialize();
    final current = _token ?? await FirebaseMessaging.instance.getToken().catchError((_) => null);
    if (current == null) return;
    _token = current;
    await _syncToken(current);
  }

  /// Call before logout to detach the device from the account.
  Future<void> unregisterCurrentDevice() async {
    final current = _token;
    if (current == null) return;
    try {
      await _api.delete('/users/devices', data: {'fcmToken': current});
    } catch (error) {
      debugPrint('[Push] unregister failed: $error');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final data = {...message.data.map((k, v) => MapEntry(k, v.toString()))};
    final type = data['type'] ?? 'message';
    if (type == 'incoming_call') {
      // The in-app call sheet is presented by CallController, not by a banner.
      _tapController.add(data);
      return;
    }
    final title = message.notification?.title ?? data['title'] ?? 'Miyu';
    var body = message.notification?.body ?? data['body'] ?? '';
    if (body.isEmpty) {
      body = previewFor(data['messageType'] ?? 'text');
    }
    _showLocal(
      title: title,
      body: body,
      payload: data,
      channelId: type == 'missed_call' ? _callChannelId : _messagesChannelId,
      highPriority: type == 'missed_call',
    );
  }

  Future<void> _showLocal({
    required String title,
    required String body,
    required Map<String, dynamic> payload,
    required String channelId,
    bool highPriority = false,
  }) async {
    await _local.show(
      payload.hashCode ^ DateTime.now().millisecondsSinceEpoch,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelId == _callChannelId ? 'Calls' : 'Messages',
          importance: highPriority ? Importance.max : Importance.high,
          priority: highPriority ? Priority.max : Priority.high,
          icon: '@drawable/ic_notification',
          styleInformation: BigTextStyleInformation(body),
          category: channelId == _callChannelId
              ? AndroidNotificationCategory.call
              : AndroidNotificationCategory.message,
        ),
      ),
      payload: jsonEncode(payload),
    );
  }

  Map<String, dynamic> _decodePayload(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } catch (_) {
      return const {};
    }
  }

  /// Preview text used in notification bodies for message pushes.
  static String previewFor(String messageType) {
    switch (messageType) {
      case 'image':
        return 'Photo';
      case 'video':
        return 'Video';
      case 'audio':
        return 'Voice message';
      case 'file':
        return 'Document';
      default:
        return 'New message';
    }
  }

  static String callSummary(String callType, int durationSeconds) {
    return '${callType == 'video' ? 'Video' : 'Voice'} call · '
        '${Formatters.callDurationFromSeconds(durationSeconds)}';
  }

  Future<void> dispose() async {
    await _tapController.close();
  }
}
