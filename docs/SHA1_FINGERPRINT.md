# Package name & SHA-1 fingerprints

You need these two values whenever you register the Android OAuth client in
Google Cloud Console (Google Sign-In), or set up Play App Signing.

## 1. Package name (fixed)

| Where | Value |
| --- | --- |
| `android/app/build.gradle` → `namespace` | `com.miyu.messaging` |
| `android/app/build.gradle` → `applicationId` | `com.miyu.messaging` |
| OAuth client "Package name" field | **`com.miyu.messaging`** |
| `manifestPlaceholders["appAuthRedirectScheme"]` | `com.miyu.messaging` |

The package name is compiled into the APK, so it cannot be "generated" — it
already exists in this repo. If you rename `applicationId`, you must also update
`lib/config/app_config.dart` usage of `GOOGLE_SERVER_CLIENT_ID`, the OAuth
client, and `docs/GOOGLE_AUTH.md`.

## 2. SHA-1 — why it is not in the repo

The SHA-1 is a fingerprint of a signing key. It cannot be committed:

- the **debug** key lives only on the machine running `flutter run`
  (`~/.android/debug.keystore`), and
- the **release** key must never be committed; CI injects it from
  `ANDROID_KEYSTORE_BASE64`.

Publishing a SHA-1 in a repository is harmless on its own (it is public in every
APK), but the project rule is: no key material or its derived values in Git.
So generate it locally.

## 3. Generate it (30 seconds)

A helper script is included:

```bash
cd mobile
bash tool/print_sha1.sh                 # debug + release (from android/key.properties)
bash tool/print_sha1.sh ~/my-release.jks # any specific keystore, prompts for password
```

Equivalent manual commands:

```bash
# Debug (what `flutter run` signs with)
keytool -list -v -keystore ~/.android/debug.keystore \
  -alias androiddebugkey -storepass android -keypass android | grep SHA

# Release (your keystore)
keytool -list -v -keystore ~/miyu-release.jks -alias miyu | grep SHA

# No keytool? Let Gradle print every variant's fingerprints:
cd mobile/android && ./gradlew signingReport
```

Windows: `%USERPROFILE%\.android\debug.keystore`.

A fresh debug keystore produces something like:

```
SHA1:   AB:CD:EF:01:23:45:...:99   (32 hex pairs, yours will differ)
SHA256: 12:34:...:AB               (64 hex pairs)
```

The 32 hex pairs are the SHA-1; 64 hex pairs are the SHA-256.

## 4. Where to paste them

Google Cloud Console → **APIs & Services → Credentials → Create credentials →
OAuth client ID → Android**:

| Field | Value |
| --- | --- |
| Name | `Miyu Android (debug)` / `Miyu Android (release)` — anything |
| Package name | `com.miyu.messaging` |
| SHA-1 certificate fingerprint | paste the SHA-1 above |

Add **one client entry per fingerprint** (debug, release, and Play App Signing),
all with the same package name. Google matches on package **+** fingerprint, so a
missing entry is what causes `ApiException: 10` / `DEVELOPER_ERROR`.

Play App Signing: Play Console → your app → **Setup → App integrity → App signing
key certificate** → copy that SHA-1 as well. Play re-signs your APK, so without
it Google Sign-In fails in the Play-distributed build even though it works from
`flutter run` or the CI artifact.

After adding fingerprints you do **not** need a new OAuth client ID and you do
not need to rebuild for the change to take effect (Google verifies at runtime) —
but do wait a minute or two for propagation.

## 5. Checklist

- [ ] Package name `com.miyu.messaging` (matches `build.gradle`).
- [ ] Debug SHA-1 added → `flutter run` works.
- [ ] Release SHA-1 added → CI APK / sideloaded release build works.
- [ ] Play App Signing SHA-1 added (if distributing via Play).
- [ ] Web client ID copied to `GOOGLE_SERVER_CLIENT_ID` + backend `GOOGLE_CLIENT_ID`.

See `docs/GOOGLE_AUTH.md` for the full three-client setup and the token flow.
