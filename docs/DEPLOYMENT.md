# Deploying the Miyu backend

> **This project is deployed on Pterodactyl** (`play.notmemc.my.id:3186`).
> Step-by-step for that host: [PTERODACTYL.md](PTERODACTYL.md). The options
> below remain valid for any other host.

GitHub Actions builds the backend image but **does not** and cannot deploy it to
a public host without your account. Choose one of the options below, configure
the secrets, then enable `deploy-backend.yml`.

## 1. Container deploy (Render / Railway / Fly.io)

The repo ships `backend/Dockerfile` exposing port 5000 and a healthcheck on
`/api/health`.

### Render

1. **New → Blueprint** (or Web Service) → point at this repo.
2. Root directory: `backend`, Environment: Docker.
3. Health check path: `/api/health`.
4. Add every backend secret as an environment variable (the ones from
   `GITHUB_SECRETS.md`).
5. Deploy, then copy the public URL into `API_BASE_URL` / `SOCKET_URL` variables.

### Railway

```bash
railway init
railway variables --set MONGODB_URI=... --set JWT_ACCESS_SECRET=...
railway up --dockerfile backend/Dockerfile
```

### Fly.io

```bash
cd backend
fly launch --dockerfile Dockerfile --name miyu-api
fly secrets set MONGODB_URI=... JWT_ACCESS_SECRET=... JWT_REFRESH_SECRET=...
fly deploy
```

## 2. VPS with Docker Compose

```yaml
# docker-compose.yml
services:
  api:
    build: ./backend
    restart: always
    env_file: ./backend/.env
    ports:
      - "127.0.0.1:5000:5000"
```

Put nginx/Caddy in front for TLS and WebSocket upgrades:

```nginx
server {
  server_name api.miyu.app;
  location / {
    proxy_pass http://127.0.0.1:5000;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  }
}
```

WebSockets must be proxied for Socket.IO; without the upgrade headers the app
falls back to long-polling and realtime latency suffers.

## 3. Environment checklist before going public

- [ ] `NODE_ENV=production`
- [ ] `CORS_ORIGINS` restricted to your app's origins (not `*`)
- [ ] `MONGODB_URI` points at the production cluster + narrow IP allow-list
- [ ] JWT secrets are 64-byte random hex, different per environment
- [ ] `TURN_*` configured (calls across carriers)
- [ ] Cloudinary credentials set (media uploads)
- [ ] Firebase service account set (push)
- [ ] HTTPS/WSS only
- [ ] Rate limits tuned (`backend/src/middleware/rateLimit.js`)
- [ ] Logs shipped somewhere durable; secrets never logged
- [ ] Atlas backups or `mongodump` cron

## 4. Health & observability

```bash
curl -s https://api.miyu.app/api/health | jq
```

Structured JSON logs via pino include request id, method, path, status and
latency, with `authorization` and token fields redacted.

## 5. Call reliability backlog (honest limitations)

Incoming calls while the app is **terminated** are the hardest part of a
messaging app. Miyu currently:

- sends a high-priority FCM notification with a full-screen-intent capable
  channel when the app is backgrounded,
- recovers call state from the backend when the notification opens the app.

To reach true phone-like ringing you need to add, on Android:

1. A `FirebaseMessagingService` subclass that starts a foreground service on
   `incoming_call` data messages.
2. A `ConnectionService`-based telecom integration (or a full-screen intent from
   the foreground service) that wakes the device and shows the call UI.
3. Keep-alive awareness of Android 14+ foreground service type restrictions.

The Flutter UI already consumes the resulting state, so this is an additive
native task, not a rewrite.

## 6. Scaling notes

- Socket.IO is single-node by default. Behind multiple instances, add the Redis
  adapter (`@socket.io/redis-adapter`) so rooms fan out across nodes.
- MongoDB: pagination is cursor-based (`createdAt + _id`) so deep conversations
  stay fast.
- Media is offloaded to Cloudinary; MongoDB stores URLs only.
