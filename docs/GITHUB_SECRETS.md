# GitHub Actions secrets & variables

Open **Repository → Settings → Secrets and variables → Actions**. Secrets are
masked in logs; variables are plain configuration.

## Secrets (encrypted)

| Name | Used by | Where to get it |
| --- | --- | --- |
| `MONGODB_URI` | backend deploy | Atlas connection string (`MONGODB_SETUP.md`) |
| `JWT_ACCESS_SECRET` | backend deploy | `openssl rand -hex 64` |
| `JWT_REFRESH_SECRET` | backend deploy | `openssl rand -hex 64` (must differ) |
| `GOOGLE_CLIENT_ID` | backend | Google Cloud → Web OAuth client |
| `GOOGLE_CLIENT_SECRET` | backend | same OAuth client |
| `TURN_URL` | backend | Metered / coturn (`WEBRTC_SETUP.md`) |
| `TURN_USERNAME` | backend | TURN provider |
| `TURN_CREDENTIAL` | backend | TURN provider |
| `CLOUDINARY_CLOUD_NAME` | backend | Cloudinary dashboard |
| `CLOUDINARY_API_KEY` | backend | Cloudinary dashboard |
| `CLOUDINARY_API_SECRET` | backend | Cloudinary dashboard |
| `FIREBASE_PROJECT_ID` | backend | Firebase console |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | backend | Firebase → Project settings → Service accounts → Generate key (paste the whole JSON, or base64 of it) |
| `GOOGLE_SERVICES_JSON` | Android build | `android/app/google-services.json` content (enables FCM in the APK) |
| `ANDROID_KEYSTORE_BASE64` | release | `base64 -w0 release.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | release | keystore password |
| `ANDROID_KEY_ALIAS` | release | key alias |
| `ANDROID_KEY_PASSWORD` | release | key password |
| `REGISTRY_HOST` / `REGISTRY_USER` / `REGISTRY_PASSWORD` | optional deploy | your container registry |

## Variables (public)

| Name | Example | Effect |
| --- | --- | --- |
| `API_BASE_URL` | `https://api.miyu.app` | compiled into the APK via `--dart-define` |
| `SOCKET_URL` | `https://api.miyu.app` | Socket.IO origin |
| `APP_ENV` | `production` | shown in About, toggles dev labels |
| `APP_VERSION` | `1.0.0` | version name for CI builds |
| `GOOGLE_SERVER_CLIENT_ID` | `1234-abc.apps.googleusercontent.com` | Google Sign-In server client |
| `BACKEND_DEPLOY_ENABLED` | `false` | gate for the deploy workflow |

## Why the split

- The APK must be reproducible from variables alone; it never needs a secret.
- Backend secrets are consumed only by the deploy/host environment, never by
  `android-build.yml`.
- `GOOGLE_SERVICES_JSON` and `GOOGLE_SERVER_CLIENT_ID` are *not* secrets in the
  cryptographic sense, but keeping the services file out of the repo prevents
  accidental project-ID commits and keeps forks clean.

## Setting them from the CLI

```bash
# Secrets
gh secret set MONGODB_URI --body "mongodb+srv://..."
gh secret set JWT_ACCESS_SECRET --body "$(openssl rand -hex 64)"
gh secret set ANDROID_KEYSTORE_BASE64 < <(base64 -w0 release.jks)

# Variables
gh variable set API_BASE_URL --body "https://api.miyu.app"
gh variable set APP_ENV --body "production"
```

## Rules

1. Never commit `.env`, `google-services.json`, `key.properties`, `*.jks` — all
   are covered by `.gitignore`.
2. Never echo a secret in a workflow step. The provided workflows read secrets
   through `env:` and only print presence notices ("configured"/"not set").
3. Rotate `JWT_ACCESS_SECRET` / `JWT_REFRESH_SECRET` if a build log ever leaks
   them; all users will be signed out, which is the safe outcome.
4. Production and development should use different MongoDB clusters and
   different OAuth clients. GitHub **Environments** (`production`) can hold the
   production-only secrets — `deploy-backend.yml` already targets that
   environment.

## What CI does *not* prove

A green `android-build` run proves the app compiles and its tests pass. It does
not prove Google login or calls work — those require real credentials and two
devices. See the acceptance checklist in the README.
