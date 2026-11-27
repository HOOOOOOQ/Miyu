/// Miyu domain models.

class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String artistId;
  final String? albumId;
  final String? durationMs;
  final String? artworkUrl;
  final String? source; // provider
  final String? sourceId;
  final int trackNumber;
  final int durationSeconds;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.artistId,
    this.albumId,
    this.durationMs,
    this.artworkUrl,
    this.source,
    this.sourceId,
    this.trackNumber = 0,
    this.durationSeconds = 0,
  });

  factory Song.fromMap(Map<String, dynamic> map) {
    return Song(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      artist: map['artist']?.toString() ?? '',
      album: map['album']?.toString() ?? '',
      artistId: map['artistId']?.toString() ?? map['artist_id']?.toString() ?? '',
      albumId: map['albumId']?.toString() ?? map['album_id']?.toString(),
      durationMs: map['durationMs']?.toString() ?? map['duration_ms']?.toString(),
      artworkUrl: map['artworkUrl'] ?? map['artwork_url'],
      source: map['source'],
      sourceId: map['sourceId'] ?? map['source_id'],
      trackNumber: (map['trackNumber'] ?? map['track_number'] ?? 0) as int? ?? 0,
      durationSeconds: (map['durationSeconds'] ?? map['duration_seconds'] ?? 0) as int? ?? 0,
    );
  }
}

class Album {
  final String id;
  final String title;
  final String artist;
  final String? artistId;
  final String? artworkUrl;
  final int? year;
  final int totalTracks;

  const Album({required this.id, required this.title, required this.artist, this.artistId, this.artworkUrl, this.year, this.totalTracks = 0});
}

class Artist {
  final String id;
  final String name;
  final String? avatarUrl;
  final int subscribers;
  final bool isVerified;

  const Artist({required this.id, required this.name, this.avatarUrl, this.subscribers = 0, this.isVerified = false});
}

class Playlist {
  final String id;
  final String name;
  final String ownerId;
  final String? description;
  final int trackCount;
  final int createdAtMs;

  const Playlist({required this.id, required this.name, required this.ownerId, this.description, this.trackCount = 0, this.createdAtMs = 0});
}

/// User account (local account store; original app is local + optional YouTube).
class UserAccount {
  final String id;
  final String username;
  final String displayName;
  final String role; // user / admin (see core/app_prefs + features/profile)
  final bool verified;
  final bool admin;
  final int listeningHours;

  const UserAccount({
    required this.id,
    required this.username,
    this.displayName = '',
    this.role = 'user',
    this.verified = false,
    this.admin = false,
    this.listeningHours = 0,
  });
}
