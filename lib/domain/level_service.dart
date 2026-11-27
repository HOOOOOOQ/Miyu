/// Level System — MASTER TASK spec.
///
/// One level requires 180 minutes of listening. Max level 100.
class LevelService {
  /// menit = totalMs ~/ 60000
  static int minutesOf(int totalMs) => totalMs ~/ 60000;

  /// level = min((menit ~/ 180) + 1, 100)
  static int levelOf(int totalMs) {
    final menit = totalMs ~/ 60000;
    final lvl = (menit ~/ 180) + 1;
    return lvl < 100 ? lvl : 100;
  }

  /// progress = level >= 100 ? 100 : (menit % 180) * 100 / 180
  static int progressOf(int totalMs) {
    final menit = totalMs ~/ 60000;
    final level = levelOf(totalMs);
    if (level >= 100) return 100;
    return ((menit % 180) * 100 ~/ 180);
  }

  /// menitKeBerikutnya = level >= 100 ? 0 : 180 - (menit % 180)
  static int minutesToNextLevel(int totalMs) {
    final menit = totalMs ~/ 60000;
    if (levelOf(totalMs) >= 100) return 0;
    return 180 - (menit % 180);
  }

  static const List<String> _titles = ['🌱 Pemula']; // placeholder, see titleFor

  /// Level titles per MASTER TASK.
  static String titleFor(int level) {
    if (level < 5) return '🌱 Pemula';
    if (level < 10) return '🎧 Pendengar';
    if (level < 20) return '🧭 Penjelajah';
    if (level < 28) return '📻 Kolektor';
    if (level < 40) return '🎵 Maestro';
    if (level < 50) return '⭐ Legenda';
    return '🔥 Mythic';
  }
}
