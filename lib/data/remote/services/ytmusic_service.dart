import 'package:dio/dio.dart';
import 'package:miyu/core/constants.dart';
import 'package:miyu/domain/models.dart';

/// YouTube Music service (unofficial reverse-engineered, as in the original app).
/// Endpoints re-used from the original source (see AUDIT_REPORT.md).
class YtMusicService {
  final Dio dio;

  YtMusicService(this.dio);

  /// Search songs/albums/artists/playlists via youtubei/v1.
  Future<List<Song>> searchSongs(String query) async {
    final res = await dio.get(AppConstants.ytMusicMusicApiV1,
        queryParameters: {'query': query, 'type': 'Song'});
    return _parseSongs(res.data);
  }

  Future<List<Song>> searchSongsMobile(String query) async {
    final res = await dio.get('${AppConstants.ytMusicApiBase}/search', queryParameters: {'q': query});
    return _parseSongs(res.data);
  }

  List<Song> _parseSongs(dynamic data) {
    final list = data is List ? data : const <dynamic>[];
    return list.whereType<Map>().map((m) => Song.fromMap(Map<String, dynamic>.from(m))).toList();
  }

  Future<Song?> getSongMetadata(String songId) async {
    final res = await dio.get('${AppConstants.ytMusicMusicApiV1}/song/get', queryParameters: {'videoId': songId});
    final data = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : null;
    if (data == null) return null;
    return Song.fromMap(data);
  }

  Future<List<String>> getStreamingUrls(String videoId) async {
    final res = await dio.get(AppConstants.playerConfigsUrl);
    return _parseStreamUrls(res.data);
  }

  List<String> _parseStreamUrls(dynamic data) {
    // Player configs may be JSON list of streams; tolerate both shapes.
    final List<dynamic> items;
    if (data is List) {
      items = data;
    } else if (data is Map) {
      final inner = data['streams'] ?? data['urls'] ?? data['tracks'];
      items = inner is List ? inner : const [];
    } else {
      items = const [];
    }
    return items.whereType<String>().where((u) => u.startsWith('http')).toList();
  }
}
