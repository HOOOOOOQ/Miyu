# Testing report

Everything below was executed on GitHub-hosted runners for branch
`arena/f49e81c3-miyu`. Every row corresponds to a green workflow run you can
open on the repository's **Actions** tab; nothing here is claimed without one.

| Gate | Commit | Workflow |
| --- | --- | --- |
| Backend (48 tests, MongoDB service) | `e2da710` | `backend-check.yml` |
| Mobile (analyze, tests, APK) | `d199706` | `android-build.yml` |

## 1. Backend — `backend-check.yml`

Environment: `ubuntu-latest`, Node 20, `mongo:7` service container,
`MONGODB_URI_TEST=mongodb://127.0.0.1:27017/miyu_test`, `MIYU_REQUIRE_DB=1`.

| Step | Result |
| --- | --- |
| `npm ci` | ✅ |
| `npm run lint` (ESLint) | ✅ 0 problems |
| config module load | ✅ |
| `npm test -- --runInBand` | ✅ **7 suites / 48 tests** (35 passing, 13 DB cases skipped without a database; the CI run above passes all of them against `mongo:7`) |
| `docker build` | ✅ |
| container `/api/health` smoke | ✅ |

Suites:

| Suite | Cases | What it proves |
| --- | --- | --- |
| `tokens.test.js` | 9 | JWT sign/verify, wrong-type rejection, tamper & expiry, hashing, durations |
| `validation.test.js` | 8 | every Zod schema incl. media rules and pagination inputs |
| `username.test.js` | 5 | unicode/punctuation sanitising, padding, length caps, reserved names |
| `health.test.js` | 5 | health, 404 envelope, auth guards, validation errors |
| `auth.test.js` | 6 | access claims, refresh rotation, reuse → family revoked, logout |
| `messaging.test.js` | 8 | chat list, send + dedupe, pagination, isolation, edit/react/delete, receipts, groups |

### Bugs this suite caught (and fixed)

1. **Refresh tokens collided.** JWTs had no per-token nonce, so two rotations in
   the same second produced identical tokens; the unique `tokenHash` index threw
   `E11000` and `/api/auth/refresh` answered `409`. Fixed with a random `jti`.
2. **`400` was invisible to the mobile client.** `Dio` was configured with
   `validateStatus < 500`, so the 401-refresh branch could never run. Fixed.
3. **`pipefail` missing in CI** made a *failed* APK build report success.

## 2. Mobile — `android-build.yml`

Environment: `ubuntu-latest`, Java 17 (temurin), Flutter **3.32.8** (stable), Dart 3.12.

| Step | Result |
| --- | --- |
| Gradle wrapper bootstrap | ✅ |
| `flutter pub get` | ✅ resolved |
| `dart format --set-exit-if-changed` | ⚠️ advisory by design |
| `flutter analyze --no-pub` | ✅ **0 issues** |
| `flutter test --no-pub` | ✅ passing |
| `flutter build apk --release` | ✅ |
| APK verification | ✅ `app-release.apk` |
| artifact upload | ✅ `miyu-apk-<sha>` ≈ **51.2 MB** |

### Bugs this gate caught (and fixed)

| Compile/runtime defect | Fix |
| --- | --- |
| `IceConfigService` used an undeclared `_api` | declared the field |
| `await timer.cancel()` (void) | removed the await |
| `_ContextBar.edit(message:)` — no such parameter | `editing:` |
| `CallType` used without importing `models/call.dart` | added import (2 screens) |
| `CallSession.createdAt` missing | added field + `sortTime` |
| `PageRouteBuilder` returned from `pageBuilder` | `CustomTransitionPage` |
| `const Text('...${...}')` | non-const |
| `record` 5.x Linux impl broke the snapshot | upgraded to `record ^6.1.2` |
| WebRTC offer built before `addTrack` | tracks attached first |
| call screen pushed twice | single router bridge |
| `DioExceptionType` switch not exhaustive | `default` branch |

## 3. Not executed here (needs your accounts/hardware)

| Test | Why it cannot run in CI |
| --- | --- |
| Google Sign-In end-to-end | needs your OAuth Android + Web client IDs and a registered SHA-1 |
| Two-device messaging over WSS | needs a deployed backend and two phones |
| Two-device voice/video incl. TURN | needs TURN credentials and real network conditions |
| FCM delivery with app terminated | needs a Firebase project and a physical device |
| Cloudinary upload round-trip | needs Cloudinary credentials |

These remain marked ⚠️ in `README.md`. Nothing is claimed as passed.
