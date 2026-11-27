# Miyu — Android Music Player (Flutter)

Modern Android music application named **Miyu**, built on Flutter/Dart 3 with Material Design 3, Riverpod, Drift + SQLite, Dio, just_audio, audio_service, cached_network_image, palette_generator, flutter_animate, shared_preferences.

Original source reference: `auralys-original/` (HOOOOOOQ/Auralys_src.git — decompiled, rebranded to Miyu). See `AUDIT_REPORT.md` and `FINAL_REPORT.md`.

## Architecture

```
lib/
  main.dart            entry
  app.dart             MaterialApp (light/dark, style-aware)
  theme/theme.dart     MIYU palette, Flat/Glass styles, mode switch
  core/                constants, app_prefs (SharedPreferences)
  domain/              models, level_service
  data/
    remote/            api_client (Dio), api_config, interceptors, services (ytmusic, lyrics)
    local/             database.dart (Drift + SQLite)
  features/            splash, auth, home, search, library, player, profile, settings
  player/              player_engine, background_service
  widgets/             miyu_logo, cover_card
```

## Features

- Splash + 3 intro cards + login (YouTube Music) + continue without account
- Home: greeting, recently played, continue listening, recommendations, new releases, popular artists, recent albums, playlists, local music
- Search: songs/albums/artists/playlists, live search, history
- Library: liked songs, playlists, downloads, followed artists, recents, local music, albums
- Player: artwork, play/pause/prev/next, seek, shuffle, repeat, queue, lyrics, like, sleep timer, speed, mini + full player
- Background playback via Android media notification + lock screen (audio_service + just_audio)
- Profile: level system from real listening records (180 min/level, max 100), titles, verification, admin
- Settings: playback, appearance (Flat/Glass, Light/Dark/System), storage, backup/restore, privacy, account, about

## Level System (spec)

```
menit      = totalMs ~/ 60000
level      = min((menit ~/ 180) + 1, 100)
progress   = level >= 100 ? 100 : (menit % 180) * 100 / 180
menitKeBerikutnya = level >= 100 ? 0 : 180 - (menit % 180)
```

## Build

```
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Note: in the environment this was developed, Flutter/Dart were not installed and pub.dev was unreachable — see FINAL_REPORT.md for actual outputs.

## Brand

Name: **Miyu**; package: `app.miyu.my.id` (original app ID, preserved). Colors from the original palette. Fonts: Figtree + Plus Jakarta Sans (Arimo in the bundled set).
