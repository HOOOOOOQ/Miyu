import 'package:miyu/core/constants.dart';

/// API client configuration — mirrors the original app's endpoints.
class ApiConfig {
  ApiConfig._();

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// Headers sent on every request (from original app).
  static Map<String, String> defaultHeaders() => {
        'User-Agent': 'Miyu/${AppConstants.versionName}',
        'Accept': 'application/json',
      };

  /// YouTube Music API base (music.youtube.com).
  static const String youtubeMusic = AppConstants.ytMusicBase;
}
