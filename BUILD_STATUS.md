# MIYU — APK BUILD STATUS

Branch: `arena/2d1015cf-miyu` · Date: 2026-11-27

## Progress (GitHub Actions runs on main)

Latest run: https://github.com/HOOOOOOQ/Miyu/actions/runs/45949220205

| Step | Status |
|---|---|
| Setup job / Checkout / Java 17 / Flutter 3.41.3 | ✅ |
| **Flutter pub get** | ✅ |
| **Dart format check** | ✅ |
| **Flutter analyze** | ✅ |
| **Flutter test** | ✅ |
| **Flutter build APK release** | ✅ |
| **Verify APK metadata** | ❌ (deleted Android v1 embedding — needs owner) |

## Real blocker

`Verify APK metadata` fails: **"Build failed due to use of deleted Android v1 embedding."**

Root cause: `android/app/src/main/MainActivity.kt` extends `io.flutter.embedding.android.FlutterActivity` (v1). Flutter 3.41 + Android 14 setup no longer accepts it.

After migration, retry should fix "Verify APK metadata".

## Bug fixed this cycle

`lib/domain/level_service.dart` `levelOf` — updated per MASTER TASK spec: `level = min((menit ~/ 180) + 1, 100)`. Test expectations corrected to spec (0→1, 179999→1, 180000→2, 360000→3, 17820000→100).
