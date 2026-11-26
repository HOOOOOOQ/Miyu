# Miyu — Local installation

This guide takes a fresh machine to a running Miyu stack: Node backend, MongoDB
Atlas database, and the Flutter Android app.

## 1. Prerequisites

| Tool | Version | Notes |
| --- | --- | --- |
| Flutter | 3.24.x (stable) | `flutter --version` |
| Dart | 3.5.x | ships with Flutter |
| Java JDK | 17 | required by Android Gradle Plugin 8.3 |
| Android SDK | API 35 | install via Android Studio or `sdkmanager` |
| Node.js | 20 LTS or 22 | `node --version` |
| npm | 10+ | `npm --version` |
| MongoDB Atlas | free M0 tier | see `MONGODB_SETUP.md` |
| Git | any recent | |

```bash
flutter doctor -v        # resolve every red X before continuing
java -version            # must report 17
```

## 2. Clone and install

```bash
git clone https://github.com/<you>/Miyu.git
cd Miyu

# Backend
cd backend
cp .env.example .env     # fill in real values (see docs)
npm install

# Mobile
cd ../mobile
flutter pub get
```

## 3. Configure the backend

Edit `backend/.env`:

```dotenv
NODE_ENV=development
PORT=5000
MONGODB_URI=mongodb+srv://...
JWT_ACCESS_SECRET=...   # openssl rand -hex 64
JWT_REFRESH_SECRET=...  # openssl rand -hex 64
GOOGLE_CLIENT_ID=...apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=...
```

Optional but recommended for full functionality:
`TURN_URL`, `TURN_USERNAME`, `TURN_CREDENTIAL` (calls across strict networks),
`CLOUDINARY_*` (media upload), `FIREBASE_*` (push notifications).

Start it:

```bash
cd backend
npm run dev
curl http://localhost:5000/api/health
# {"success":true,"data":{"status":"ok",...}}
```

## 4. Run the Android app

The emulator reaches your host machine at `10.0.2.2`, which is the default
`API_BASE_URL`. For a physical device on the same Wi-Fi use your LAN IP.

```bash
cd mobile

# Emulator (default http://10.0.2.2:5000)
flutter run

# Physical device
flutter run \
  --dart-define=API_BASE_URL=http://192.168.1.25:5000 \
  --dart-define=SOCKET_URL=http://192.168.1.25:5000

# Release APK against a deployed backend
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.your-domain.com \
  --dart-define=SOCKET_URL=https://api.your-domain.com \
  --dart-define=APP_ENV=production \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=1234567890-xxxx.apps.googleusercontent.com
```

The output APK lives at `mobile/build/app/outputs/flutter-apk/app-release.apk`.

## 5. Verify the install

1. App opens on the onboarding screen and the Google button is visible.
2. `Continue with Google` returns to the app and lands on **Chats**.
3. MongoDB Atlas → `miyu.users` contains your account.
4. Install the app on a second device/emulator, sign in with another Google
   account, search for the first user in **Contacts**, and send a message.
5. Kill and reopen the app: the conversation is still there (server-backed).

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `ApiException … cannot reach servers` | backend not running, or wrong `API_BASE_URL` |
| Google sign-in fails immediately | SHA-1 not registered — see `GOOGLE_AUTH.md` |
| `DEVELOPER_ERROR` from Google | OAuth client package name must be `com.miyu.messaging` |
| Build fails on Java version | `java -version` must be 17 |
| `google-services.json` missing warning | optional; add it for push notifications |
| Media upload returns `MEDIA_NOT_CONFIGURED` | set Cloudinary env vars — see `WEBRTC_SETUP.md` sibling section |
