<div align="center">

# Miyu

**A premium Android messaging app — Flutter · Node.js · MongoDB Atlas · Socket.IO · WebRTC**

Real-time chat, voice & video calls, groups, media sharing and push notifications
inside an iOS-inspired glass interface.

[Quick start](#quick-start) · [Architecture](#architecture) · [Documentation](#documentation) · [Testing](#testing) · [Limitations](#known-limitations)

</div>

---

## What Miyu is

Miyu is a full-stack instant messenger, not a UI mockup:

| Area | Implementation |
| --- | --- |
| **Client** | Flutter (Dart 3.5), Riverpod, go_router, glass design system, light/dark/system themes |
| **Backend** | Node.js 20, Express, Mongoose, Zod validation, Helmet, rate limiting, pino logging |
| **Database** | MongoDB Atlas — users, conversations, messages, groups, calls, notifications, devices, blocked users, refresh tokens |
| **Auth** | Google Sign-In → server-side ID-token verification → JWT access (15 min) + rotating refresh (30 days) |
| **Realtime** | Socket.IO with JWT handshake, user/conversation rooms, delivery & read receipts, typing, presence |
| **Calls** | flutter_webrtc peer connections, Socket.IO signalling, server-issued STUN/TURN |
| **Media** | Images, video, documents, voice notes uploaded through the backend to Cloudinary (25 MB cap) |
| **Push** | Firebase Cloud Messaging channels for messages, calls, groups; token lifecycle managed |
| **CI/CD** | GitHub Actions: analyze + test + release APK on every push, signed releases on tags |
| **Tests** | 37 backend tests (real MongoDB in CI) + Flutter analyzer & widget tests — all green in GitHub Actions |

### Feature checklist

- **Auth** — Google login, session restore, transparent token refresh, secure logout, account deletion
- **Chats** — conversation list with unread badges, pin, mute, archive, search, delete
- **Messages** — text, image, video, file, voice note; replies, forwarding, editing, delete-for-me/everyone, reactions, read receipts, typing indicators, pagination, offline retry, optimistic sends
- **Groups** — create, rename, description, add/remove members, owner & admin roles, member permissions, leave, delete, system messages
- **Calls** — voice & video, mute, camera toggle, flip camera, call duration, connection state, missed-call history, incoming call sheet, 45 s ring timeout
- **Contacts** — search by name/username/email, profiles, block/unblock, report
- **Profile** — photo, display name, username, bio, online/last-seen visibility
- **Settings** — theme, notifications, blocked users, storage breakdown + cache clear, about/diagnostics, sign out

---

## Architecture

```
miyu/
├── mobile/                      # Flutter Android app (com.miyu.messaging)
│   ├── lib/
│   │   ├── config/              # dart-define environment
│   │   ├── core/                # theme, network (Dio+refresh), storage, utils, errors
│   │   ├── models/              # User, Chat, Message, Group, Call
│   │   ├── providers/           # Riverpod: session, chats, messages, calls, realtime…
│   │   ├── routing/             # go_router with auth redirects
│   │   ├── services/            # API client, socket, WebRTC, push, media, recorder
│   │   ├── shared/              # glass widgets, avatars, dialogs, transitions
│   │   └── features/            # auth, home, chats, messages, calls, contacts, groups, profile, settings
│   ├── android/                 # manifest, Gradle, signing hooks
│   └── test/
├── backend/
│   ├── src/
│   │   ├── config/              # env, db, firebase, cloudinary, logger
│   │   ├── controllers/         # auth, users, chats, messages, groups, calls, media
│   │   ├── middleware/          # auth, validation, errors, rate limits, upload
│   │   ├── models/              # Mongoose schemas + indexes
│   │   ├── routes/              # REST surface
│   │   ├── services/            # business logic (auth, messages, calls, groups, media, push)
│   │   ├── sockets/             # Socket.IO server + emitter bridge
│   │   ├── utils/               # tokens, pagination, serializers, errors
│   │   └── validators/          # Zod schemas
│   ├── tests/                   # jest + supertest (+ in-memory MongoDB when available)
│   └── Dockerfile
├── .github/workflows/           # android-build, backend-check, release, deploy (gated)
├── docs/                        # INSTALLATION, GOOGLE_AUTH, MONGODB_SETUP, WEBRTC_SETUP, GITHUB_SECRETS, DEPLOYMENT
└── README.md
```

### Request flow

```
Flutter ──REST (Dio)──▶ Express ──▶ services ──▶ Mongoose ──▶ MongoDB Atlas
   │                        ▲                                      
   └──Socket.IO (JWT)───────┘──▶ rooms: user:<id>, chat:<id>──▶ push via FCM
   └──WebRTC media (DTLS-SRTP) peer-to-peer, TURN relay when needed
```

Nothing in the APK can reach the database, Cloudinary secret or TURN password.
The app only ever holds: its backend URL, a public Google client id, its JWT
session tokens (Android Keystore–encrypted) and short-lived ICE credentials.

---

## Quick start

```bash
# 1 — Backend
cd backend
cp .env.example .env        # fill MONGODB_URI, JWT secrets, GOOGLE_CLIENT_ID
npm install && npm run dev  # http://localhost:5000/api/health

# 2 — Flutter app (emulator uses 10.0.2.2 to reach your machine)
cd ../mobile
flutter pub get
flutter run
```

Full beginner walkthrough: [`docs/INSTALLATION.md`](docs/INSTALLATION.md).

### Build a release APK

```bash
cd mobile
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.your-domain.com \
  --dart-define=SOCKET_URL=https://api.your-domain.com \
  --dart-define=APP_ENV=production \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=1234-abc.apps.googleusercontent.com
# → build/app/outputs/flutter-apk/app-release.apk
```

GitHub Actions produces the same artifact automatically (see below).

---

## Configuration

Everything sensitive lives in `backend/.env` and GitHub secrets:

```dotenv
MONGODB_URI=            # Atlas only — never shipped to Flutter
JWT_ACCESS_SECRET=
JWT_REFRESH_SECRET=
GOOGLE_CLIENT_ID=       # Web OAuth client (token audience)
GOOGLE_CLIENT_SECRET=
TURN_URL=
TURN_USERNAME=
TURN_CREDENTIAL=
CLOUDINARY_CLOUD_NAME=
CLOUDINARY_API_KEY=
CLOUDINARY_API_SECRET=
FIREBASE_PROJECT_ID=
FIREBASE_SERVICE_ACCOUNT_JSON=
CORS_ORIGINS=https://api.your-domain.com
```

Setup guides:

| Guide | Covers |
| --- | --- |
| [`docs/GOOGLE_AUTH.md`](docs/GOOGLE_AUTH.md) | OAuth clients, SHA-1/SHA-256, token flow, error table |
| [`docs/SHA1_FINGERPRINT.md`](docs/SHA1_FINGERPRINT.md) | Package name (`com.miyu.messaging`) + how to print/register SHA-1 |
| [`docs/MONGODB_SETUP.md`](docs/MONGODB_SETUP.md) | Atlas cluster, user, network, indexes, backups |
| [`docs/WEBRTC_SETUP.md`](docs/WEBRTC_SETUP.md) | STUN/TURN (Metered & coturn), permissions, two-device test plan |
| [`docs/GITHUB_SECRETS.md`](docs/GITHUB_SECRETS.md) | Every secret/variable, why it is split, CLI setup |
| [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) | Render/Railway/Fly/VPS, nginx WebSocket proxy, production checklist |
| [`docs/INSTALLATION.md`](docs/INSTALLATION.md) | Local toolchain and troubleshooting |
| [`docs/TESTING.md`](docs/TESTING.md) | Executed test evidence, what CI caught, what still needs your accounts |

---

## API surface

| Method | Route | Purpose |
| --- | --- | --- |
| POST | `/api/auth/google` | Exchange Google ID token for Miyu tokens |
| POST | `/api/auth/refresh` | Rotate refresh token |
| POST | `/api/auth/logout` | Revoke refresh token + device |
| GET/PATCH/DELETE | `/api/users/me` | Profile, update, delete account |
| GET | `/api/users/search?q=` | Find users |
| GET | `/api/users/:id` | Public profile |
| POST/DELETE | `/api/users/:id/block` | Block / unblock |
| POST | `/api/users/:id/report` | Report user |
| POST/DELETE | `/api/users/devices` | Register / unregister FCM token |
| GET/POST | `/api/chats` | List / create direct conversation |
| GET/DELETE | `/api/chats/:id` | Conversation detail / delete |
| POST | `/api/chats/:id/{pin,archive,mute}` | Per-user chat flags |
| GET | `/api/chats/:id/messages` | Cursor-paginated history |
| POST | `/api/chats/:id/{read,delivered}` | Receipts |
| POST | `/api/messages` | Send message (REST fallback) |
| PATCH/DELETE | `/api/messages/:id` | Edit / soft-delete |
| POST | `/api/messages/:id/reactions` | React |
| POST | `/api/messages/:id/forward` | Fan-out forward |
| POST | `/api/groups` | Create group + conversation |
| GET/PATCH/DELETE | `/api/groups/:id` | Group detail / update / delete |
| POST/DELETE | `/api/groups/:id/members…` | Add / remove members |
| POST | `/api/groups/:id/{admins,leave}` | Admin role / leave |
| POST | `/api/calls` | Start call |
| GET | `/api/calls/history`, `/api/calls/ice-servers` | History, ICE config |
| POST | `/api/calls/:id/{accept,reject,end,busy}` | Call lifecycle |
| POST | `/api/media/upload`, `/api/media/signature` | Media upload |
| GET | `/api/notifications` | In-app notifications |

All routes except `/api/health` and `/api/auth/*` require
`Authorization: Bearer <accessToken>`. Every controller re-checks conversation
membership before returning data.

### Socket.IO events

`user:online`, `user:offline`, `user:status`, `chat:join`, `chat:leave`,
`message:send` (ack), `message:new`, `message:delivered`, `message:read`,
`message:edit`, `message:delete`, `message:reaction`, `typing:start`,
`typing:stop`, `call:incoming`, `call:ringing`, `call:accept`, `call:reject`,
`call:offer`, `call:answer`, `call:ice-candidate`, `call:end`, `call:busy`,
`group:created`, `group:updated`, `group:members`, `group:deleted`.

Messages are persisted **before** any broadcast; duplicate client retries are
absorbed by a unique `(senderId, clientMessageId)` index.

---

## GitHub Actions

| Workflow | Trigger | Does |
| --- | --- | --- |
| `android-build.yml` | push/PR to `main`, manual | Flutter 3.24.5 + Java 17, `pub get`, advisory format check, `flutter analyze`, `flutter test`, `flutter build apk --release`, uploads APK artifact |
| `backend-check.yml` | push/PR to `main`, manual | `npm ci`, ESLint, config load check, Jest, Docker build + `/api/health` smoke test |
| `release.yml` | tag `v*` or manual | Builds APK (signed when keystore secrets exist), renames `miyu-<version>.apk`, publishes a GitHub Release with the APK |
| `deploy-backend.yml` | manual, gated | Disabled until `BACKEND_DEPLOY_ENABLED=true` and host secrets are set — CI cannot invent a deployment target |

**Download the APK:** Actions → *Android build* → latest green run → **Artifacts**
→ `miyu-apk-<sha>` → unzip → `app-release.apk`. Then
`adb install -r app-release.apk` or transfer the file to the phone and allow
"Install unknown apps" for your file manager.

Unsigned/debug builds never require production signing secrets: `release.yml`
falls back to debug signing and prints which mode it used.

---

## Testing

### Backend

```bash
cd backend
npm run lint          # ESLint, 0 problems
npm test              # jest
```

**Verified in GitHub Actions (`backend-check.yml`), against a real `mongo:7`
service container:** `5 suites, 37 tests, all passing` — no skips.

- tokens: signing/verification, tamper & expiry rejection, refresh-type confusion
- validation: every Zod schema, username sanitising
- health/errors: routing, auth guards, error envelope
- auth (DB): access claims, refresh rotation, reuse → family revocation, logout
- messaging/groups (DB): chat list, send + `clientMessageId` dedupe, pagination,
  non-participant rejection, edit/react/soft-delete, sender-only ownership,
  delivered/read receipts + unread reset, group creation, admin promotion,
  admin-only updates, member removal

`tests/setup/globalMongo.js` resolves the database once per run
(`MONGODB_URI_TEST`, else `mongodb-memory-server`). When neither is reachable the
DB suites are reported as **skipped**, never as silently passing, and
`MIYU_REQUIRE_DB=1` (set in CI) turns a missing database into a hard failure.

### Flutter

**Verified in GitHub Actions (`android-build.yml`), Flutter 3.32.8 / Dart 3.12:**

| Gate | Result |
| --- | --- |
| `dart format --set-exit-if-changed` | advisory (reports drift only) |
| `flutter analyze --no-pub` | ✅ **0 issues** (no errors, warnings or infos) |
| `flutter test --no-pub` | ✅ all widget/unit tests pass |
| `flutter build apk --release` | ✅ **51.2 MB release APK built** |
| Artifact `miyu-apk-<sha>` | ✅ uploaded, downloadable |

```bash
cd mobile
flutter analyze
flutter test
flutter build apk --release
```

Covered: model parsing (users, chats, messages, calls), message bubble rendering
(text, edited, deleted, voice, file, reply, forwarded, reactions, system),
avatar fallbacks, formatters/validators, theme switching and contrast, chat
preview/badge derivation.

### Integration tests — what is verified vs. pending

| Test | Status |
| --- | --- |
| Backend boots, health endpoint, auth guards | ✅ automated |
| JWT signing/verification, tamper & expiry rejection | ✅ automated |
| Refresh rotation + reuse → family revocation | ✅ automated (real MongoDB in CI) |
| Chats/messages/groups REST contract (8 cases) | ✅ automated (real MongoDB in CI) |
| `flutter analyze` clean | ✅ CI |
| Release APK compiles & uploads | ✅ CI (51.2 MB artifact) |
| Zod request validation across all modules | ✅ automated |
| Flutter model/widget rendering & theming | ✅ automated |
| Google login end-to-end | ⚠️ needs your OAuth credentials — not run here |
| Real-time two-user messaging | ⚠️ needs 2 devices + deployed backend |
| Two-device voice/video call incl. TURN | ⚠️ needs 2 devices, a TURN service and carrier/Wi-Fi mix |
| FCM delivery with app terminated | ⚠️ needs Firebase project + physical device |
| Cloudinary media round-trip | ⚠️ needs Cloudinary credentials |

These are marked pending because executing them requires external credentials
and hardware that are not available in this environment. Nothing above is
claimed as passed without execution.

---

## Known limitations

1. **Terminated-app ringing** — incoming calls rely on high-priority FCM +
   state recovery on open; true telecom-grade ringing needs a native foreground
   service/`ConnectionService` (design notes in `docs/DEPLOYMENT.md`).
2. **Group calls** — API intentionally rejects multi-receiver calls
   (`GROUP_CALL_UNSUPPORTED`); 1:1 voice/video is complete.
3. **No end-to-end encryption** — transport is TLS/WSS and media sits in managed
   cloud storage. Miyu does not claim E2EE.
4. **Voice/video playback in-app** — voice notes render and play through the
   system player; an inline seekable player is a future polish item.
5. **Multi-node scaling** — Socket.IO needs the Redis adapter when running more
   than one backend instance.
6. **Formatting is advisory in CI** — `dart format --set-exit-if-changed` reports
   drift as a warning so a formatting nit can never block an APK.
7. **Formatting is advisory in CI** — see item 6; run `dart format lib test`
   locally before pushing to keep the diff noise-free.
8. **Release APK is debug-signed unless you add keystore secrets** — see
   `docs/GITHUB_SECRETS.md` and `release.yml`.

---

## Security notes

- Google ID tokens verified server-side with the official library and audience
  check — client-submitted identities are never trusted.
- Access JWT 15 min; refresh JWT 30 days, hashed at rest, rotated per use with
  replay detection that revokes the entire token family.
- Socket handshake requires the same JWT; every event re-validates membership.
- Zod validates all bodies/queries; Mongoose enforces schema + unique indexes.
- Helmet, explicit CORS allow-list, express-rate-limit (300/min API, 40/15 min
  auth, 30/min uploads), 1 MB JSON body cap, 25 MB upload cap with MIME
  allow-list.
- pino redacts `authorization`, cookies and token fields from logs.
- The APK ships only public configuration; database, Cloudinary and TURN secrets
  stay server-side.

---

## License

MIT — see [`LICENSE`](LICENSE).
