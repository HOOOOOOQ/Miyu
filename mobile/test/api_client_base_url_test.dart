import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miyu/config/app_config.dart';
import 'package:miyu/core/network/api_client.dart';
import 'package:miyu/core/storage/secure_store.dart';

/// The Settings override is only useful if it actually reaches Dio's baseUrl.
/// Without this test the UI could save a value, show it, and still talk to the
/// compiled default host.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ApiClient uses the Settings override for its base URL', () {
    final client = ApiClient(
      secureStore: SecureStore(),
      serverUrl: 'http://192.168.1.10:5000',
    );

    expect(client.raw.options.baseUrl, 'http://192.168.1.10:5000/api');
  });

  test('ApiClient trails a single /api and never a double slash', () {
    final client = ApiClient(
      secureStore: SecureStore(),
      serverUrl: 'https://miyu.example.com/',
    );

    expect(client.raw.options.baseUrl, 'https://miyu.example.com/api');
    expect(client.raw.options.baseUrl.contains('//api'), isFalse);
  });

  test('ApiClient falls back to the compiled default when no override is given', () {
    final client = ApiClient(secureStore: SecureStore());

    expect(
      client.raw.options.baseUrl,
      '${AppConfig.normalizedApiBaseUrl}/api',
    );
  });

  test('401s are treated as errors so the refresh path runs', () {
    final client = ApiClient(secureStore: SecureStore());

    // validateStatus is non-nullable in dio 5.x, so it is called directly.
    final validate = client.raw.options.validateStatus;
    expect(validate(401), isFalse);
    expect(validate(200), isTrue);
  });

  test('an injected Dio is respected (used by tests and future proxies)', () {
    final dio = Dio(BaseOptions(baseUrl: 'http://injected.local/api'));
    final client = ApiClient(secureStore: SecureStore(), dio: dio);

    expect(client.raw.options.baseUrl, 'http://injected.local/api');
  });
}
