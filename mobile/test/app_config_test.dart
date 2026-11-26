import 'package:flutter_test/flutter_test.dart';
import 'package:miyu/config/app_config.dart';

void main() {
  group('AppConfig.normalizeServerInput', () {
    test('adds http:// when no scheme is typed', () {
      expect(
        AppConfig.normalizeServerInput('play.notmemc.my.id:3186'),
        'http://play.notmemc.my.id:3186',
      );
    });

    test('keeps https:// and strips a trailing slash', () {
      expect(AppConfig.normalizeServerInput('https://api.example.com/'), 'https://api.example.com');
    });

    test('accepts an IP address with a port (LAN testing)', () {
      expect(AppConfig.normalizeServerInput('192.168.1.10:5000'), 'http://192.168.1.10:5000');
    });

    test('trims surrounding whitespace', () {
      expect(AppConfig.normalizeServerInput('  http://10.0.2.2:5000  '), 'http://10.0.2.2:5000');
    });

    test('rejects empty input', () {
      expect(AppConfig.normalizeServerInput(''), isNull);
      expect(AppConfig.normalizeServerInput('   '), isNull);
    });

    test('rejects a scheme the app cannot speak', () {
      expect(AppConfig.normalizeServerInput('ftp://example.com'), isNull);
    });
  });

  group('resolved server URL', () {
    test('uses the override when one is set', () {
      expect(
        AppConfig.resolvedApiBaseUrl('http://192.168.1.10:5000'),
        'http://192.168.1.10:5000',
      );
      expect(
        AppConfig.resolvedSocketUrl('http://192.168.1.10:5000/'),
        'http://192.168.1.10:5000',
      );
    });

    test('falls back to the compiled default when the override is empty', () {
      expect(AppConfig.resolvedApiBaseUrl(null), AppConfig.normalizedApiBaseUrl);
      expect(AppConfig.resolvedApiBaseUrl(''), AppConfig.normalizedApiBaseUrl);
      expect(AppConfig.resolvedSocketUrl(null), AppConfig.normalizedSocketUrl);
    });
  });

  test('the default build points at the deployed Pterodactyl backend', () {
    // Guards against a regression where the default silently reverts to the
    // emulator loopback and every release APK fails to connect.
    expect(AppConfig.normalizedApiBaseUrl, 'http://play.notmemc.my.id:3186');
  });
}
