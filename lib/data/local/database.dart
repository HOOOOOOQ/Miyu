import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

// ---------------------------------------------------------------------------
// Tables (DRIFT — SQLite). DDL executed via Migrator (no codegen).
// ---------------------------------------------------------------------------

class Songs extends Table {
  IntColumn get id => integer().autoIncrement().primaryKey();
  TextColumn get title => text().withDefault(Constant(''));
  TextColumn get artist => text().withDefault(Constant(''));
  TextColumn get album => text().withDefault(Constant(''));
  IntColumn get durationMs => integer().withDefault(Constant(0));
  TextColumn get artworkUrl => text().nullable();
  TextColumn get provider => text().withDefault(Constant(''));
  TextColumn get providerId => text().nullable();
}

class Playlists extends Table {
  TextColumn get id => text().primaryKey();
  TextColumn get name => text().withDefault(Constant(''));
  TextColumn get ownerId => text().withDefault(Constant(''));
  TextColumn get description => text().nullable();
  IntColumn get trackCount => integer().withDefault(Constant(0));
  IntColumn get createdAtMs => integer().withDefault(Constant(0));
}

class PlaylistSongs extends Table {
  IntColumn get playlistId => integer().notNull();
  TextColumn get songId => text().notNull();
  IntColumn get position => integer().withDefault(Constant(0));
}

class LikedSongs extends Table {
  TextColumn get songId => text().primaryKey();
  IntColumn get likedAtMs => integer().withDefault(Constant(0));
}

class FollowedArtists extends Table {
  TextColumn get artistId => text().primaryKey();
  IntColumn get followedAtMs => integer().withDefault(Constant(0));
}

class UserPreferences extends Table {
  TextColumn get key => text().primaryKey();
  TextColumn get value => text().withDefault(Constant(''));
}

class PlayHistory extends Table {
  IntColumn get id => integer().autoIncrement().primaryKey();
  TextColumn get songId => text().withDefault(Constant(''));
  IntColumn get playedMs => integer().withDefault(Constant(0));
  IntColumn get timestampMs => integer().withDefault(Constant(0));
}

/// Play sessions feed the Level System (totalMs from actual listening records).
class PlaySessions extends Table {
  IntColumn get id => integer().autoIncrement().primaryKey();
  TextColumn get songId => text().withDefault(Constant(''));
  IntColumn get startedAtMs => integer().withDefault(Constant(0));
  IntColumn get endedAtMs => integer().withDefault(Constant(0));
  IntColumn get totalMs => integer().withDefault(Constant(0));
  IntColumn get wasPlayed => integer().withDefault(Constant(0));
}

/// AppDatabase (Drift + SQLite).
class AppDatabase extends GeneratedDatabase {
  AppDatabase(QueryExecutor executor) : super(executor);

  static AppDatabase openInMemory() => AppDatabase(NativeDatabase.inMemory());
  static AppDatabase open(String path) => AppDatabase(NativeDatabase(File(path)));

  @override
  int get schemaVersion => 1;

  @override
  Future<void> onUpgrade(Migrator m, int oldVersion, int newVersion) async {
    if (oldVersion < 1) {
      await m.createTable(Songs());
      await m.createTable(Playlists());
      await m.createTable(PlaylistSongs());
      await m.createTable(LikedSongs());
      await m.createTable(FollowedArtists());
      await m.createTable(UserPreferences());
      await m.createTable(PlayHistory());
      await m.createTable(PlaySessions());
    }
  }

  // --- CRUD ---------------------------------------------------------------

  /// Insert a song into the local library ( songs table ).
  Future<int> insertSong(Map<String, Object?> data) =>
      customInsert("INSERT INTO songs (title, artist, album, durationMs, artworkUrl, provider, providerId) "
          "VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
          variables: [
            Variable(data['title'] ?? ''),
            Variable(data['artist'] ?? ''),
            Variable(data['album'] ?? ''),
            Variable(data['durationMs'] ?? 0),
            Variable(data['artworkUrl'] ?? ''),
            Variable(data['provider'] ?? ''),
            Variable(data['providerId'] ?? ''),
          ]);

  Future<List<Map<String, dynamic>>> songs() async {
    final res = await customSelect('SELECT id, title, artist, album, durationMs, artworkUrl, provider, providerId FROM songs',
        readsFrom: {Songs()});
    return res.map((r) => r.data).toList();
  }

  Future<int> likeSong(String songId) async {
    final rows = await customSelect('SELECT 1 FROM likedSongs WHERE songId = ?1',
        variables: [Variable(songId)], readsFrom: {LikedSongs()});
    if (rows.isNotEmpty) return 0;
    return customInsert("INSERT INTO likedSongs (songId, likedAtMs) VALUES (?1, ?2)",
        variables: [Variable(songId), Variable(DateTime.now().millisecondsSinceEpoch)]);
  }

  Future<int> unlikeSong(String songId) =>
      customDelete('DELETE FROM likedSongs WHERE songId = ?1', variables: [Variable(songId)]);

  Future<bool> isLiked(String songId) async {
    final rows = await customSelect('SELECT 1 FROM likedSongs WHERE songId = ?1',
        variables: [Variable(songId)], readsFrom: {LikedSongs()});
    return rows.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> likedSongsList() async {
    final res = await customSelect('''SELECT s.id, s.title, s.artist, s.album, s.durationMs, s.artworkUrl
        FROM likedSongs l JOIN songs s ON s.id = l.songId''',
        readsFrom: {LikedSongs(), Songs()});
    return res.map((r) => r.data).toList();
  }

  Future<int> insertSession(Map<String, Object?> data) =>
      customInsert("INSERT INTO playsessions (songId, startedAtMs, endedAtMs, totalMs, wasPlayed) "
          "VALUES (?1, ?2, ?3, ?4, ?5)",
          variables: [
            Variable(data['songId'] ?? ''),
            Variable(data['startedAtMs'] ?? 0),
            Variable(data['endedAtMs'] ?? 0),
            Variable(data['totalMs'] ?? 0),
            Variable(data['wasPlayed'] ? 1 : 0),
          ]);

  Future<List<Map<String, dynamic>>> sessions() async {
    final res = await customSelect(
        'SELECT id, songId, startedAtMs, endedAtMs, totalMs, wasPlayed FROM playsessions ORDER BY id DESC',
        readsFrom: {PlaySessions()});
    return res.map((r) => r.data).toList();
  }

  Future<void> clearHistory() => customUpdate('DELETE FROM playHistory');

  Future<int> clearAllData() {
    return customUpdate('''DELETE FROM songs; DELETE FROM playlists; DELETE FROM playlistSongs;
      DELETE FROM likedSongs; DELETE FROM followedArtists; DELETE FROM userPreferences;
      DELETE FROM playHistory; DELETE FROM playsessions;''');
  }
}

final appDatabaseProvider = FutureProvider<AppDatabase>((ref) async {
  final db = AppDatabase.open('miyu.db');
  await db.onUpgrade(Migrator(db), 0, db.schemaVersion);
  return db;
}, name: 'appDatabaseProvider');
