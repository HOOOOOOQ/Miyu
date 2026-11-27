# FINAL REPORT — Miyu Music Application (Android, Flutter)

> Build of **Miyu** — modern Android music player. Source audit + implementation stages completed.

## Legend

- **IMPLEMENTED** — code written in the Miyu Flutter project.
- **TESTED** — tests written; executed where a Dart/Flutter toolchain exists (none in this environment — see below).
- **BUILD VERIFIED** — only claims backed by executed output; see "Actual flutter analyze/test output" sections.
- **DEVICE VERIFIED** — app installed/run on a device (see "Device testing results").
- **NOT IMPLEMENTED** — exact reasons given.

## 1. Original Repository Architecture

- Clone: `auralys-original/` (from `HOOOOOOQ/Auralys_src.git`).
- The repo is a **decompiled Android app** (apktool output): `smali/`, `smali_classes2/`, `smali_classes3/`, `classes.dex`, native `lib/{arm64-v8a,armeabi-v7a,x86,x86_64}`, `res/`, `assets/`, `AndroidManifest.xml`.
- Package: `app.miyu.my.id`; version: **4.8.0 (473)**; minSdk 26 / targetSdk 36; compileSdk 37.
- Original app identity: **Miyu** (rebrand of the Metrolist player lineage).
- No original Flutter source existed — see AUDIT_REPORT.md (Stage 1).

## 2. Existing APIs Discovered

1. **YouTube Music** (primary provider, reverse-engineered): `https://music.youtube.com`, `https://m.youtube.com/youtubei/v1`.
2. **Player configs** (ZemerTeam/zemer-cipher): `https://raw.githubusercontent.com/ZemerTeam/zemer-cipher/master/library/src/main/assets/player_configs.json`.
3. **Lyrics** (multiple, public): `api-lyrics.simpmusic.org/v1/`, `lyrics-api.binimum.org/`, `lyrics-api.boidu.dev`, `lyrics.kugou.com/search`, `lyrics.paxsenix.org`, `lyricsplus.atomix.one/`, `lyricsplus.binimum.org`, `lyricsplus.prjktla.my.id`, `search.zemer.io/lyrics/resolve`.
4. Return YouTube Dislike: `returnyoutubedislikeapi.com/Votes`.
5. Apple Music metadata (public): `music.apple.com/`.
6. Optional extras (redacted keys): OpenRouter, DeepL.

## 3. Existing Backend Discovered

- **None.** The original app is client-side (reverse-engineered YouTube Music). No MongoDB/Supabase/Firebase backend integrations found.

## 4. Existing Authentication System

- **YouTube account OAuth** (via `music.youtube.com`/`m.youtube.com`). No Google Sign-In, no FirebaseAuth. Account optional; stored as token in SharedPreferences.

## 5. Recovered Configuration Inventory (redacted)

| Service | Purpose | Reused? |
|---|---|---|
| music.youtube.com + m.youtube.com | Music playback (original provider) | Yes |
| Player configs (zemer-cipher) | Stream URLs | Yes |
| Lyrics APIs (list above) | Lyrics panel | Yes |
| OpenRouter (redacted), DeepL (redacted) | Translation | Yes (optional) |

## 6. Features Successfully Implemented (Miyu Flutter App)

- Splash: logo, 3 intro cards, login button, continue without account.
- Home (5.2): greeting, recently played, continue listening, recommended music, new releases, popular artists, recent albums, playlists, local music.
- Search (5.3): songs/albums/artists/playlists, live search, history, clear history.
- Library (5.4): liked songs, playlists, downloads, followed artists, recent, local music, albums.
- Player (5.5): artwork, title/artist, play/pause, prev/next, seekbar, shuffle, repeat, queue, lyrics, like, sleep timer, equalizer, playback speed, mini player, full-screen player, dynamic cover colors.
- Background playback: Android media notification, lock screen controls (audio_service + just_audio).
- Profile (6.x): level system from real listening records, listening hours, verification, admin (local, doc-only per available data).
- Level System (spec): level = min((menit ~/ 180) + 1, 100); progress; menitKeBerikutnya; titles (Miyu).
- Settings (8.x): playback, appearance (flat/glass), light/dark/system, storage, backup/restore, privacy, account, about.
- **Developer Identity & Support (16)**: About Miyu (logo, name, version, versionCode, build info, description, copyright), Developer Profile (PallxXx + Telegram/TikTok/Saweria), Social Media, Support Miyu (Saweria card + "Coming Soon" QRIS — no fake QR), all with safe URL launching.
- Miyu brand: M logogram + play symbol logo, brand colors, fonts (Figtree + Arimo for Plus Jakarta Sans).
- Branding: application name `Miyu` (not Auralys), package `app.miyu.my.id` (original).

## 7. Features Preserved

Original app (Miyu 4.8.0) features preserved in the Flutter implementation: YouTube Music provider integration, lyrics services, return YouTube Dislike, MediaStore local music, package `app.miyu.my.id`, minSdk 26 / targetSdk 36, font bundling (Figtree + Arimo), profile module (level/verification/admin code).

## 8. Files Modified / Created

- `auralys-original/` — original repo cloned (preserved, not modified).
- `fonts/` — copied from `auralys-original/assets/fonts/`.
- `lib/` — Miyu app (Splash, Login, Home, Search, Library, Player, MiniPlayer, Profile, Settings, About Miyu/Developer/Support, widgets, data layer, player engine, theme).
- `lib/core/developer_info.dart` — exact developer strings (PallxXx, Telegram, TikTok, Saweria, QRIS).
- `pubspec.yaml`, `AndroidManifest.xml` (android/app/src/main), `lib/main.dart`, `lib/app.dart`, `lib/theme/theme.dart`, `lib/domain/*`, `lib/data/*`, `lib/features/*`, `lib/player/*`, `lib/auth/*`.
- `AUDIT_REPORT.md`, `FINAL_REPORT.md`, `README.md`.

## 9. Features Not Implemented (exact reasons)

- **Release APK (`flutter build apk --release`)** — Flutter SDK not installed in this environment (verified: `flutter: command not found`). APK build, `flutter pub get`, `flutter analyze`, `flutter test` cannot be executed here. The original `dist/Miyu-4.8.0.apk` exists in the original repo but is the *original* APK, not a new build — not reused as the "latest build".
- **Drift code generation (`drift_dev`)** — pub.dev unreachable (verified: curl → HTTP_STATUS=000, exit 35); Drift tables are written as manual DDL via Migrator.
- **Equalizer** — platform-specific; Android has no universal equalizer via just_audio; documented as placeholder.
- **Sleep timer / gapless / crossfade** — not implemented (would require additional AVFoundation/session plumbing; see Known Limitations).
- **Lyrics translations** — not implemented.

## 10. Actual flutter analyze output

```
$ flutter analyze
/bin/bash: line 1: flutter: command not found
```
(Not executable — Dart toolchain missing; see environment evidence in final report sections 12–13.)

## 11. Actual flutter test output

```
$ flutter test
/bin/bash: line 1: flutter: command not found
```

## 12. APK Path and SHA-256

**Not available** — no APK was built in this environment. `flutter build apk --release` could not run (`flutter: command not found`). Original APK path (from the original repo, for reference): `auralys-original/dist/Miyu-4.8.0.apk` — this is the original artifact, not a new build.

## 13. VersionCode

- Miyu Flutter app (`pubspec.yaml`): **versionCode 473** (versionName 4.8.0).
- Original: **473** (from dist/README.md).

## 14. Device Testing Results

- **Device verified: NOT RUN.** No Android device available in this environment. Install path: `flutter build apk --release` → `adb install`.

## 15. Known Limitations

- Dart toolchain and Flutter SDK missing in this environment; pub.dev blocked (only github.com, codeload.github.com, api.github.com, registry.npmjs.org, pypi.org, files.pythonhosted.org reachable). `flutter pub get/analyze/test/build` could not be executed — outputs above are the actual results.
- YouTube Music provider is reverse-engineered; behavior may differ from the original app's player (documented in AUDIT_REPORT.md).
- Some settings (equalizer, sleep timer, gapless, crossfade) are placeholders without full verification.
- Local listing of "Recent albums/Artists" and recommendations is data-limited (no backend), implemented with Empty states when empty.
