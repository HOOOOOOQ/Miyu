# STAGE 11 — GitHub Actions Android APK Build (Report)

Project: `/home/user/Miyu` · Package: `app.miyu.my.id` · Version: `4.8.0 (473)`

## 1. Project Inspection

| Item | Result |
|---|---|
| `pubspec.yaml` | ✅ Valid (Riverpod, Drift, Dio, just_audio, audio_service, url_launcher, cached_network_image, palette_generator, flutter_animate, shared_preferences) |
| `lib/` | ✅ 31 Dart files (splash, auth, home, search, library, player, profile, settings, about_miyu, widgets, domain, data, player) |
| `test/` | ✅ `level_service_test.dart` (moved from lib/domain) |
| `android/` | ✅ Created: settings.gradle, build.gradle (root), app/build.gradle, gradle/wrapper, gradlew, gradlew.bat, app/src/main/MainActivity.kt, AndroidManifest.xml |
| AGP | 8.5.2 (android/build.gradle) |
| Gradle Wrapper | 8.9 (`gradle-wrapper.properties`) |
| Kotlin | 1.9.24 (root + app build.gradle) |
| Java | 17 (app build.gradle: source/targetCompatibility VERSION_17) |
| AndroidManifest | `package="app.miyu.my.id"`, minSdk 26, targetSdk 36 |
| versionName | `4.8.0` ✅ |
| versionCode | `473` ✅ |

## 2. GitHub Actions Workflow Created

`​.github/workflows/build-miyu.yml` — workflow "Build Miyu APK":

```yaml
name: Build Miyu APK
on:
  push:
    branches: [main]
  workflow_dispatch:
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - checkout @ actions/checkout@v4
      - setup-java 17 (temurin)
      - subosito/flutter-action → Flutter 3.41.3
      - flutter --version
      - flutter doctor -v
      - flutter pub get
      - dart format --output=none --set-exit-if-changed lib test
      - flutter analyze
      - flutter test
      - flutter build apk --release
      - Verify APK metadata (sha256sum, unzip manifest)
      - actions/upload-artifact@v4 → Miyu-4.8.0-473-Release (30 days)
```

Committed to branch `arena/ac0c027c-miyu`:

```
62be48f Stage 11: GitHub Actions workflow for Miyu APK build + Android project files
```

## 3. Local Build Attempt (evidence)

```
=== dart --version ===
/bin/bash: line 1: dart: command not found
=== flutter --version ===
/bin/bash: line 1: flutter: command not found
```

**NOT EXECUTED locally.**

## 4. GitHub Actions Attempt (evidence)

```
=== gh workflow run build-miyu.yml --repo HOOOOOOQ/Miyu --ref arena/ac0c027c-miyu ===
HTTP 404: Not Found (https://api.github.com/repos/HOOOOOOQ/Miyu/actions/workflows/build-miyu.yml)

=== direct dispatches POST ===
{"message":"Resource not accessible by integration"} (HTTP 403)

=== gh workflow run "Android build" (existing registered workflow) ===
HTTP 403: Resource not accessible by integration
```

Findings:

- `gh` is installed (v2.23.0) and authenticated as HOOOOOOQ, but workflow dispatch is blocked (403, integration permissions).
- `gh run list` on branch `arena/ac0c027c-miyu` → empty (no runs triggered).
- Root cause: GitHub Actions workflows are registered from the default branch; my new workflow is on a non-default branch (`arena/ac0c027c-miyu`), so the API cannot find it (404). Session rules prohibit pushing to other branches.

## 5. APK Verification

**NOT VERIFIED — no APK produced.** Expected path: `build/app/outputs/flutter-apk/app-release.apk`. The workflow includes a "Verify APK metadata" step (ls, sha256sum, manifest package check).

## 6. Status Summary

| Status | Items |
|---|---|
| **IMPLEMENTED** | `.github/workflows/build-miyu.yml`, android/ files (settings.gradle, build.gradle, app/build.gradle, gradlew, MainActivity.kt, AndroidManifest.xml) |
| **BUILD VERIFIED** | ❌ NOT — local Flutter/Dart missing; GitHub Actions dispatch blocked (403) |
| **DEVICE VERIFIED** | ❌ NOT — no device |

## 7. Known Limitations

1. No Flutter/Dart SDK in this environment → `flutter build`/`dart format`/`flutter analyze`/`flutter test` not executable locally.
2. pub.dev blocked (HTTP_STATUS=000, exit 35) — `flutter pub get` would fail.
3. GitHub Actions dispatch blocked (403) — workflows on non-default branch cannot be dispatched; could not trigger the new Android build.
4. `dart format --set-exit-if-changed` step will likely fail on first run until sources are formatted (no local dart available) — run `dart format` once a toolchain is available.
5. No signing keystore (`ANDROID_KEYSTORE`) configured in the workflow — release build will need credentials or env vars.
