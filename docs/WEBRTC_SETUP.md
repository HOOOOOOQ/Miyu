# Voice & video calls (WebRTC) setup

Miyu calls are peer-to-peer WebRTC media with Socket.IO signalling. The backend
issues ICE configuration (STUN + TURN credentials) so no relay secret is
compiled into the APK.

## 1. How the pieces fit

```
Caller                          Miyu backend                       Callee
  |  POST /api/calls ---------------->|                                |
  |<------------ call (ringing) ------|  call:incoming (socket+FCM) --> |
  |                                    |<---------- POST /calls/:id/accept
  |<----------- call:accept -----------|  call:accept ----------------->|
  |  call:offer (SDP) ---------------->|-----------------------------> |
  |<------------------------------ call:answer (SDP) ---------------  |
  |  call:ice-candidate <------------->|<------------- ICE candidates    |
  |============== encrypted DTLS-SRTP media ==========================|
```

Signalling events: `call:incoming`, `call:ringing`, `call:accept`,
`call:reject`, `call:offer`, `call:answer`, `call:ice-candidate`, `call:end`,
`call:busy`.

## 2. STUN (works out of the box)

`GET /api/calls/ice-servers` always returns free Google STUN servers. STUN is
enough when both peers can reach each other directly (same Wi-Fi, most home
networks).

## 3. TURN (required for real-world reliability)

Mobile carriers and corporate networks frequently block direct UDP. A TURN
relay is mandatory for production-grade call success rates.

### Option A — Metered TURN (fastest)

1. Create an account at https://www.metered.ca/stun-turn (free tier available).
2. Copy the TURN hostname, username and credential.
3. Configure the backend:

```dotenv
TURN_URL=turn:global.relay.metered.ca:80,turns:global.relay.metered.ca:443
TURN_USERNAME=your-username
TURN_CREDENTIAL=your-credential
```

### Option B — Self-hosted coturn (full control)

```bash
# Ubuntu 22.04 VPS with a public IP
sudo apt install coturn
sudo sed -i 's/#TURNSERVER_ENABLED=1/TURNSERVER_ENABLED=1/' /etc/default/coturn

# /etc/turnserver.conf
listening-port=3478
tls-listening-port=5349
fingerprint
lt-cred-mech
realm=miyu.example.com
user=miyu:CHANGE_ME_STRONG_SECRET
external-ip=YOUR_PUBLIC_IP
min-port=49160
max-port=49200
no-multicast-peers
```

```dotenv
TURN_URL=turn:turn.miyu.example.com:3478,turns:turn.miyu.example.com:5349
TURN_USERNAME=miyu
TURN_CREDENTIAL=CHANGE_ME_STRONG_SECRET
```

Open the UDP port range and 3478/5349 in the firewall. Put TLS in front of 5349
with a real certificate (Let's Encrypt) so `turns:` works on restrictive
networks.

### Rotating credentials (recommended for production)

Static TURN passwords leak over time. The backend already centralises ICE
issuance in `backend/src/services/mediaService.js#getIceServers`. To rotate,
replace the static env values with time-limited HMAC credentials:

```js
// RFC 5766 long-term credential mechanism with coturn's `use-auth-secret`
const ttl = 3600;
const username = `${Math.floor(Date.now() / 1000) + ttl}:miyu`;
const credential = crypto.createHmac('sha1', TURN_STATIC_SECRET).update(username).digest('base64');
```

Then set `use-auth-secret` + `static-auth-secret=…` in `turnserver.conf` and only
`TURN_STATIC_SECRET` in the backend environment.

## 4. Android permissions

Already declared in `android/app/src/main/AndroidManifest.xml`:

- `CAMERA`, `RECORD_AUDIO`, `MODIFY_AUDIO_SETTINGS`
- `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_CAMERA`,
  `FOREGROUND_SERVICE_MICROPHONE`, `FOREGROUND_SERVICE_PHONE_CALL`
- `POST_NOTIFICATIONS`, `USE_FULL_SCREEN_INTENT`, `WAKE_LOCK`

Runtime prompts are triggered by `flutter_webrtc` on first call. If you deny
them, the call screen shows a permission error instead of failing silently.

## 5. Testing two devices

1. Install the same APK on two Android devices/emulators.
2. Sign in with different Google accounts.
3. Start a chat, tap the phone or video icon.
4. Accept on the other device within 45 seconds.
5. Verify: two-way audio, remote video, mute, camera flip, duration counter,
   and that ending on one side ends the other.
6. Repeat with one device on **mobile data** and the other on Wi-Fi. Without
   TURN this often fails — that is the test that tells you whether TURN is
   configured correctly.

Emulator-to-emulator calls work on the same host but do not exercise TURN.

## 6. Known limits

- **Terminated app**: an ordinary FCM notification cannot guarantee ringing.
  Miyu delivers a high-importance incoming-call notification and recovers the
  call state via `GET /api/calls/:id` when opened, but a true "ring like a
  phone" experience needs a foreground service plus
  `ConnectionService`/full-screen intent handling. See `DEPLOYMENT.md → Call
  reliability backlog`.
- **Group calls** are rejected by the API (`GROUP_CALL_UNSUPPORTED`); one-to-one
  calls are fully implemented.
- **Camera/mic in background**: Android 14+ requires the foreground service
  types declared above; keep the call screen in the foreground while calling.
