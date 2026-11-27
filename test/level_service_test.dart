import 'package:flutter_test/flutter_test.dart';
import 'package:miyu/domain/level_service.dart';

void main() {
  test('level calc: 180 min per level (spec)', () {
    // menit = totalMs ~/ 60000; level = min((menit ~/ 180) + 1, 100)
    expect(LevelService.levelOf(0), 1);
    expect(LevelService.levelOf(179999), 1);
    expect(LevelService.levelOf(180000), 2);
    expect(LevelService.levelOf(360000), 3);
    expect(LevelService.levelOf(17820000), 100); // 293h40m
  });

  test('max level is 100', () {
    expect(LevelService.levelOf(86400000), 100); // 24h
    expect(LevelService.levelOf(3628800000), 100); // 500h
  });

  test('progress is modulo based (spec)', () {
    // progress = level >= 100 ? 100 : (menit % 180) * 100 / 180
    expect(LevelService.progressOf(180000), 0); // menit%180 == 0
    expect(LevelService.progressOf(60000), 0); // 1 min: (1%180)*100/180 = 0 (int)
    expect(LevelService.progressOf(30000), (30 * 100 ~/ 180)); // 0.5 min -> 0
    expect(LevelService.progressOf(95000), ((95 ~/ 60000) % 180) * 100 ~/ 180); // 0
    expect(LevelService.progressOf(100000000), (100000000 ~/ 60000 % 180) * 100 ~/ 180);
  });

  test('minutesToNextLevel formula', () {
    // menitKeBerikutnya = level >= 100 ? 0 : 180 - (menit % 180)
    expect(LevelService.minutesToNextLevel(0), 180);
    expect(LevelService.minutesToNextLevel(180000), 180);
    expect(LevelService.minutesToNextLevel(89999), 179); // menit=1, 180 - (1 % 180)
    expect(LevelService.minutesToNextLevel(180000), 177); // menit=3, 180 - (3 % 180)
    expect(LevelService.minutesToNextLevel(86400000), 0);
  });

  test('titles per spec', () {
    expect(LevelService.titleFor(0), '🌱 Pemula');
    expect(LevelService.titleFor(5), '🎧 Pendengar');
    expect(LevelService.titleFor(10), '🧭 Penjelajah');
    expect(LevelService.titleFor(28), '🎵 Maestro');
    expect(LevelService.titleFor(40), '⭐ Legenda');
    expect(LevelService.titleFor(50), '🔥 Mythic');
    expect(LevelService.titleFor(100), '🔥 Mythic');
  });
}
