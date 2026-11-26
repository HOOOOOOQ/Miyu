import 'package:flutter_test/flutter_test.dart';
import 'package:miyu/core/utils/formatters.dart';
import 'package:miyu/core/utils/validators.dart';

void main() {
  group('Formatters', () {
    test('initials from full names', () {
      expect(Formatters.initials('Miyu Tester'), 'MT');
      expect(Formatters.initials('Ayu'), 'AY');
      expect(Formatters.initials('  '), '?');
    });

    test('call duration formatting', () {
      expect(Formatters.callDuration(const Duration(seconds: 5)), '00:05');
      expect(Formatters.callDuration(const Duration(minutes: 2, seconds: 7)), '02:07');
      expect(Formatters.callDuration(const Duration(hours: 1, minutes: 1, seconds: 1)), '1:01:01');
      expect(Formatters.callDurationFromSeconds(3600), '1:00:00');
    });

    test('file sizes', () {
      expect(Formatters.fileSize(500), '500 B');
      expect(Formatters.fileSize(2048), '2.0 KB');
      expect(Formatters.fileSize(5 * 1024 * 1024), '5.0 MB');
      expect(Formatters.fileSize(null), '');
    });

    test('day divider labels', () {
      expect(Formatters.dayDivider(DateTime.now()), 'Today');
      expect(Formatters.dayDivider(DateTime.now().subtract(const Duration(days: 1))), 'Yesterday');
      expect(Formatters.chatTimestamp(null), '');
    });

    test('last seen labels', () {
      expect(Formatters.lastSeen(null), 'Offline');
      expect(Formatters.lastSeen(DateTime.now().subtract(const Duration(seconds: 20))),
          'Last seen just now');
      expect(Formatters.lastSeen(DateTime.now().subtract(const Duration(minutes: 5))),
          'Last seen 5m ago');
      expect(Formatters.lastSeen(DateTime.now().subtract(const Duration(hours: 3))),
          'Last seen 3h ago');
    });
  });

  group('Validators', () {
    test('username rules', () {
      expect(Validators.username('miyu_user'), isNull);
      expect(Validators.username('ab'), isNotNull);
      expect(Validators.username('bad name'), isNotNull);
      expect(Validators.username(''), isNotNull);
      expect(Validators.username('UPPER'), isNull, reason: 'lowercases before validating');
    });

    test('display name rules', () {
      expect(Validators.displayName('Miyu'), isNull);
      expect(Validators.displayName(''), isNotNull);
      expect(Validators.displayName('x' * 61), isNotNull);
    });

    test('bio rules', () {
      expect(Validators.bio('short bio'), isNull);
      expect(Validators.bio('x' * 201), isNotNull);
    });
  });
}
