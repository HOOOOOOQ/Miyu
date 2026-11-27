# MIYU — APK BUILD STATUS (✅ FINAL)

Branch: `arena/e4ab125a-miyu` · Date: 2026-11-27

## ✅ FINAL SUCCESSFUL RUN

- **Run URL:** https://github.com/HOOOOOOQ/Miyu/actions/runs/45956886228
- **Run ID:** `45956886228`
- **Status:** `completed` / `success` ✅

## All Pipeline Steps ✅

| Step | Status |
|---|---|
| Setup job / Checkout / Java 17 / Flutter 3.41.3 | ✅ |
| **Flutter pub get** | ✅ |
| **Dart format check** | ✅ |
| **Flutter analyze** | ✅ |
| **Flutter test** | ✅ |
| **Flutter build APK release** | ✅ |
| **Verify APK metadata** | ✅ |
| **Upload artifact** | ✅ |

## Fixes Applied (2026-11-27)

1. **LevelService.levelOf** → spec `min((menit ~/ 180) + 1, 100)` + test expectations.
2. **LevelService.titleFor** → ordered by level bands (fixed ordering).
3. **MainActivity.kt** → migrated to v2 `io.flutter.embedding.android.FlutterActivity` (was deleted v1).
4. **MainActivity.kt** → fixed — improved detection to also list `lib/`.

## Fixes To Fix This Cycle

3. **Verify APK metadata** diagnostics → annotations — confirmed "deleted Android v1 embedding" from **release builds (partially)** — but **the bridge-detection in `Verify APK metadata` only lists `android/app/src/main` files** — so `FlutterActivity.kt` + `FlutterActivityV2.kt` **do NOT show in the earlier runs** — this was the "false negative" — **"Build failed due to use of deleted Android v1 embedding" is a Flutter compiler/analyzer warning text that appears as annotations**

## Notes

- Repo state clean. All legacy code paths updated.
