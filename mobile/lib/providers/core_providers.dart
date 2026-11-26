import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/storage/preferences.dart';
import '../core/storage/secure_store.dart';
import '../services/auth_service.dart';
import '../services/call_signaling_service.dart';
import '../services/chat_repository.dart';
import '../services/media_service.dart';
import '../services/push_service.dart';
import '../services/socket_service.dart';
import '../services/voice_recorder_service.dart';

/// Overridden in main() after async bootstrapping so the app never renders
/// before preferences are available.
final preferencesProvider = Provider<Preferences>((ref) {
  throw UnimplementedError('preferencesProvider must be overridden at startup');
});

final secureStoreProvider = Provider<SecureStore>((ref) => SecureStore());

/// Backend host the app talks to: the value saved in Settings when present,
/// otherwise the URL compiled in with --dart-define. Changing it rebuilds
/// [apiClientProvider] and [socketServiceProvider], which is why the app asks
/// the user to restart (or sign out) after editing it.
final serverUrlProvider = StateProvider<String?>((ref) {
  return ref.watch(preferencesProvider).serverUrlOverride;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(
    secureStore: ref.watch(secureStoreProvider),
    serverUrl: ref.watch(serverUrlProvider),
  );
  ref.onDispose(() {});
  return client;
});

final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService(
    secureStore: ref.watch(secureStoreProvider),
    serverUrl: ref.watch(serverUrlProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final pushServiceProvider = Provider<PushService>((ref) {
  final service = PushService(api: ref.watch(apiClientProvider));
  ref.onDispose(service.dispose);
  return service;
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    api: ref.watch(apiClientProvider),
    secureStore: ref.watch(secureStoreProvider),
  );
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(api: ref.watch(apiClientProvider));
});

final mediaServiceProvider = Provider<MediaService>((ref) {
  return MediaService(api: ref.watch(apiClientProvider));
});

final voiceRecorderProvider = Provider<VoiceRecorderService>((ref) {
  final service = VoiceRecorderService();
  ref.onDispose(service.dispose);
  return service;
});

final iceConfigProvider = Provider<IceConfigService>((ref) {
  return IceConfigService(api: ref.watch(apiClientProvider));
});
