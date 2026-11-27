import 'package:flutter_test/flutter_test.dart';
import 'package:miyu/domain/level_service.dart';

void main() {
  test('level calc: 180 min per level', () {
    expect(LevelService.levelOf(0), 1);
    expect(LevelService.levelOf(179999), 1);
    expect(LevelService.levelOf(180000), 2);
    expect(LevelService.levelOf(9000000), min((9000000 ~/ 60000 ~/ 180) + 1, 100));
  });

  test('max level is 100', () {
    expect(LevelService.levelOf(86400000), 100);
  });

  test('progress is modulo based', () {
    // 180 min = level 2, menit%180 == 0 -> progress 0
    expect(LevelService.progressOf(180000), 0);
    // 60000 ms = 1 min -> level 1, progress = 1*100/180 = 0 (integer)
    expect(LevelService.progressOf(60000), 0);
  });

  test('minutesToNextLevel formula', () {
    expect(LevelService.minutesToNextLevel(0), 180);
    expect(LevelService.minutesToNextLevel(86400000), 0);
  });

  test('titles per spec', () {
    expect(LevelService.titleFor(49), '🌱 Pemula');
    expect(LevelService.titleFor(5), '🎧 Pendengar');
    expect(LevelService.titleFor(10), '🧭 Penjelajah');
    expect(LevelService.titleFor(28), '🎵 Maestro');
    expect(LevelService.titleFor(40), '⭐ Legenda');
    expect(LevelService.titleFor(50), '🔥 Mythic');
  });
}

const int min(int a, int b) => a < b ? a : b;
