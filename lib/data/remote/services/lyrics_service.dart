import 'package:dio/dio.dart';
import 'package:miyu/core/constants.dart';

/// Lyrics provider — uses discovered public lyrics endpoints.
class LyricsService {
  final Dio dio;

  LyricsService(this.dio);

  Future<String?> searchLyrics(String title, {String? artist}) async {
    final endpoints = [
      (AppConstants.lyricsSimpMusic, {'text': title, 'artist': artist ?? ''}),
      (AppConstants.lyricsBoiduDev, {'q': title, 'artist': artist ?? ''}),
      (AppConstants.lyricsPaxsenix, {'song': title, 'artist': artist ?? ''}),
    ];
    for (final (base, params) in endpoints) {
      try {
        final res = await dio.get(base, queryParameters: params, options: Options(receiveTimeout: const Duration(seconds: 8)));
        final data = res.data;
        final text = data is Map ? (data['lyrics'] ?? data['text'] ?? data['lrc'])?.toString() : null;
        if (text is String && text.trim().isNotEmpty) return text;
        final lrc = data is Map ? data['lrc'] : null;
        if (lrc is String && lrc.trim().isNotEmpty) return lrc;
      } catch (_) {
        // Try next endpoint
      }
    }
    return null;
  }
}
