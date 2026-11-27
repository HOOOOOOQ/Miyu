/// Application constants (name, IDs, versions, endpoints).
class AppConstants {
  static const String appName = 'Miyu';
  static const String applicationId = 'app.miyu.my.id';
  static const String versionName = '4.8.0';
  static const int versionCode = 473;

  /// Original app version this build restores (from dist/README.md).
  static const String originalVersion = '4.8.0 (473)';

  /// YouTube Music endpoints (reused from the original app).
  static const String ytMusicBase = 'https://music.youtube.com';
  static const String ytMusicApiBase = 'https://m.youtube.com';
  static const String ytMusicMusicApiV1 = 'https://music.youtube.com/youtubei/v1';
  static const String ytMusicMPlayerApiV1 = 'https://m.youtube.com/youtubei/v1';

  /// Player configs (ZemerTeam/zemer-cipher).
  static const String playerConfigsUrl =
      'https://raw.githubusercontent.com/ZemerTeam/zemer-cipher/master/library/src/main/assets/player_configs.json';

  /// Lyrics services (discovered in original repo).
  static const String lyricsSimpMusic = 'https://api-lyrics.simpmusic.org/v1/';
  static const String lyricsBoiduDev = 'https://lyrics-api.boidu.dev';
  static const String lyricsPaxsenix = 'https://lyrics.paxsenix.org';

  /// Optional extras from original repo.
  static const String returnYouTubeDislikeApi = 'https://returnyoutubedislikeapi.com/Votes';
  static const String zemerLyricsResolve = 'https://search.zemer.io/lyrics/resolve';
}
