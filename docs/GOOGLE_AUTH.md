# Google authentication setup

Miyu uses Google Sign-In on device and verifies the ID token on the backend, so
identity is never trusted from the client.

## 1. Create the Google Cloud project

1. https://console.cloud.google.com → **New Project** → `Miyu`.
2. **APIs & Services → Library** → enable **Google Sign-In** (Google Identity).

## 2. OAuth consent screen

1. **APIs & Services → OAuth consent screen**.
2. User type: **External** (or Internal for Workspace-only testing).
3. App name: `Miyu`, support email, developer email.
4. Scopes: `email`, `profile`, `openid`.
5. Add test users while the app is in *Testing* mode.

## 3. Create OAuth clients

You need **three** client IDs in total.

### a) Android client

1. **Credentials → Create credentials → OAuth client ID → Android**.
2. Package name: `com.miyu.messaging`.
3. SHA-1 fingerprint — print it with the bundled helper:

```bash
cd mobile && bash tool/print_sha1.sh
```

or straight from the debug keystore:

```bash
keytool -list -v \
  -keystore ~/.android/debug.keystore \
  -alias androiddebugkey \
  -storepass android -keypass android | grep SHA
```

On Windows the debug keystore is `%USERPROFILE%\.android\debug.keystore`.
Full guide (including Play App Signing): [`docs/SHA1_FINGERPRINT.md`](SHA1_FINGERPRINT.md).

4. Repeat with the SHA-1 of your **release** keystore (GitHub Actions release
   builds need it too — `keytool -list -v -keystore release.jks -alias <alias>`).

> Google also exposes a SHA-256; register it as an additional fingerprint if
> you use Play App Signing, because Play re-signs the APK with its own keys.

### b) Web client (used for the server client id)

**Create credentials → OAuth client ID → Web application.**

Copy the client ID into:

- `backend/.env` → `GOOGLE_CLIENT_ID`
- `backend/.env` → `GOOGLE_CLIENT_SECRET` (only needed for other flows, but set it)
- GitHub Actions **variable** `GOOGLE_SERVER_CLIENT_ID` (public)
- `flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=...`

### c) (Optional) iOS client — Android-only project does not need it.

## 4. How the flow works

```
Flutter                      Backend                         Google
  |  GoogleSignIn.signIn()      |                                |
  |--------------------------- idToken --------------------------->|
  |  POST /api/auth/google { idToken }                          |
  |----------------------------->|  OAuth2Client.verifyIdToken()  |
  |                              |------------------------------->|
  |                              |  find-or-create user (Mongo)   |
  |<--- accessToken + refreshToken ------------------------------|
  |  secure storage (Android Keystore)                          |
```

Backend verification lives in `backend/src/services/googleAuthService.js` and
uses `google-auth-library` with your `GOOGLE_CLIENT_ID` as the audience. Tokens
signed for any other client are rejected.

## 5. Session lifecycle

- **Access token** — JWT, 15 minutes, sent as `Authorization: Bearer …`.
- **Refresh token** — JWT, 30 days, stored hashed in `refreshtokens`, rotated on
  every use. Replaying an old refresh token revokes the whole token family.
- **Sign out** — revokes the refresh token, clears secure storage, unregisters
  the FCM device token.

## 6. Common errors

| Error | Cause | Fix |
| --- | --- | --- |
| `ApiException(401/INVALID_GOOGLE_TOKEN)` | audience mismatch | `GOOGLE_CLIENT_ID` must be the **Web** client id |
| `ApiException(MISSING_ID_TOKEN)` | no server client id on device | pass `GOOGLE_SERVER_CLIENT_ID` |
| PlatformException `sign_in_failed` code 10 | SHA-1 not registered | add debug **and** release SHA-1 |
| `GOOGLE_AUTH_NOT_CONFIGURED` | backend env missing | set `GOOGLE_CLIENT_ID` |
| Account created but no e-mail | consent screen in testing | add the account as a test user |
