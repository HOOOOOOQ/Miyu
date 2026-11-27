# STAGE 1 — Source Code Audit Report

## 1. Repository Overview

| Field | Value |
|---|---|
| Repository | `HOOOOOOQ/Miyu` (clone for build: `HOOOOOOQ/Auralys_src.git`) |
| Clone path | `auralys-original/` |
| Original app name | **Miyu** (rebrand of the decompiled app `Auralys`) |
| Package name | `app.miyu.my.id` |
| Build variant | `dist/Miyu-4.8.0.apk` |
| Version (from `dist/README.md`) | **4.8.0**, versionCode **473** |
| Architecture | Decompiled Android app (apktool + smali), NOT original Flutter source |
| Components | smali/smali_classes2/smali_classes3 (DEX disassembly), classes.dex, lib/arm64-v8a, armeabi-v7a, x86, x86_64 (native libs), assets, res/, Kotlin stdlib classes |

The original `Auralys` app is a native Android music player (Metrolist player lineage). **No original Flutter source exists**, so we implement a clean Flutter app and reuse discovered APIs/backend/auth.

## 2. Existing APIs Discovered

| Service | Base URL | Notes |
|---|---|---|
| YouTube Music (unofficial/reverse-engineered via `youtubei/v1`) | `https://music.youtube.com`, `https://m.youtube.com/youtubei/v1` | Primary music provider, reverse-engineered player config (`ZemerTeam/zemer-cipher`, embedded `libquickjs.so`) |
| Player config | `https://raw.githubusercontent.com/ZemerTeam/zemer-cipher/master/library/src/main/assets/player_configs.json` | Used by player |
| Lyrics APIs (multiple) | `https://api-lyrics.simpmusic.org/v1/`, `https://lyrics-api.binimum.org/`, `https://lyrics-api.boidu.dev`, `https://lyrics.kugou.com/search`, `https://lyrics.paxsenix.org`, `https://lyricsplus.atomix.one/`, `https://lyricsplus.binimum.org`, `https://lyricsplus.prjktla.my.id`, `https://search.zemer.io/lyrics/resolve` | Lyrics providers |
| Return YouTube Dislike | `https://returnyoutubedislikeapi.com/Votes` | Rating integration |
| Apple Music | `https://music.apple.com/` (public) | Metadata |
| Lyrics translation (public keys, redacted) | `https://openrouter.ai/api/v1/chat/completions`, DeepL (redacted key) | Optional extras |

## 3. Backend / Infrastructure

- **No backend server discovered.** The original app is client-side (reverse-engineered YouTube Music + embedded player).
- No MongoDB/Supabase/Firebase backend integrations found in the source.
- "Backend reuse" = reuse the original YouTube Music API integration.

## 4. Authentication

- **YouTube account OAuth** (via `music.youtube.com`/`m.youtube.com` auth flows). ~724 OAuth references found in smali.
- No Google Sign-In, FirebaseAuth, or dedicated backend auth.
- Account is optional in the original app.

## 5. Music Providers

1. YouTube Music (official reverse-engineered player — no Play Music; there is a `misc.scdn.co/liked-songs` view)
2. Local device music (MediaStore — `READ_EXTERNAL_STORAGE`, `READ_MEDIA_AUDIO`, `WRITE_EXTERNAL_STORAGE`)

## 6. Permissions (original)

INTERNET, ACCESS_NETWORK_STATE, FOREGROUND_SERVICE, FOREGROUND_SERVICE_MEDIA_PLAYBACK, FOREGROUND_SERVICE_DATA_SYNC, FOREGROUND_SERVICE_MICROPHONE, POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED, WAKE_LOCK, SYSTEM_ALERT_WINDOW, SCHEDULE_EXACT_ALARM, RECORD_AUDIO, CAMERA, READ_MEDIA_AUDIO, READ_EXTERNAL_STORAGE, WRITE_EXTERNAL_STORAGE

## 7. Profile System Discovered

The original repo contains a profile module (`MiyuProfile/`) with blue verification badge, admin code, level from real data (see `dist/PROFILE-UI-474.md`). The new Flutter app implements the Miyu profile with level system.

## 8. Configuration Inventory (secrets redacted)

| Service | Type | Where used | Status |
|---|---|---|---|
| YouTube Music API (`music.youtube.com`, `m.youtube.com`) | Public client config | All player features | Valid/public |
| Lyrics APIs (list above) | Public endpoints | Lyrics panel | Public, no key needed |
| OpenRouter API (redacted `sk-...`) | Public (optional extras) | Lyrics translation | Optional |
| DeepL (redacted key) | Public-ish (optional) | Translation | Optional |
| AIza... keys (2x, redacted) | Public client keys | Likely Google APIs (player/misc) | Public, reusable in app |
| DiscordTokenStore | Public/internal | Optional integration | Internal |
| No private admin secrets | — | — | None found |

## 9. Limitations Discovered

- Original streaming player is reverse-engineered; a Flutter re-implementation must re-implement it.
- No existing Firebase/auth backend — document in final report.
