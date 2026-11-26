import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  /// Chat list timestamps: 09:41 → "09:41", yesterday → "Yesterday", older → date.
  static String chatTimestamp(DateTime? time) {
    if (time == null) return '';
    final local = time.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(local.year, local.month, local.day);
    final difference = today.difference(that).inDays;

    if (difference == 0) return DateFormat.Hm().format(local);
    if (difference == 1) return 'Yesterday';
    if (difference < 7) return DateFormat.E().format(local);
    if (local.year == now.year) return DateFormat.MMMd().format(local);
    return DateFormat.yMd().format(local);
  }

  /// Message bubble timestamp with seconds omitted.
  static String messageTime(DateTime? time) {
    if (time == null) return '';
    return DateFormat.Hm().format(time.toLocal());
  }

  /// Sticky day divider: "Today", "Yesterday", "Monday, Jun 3".
  static String dayDivider(DateTime time) {
    final local = time.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(local.year, local.month, local.day);
    final difference = today.difference(that).inDays;
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference < 7) return DateFormat.EEEE().format(local);
    return DateFormat.yMMMMd().format(local);
  }

  static String lastSeen(DateTime? time) {
    if (time == null) return 'Offline';
    final local = time.toLocal();
    final diff = DateTime.now().difference(local);
    if (diff.inSeconds < 60) return 'Last seen just now';
    if (diff.inMinutes < 60) return 'Last seen ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Last seen ${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Last seen yesterday';
    if (diff.inDays < 7) return 'Last seen ${diff.inDays}d ago';
    return 'Last seen ${DateFormat.yMMMd().format(local)}';
  }

  /// Call duration as mm:ss (or h:mm:ss beyond an hour).
  static String callDuration(Duration duration) {
    final total = duration.inSeconds;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  static String callDurationFromSeconds(int seconds) {
    return callDuration(Duration(seconds: seconds));
  }

  static String initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) {
      final word = parts.first;
      return (word.length >= 2 ? word.substring(0, 2) : word).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  static String fileSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit += 1;
    }
    final rounded = value >= 10 || unit == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
    return '$rounded ${units[unit]}';
  }
}
