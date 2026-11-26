# Deploy ke Pterodactyl (panel.notmemc.my.id)

Target deploy Miyu: **host `play.notmemc.my.id`, port `3186`**, dikelola dari
panel Pterodactyl `https://panel.notmemc.my.id`.

Pterodactyl adalah pilihan yang benar untuk aplikasi ini — berbeda dengan Vercel
atau layanan serverless lain, container Pterodactyl membuka port sendiri dan
**tidak** memutus WebSocket, sehingga Socket.IO (chat realtime, typing,
presence) dan signaling WebRTC untuk panggilan bisa hidup.

---

## 0. Yang sudah disiapkan di repo

| Berkas | Fungsi |
| --- | --- |
| `backend/index.js` | Titik masuk yang dijalankan panel. Egg Node.js generic memakai `node index.js` dan **tidak** membaca `"main"` di `package.json`; tanpa berkas ini server gagal start dengan `Cannot find module`. |
| `backend/src/config/env.js` | Port dibaca dari `PORT` **atau** `SERVER_PORT`. Pterodactyl menyuntikkan `SERVER_PORT=3186` dan sering tidak menyetel `PORT`; tanpa fallback ini server akan mendengarkan di 5000 dan panel tampak "jalan" padahal semua request timeout. |
| `backend/src/config/db.js` | Server **langsung listen**, koneksi Mongo dicoba ulang tiap 15 detik di latar belakang. Kalau Atlas sedang tidak bisa dihubungi, panel tidak masuk restart-loop dan `/api/health` tetap 200. |
| `backend/tests/runtime.test.js` | 6 tes yang mengunci ketiga perilaku di atas, termasuk handshake WebSocket `101` tanpa reverse proxy. Dijalankan di CI. |

Bukti yang sudah dieksekusi (bukan klaim):

```
PORT / SERVER_PORT resolution ......... 4/4 passed
node index.js entry point ............ passed
/api/health + raw WebSocket 101 ...... passed
```

---

## 1. Buat server di panel

1. **Admin/owner** panel membuat *Node* baru dengan alokasi port **3186**.
2. Buat *Server* baru:
   - **Egg / Nest**: `Node.js` → *Generic* (`NodeJS`, versi 18/20/22).
   - **Docker image**: `ghcr.io/parkervcp/yolks:nodejs_22` (atau `nodejs_20`).
   - **Allocation**: `play.notmemc.my.id:3186` — harus **sama persis** dengan
     port yang Anda berikan (`3186`).
   - **Memory**: minimal **512 MB** (Node + Socket.IO + mongoose ≈ 120–180 MB;
     512 MB memberi ruang untuk reconnect dan upload).
   - **Disk**: 1 GB cukup (tanpa `node_modules` yang di-commit).

## 2. Startup command

Di tab **Startup** server, isi:

```
if [ -f /home/container/package.json ]; then cd /home/container/backend && npm ci --omit=dev --no-audit --no-fund; fi; node /home/container/backend/index.js
```

Atau, kalau Anda meng-upload isi folder `backend/` sebagai root server
(rekomendasi — lebih kecil, tanpa Flutter):

```
if [ ! -d node_modules ]; then npm ci --omit=dev --no-audit --no-fund; fi; node index.js
```

> Egg Node.js generic menambahkan `SERVER_PORT` otomatis. Kode sudah memakainya,
> jadi **jangan** menulis `PORT=5000` di startup command — itu akan menimpa
> alokasi panel dan trafik tidak sampai.

## 3. Upload berkas

**Opsi A — isi folder `backend/` saja (paling ringan)**

```bash
cd backend
zip -r ../miyu-backend.zip . -x "node_modules/*" "tests/*" "coverage/*" ".jest/*" ".env"
```

Lalu unggah `miyu-backend.zip` lewat **File Manager** panel dan ekstrak ke
`/home/container`.

**Opsi B — clone repo penuh**

Di panel **Console**, jalankan:

```bash
git clone https://github.com/HOOOOOOQ/Miyu.git .
```

Lalu pakai startup command versi pertama di atas (`cd backend`).

## 4. Environment variables

Tab **Startup → Variables** (atau berkas `.env` di `/home/container/backend/.env`).
Wajib:

| Variabel | Contoh / catatan |
| --- | --- |
| `NODE_ENV` | `production` |
| `MONGODB_URI` | `mongodb+srv://user:pass@cluster.mongodb.net/miyu?retryWrites=true&w=majority` — lihat [MONGODB_SETUP.md](MONGODB_SETUP.md) |
| `JWT_ACCESS_SECRET` | `openssl rand -hex 64` |
| `JWT_REFRESH_SECRET` | `openssl rand -hex 64` (harus beda dari access) |
| `GOOGLE_CLIENT_ID` | Client ID **Web** dari Google Cloud (bukan Android) |
| `GOOGLE_CLIENT_SECRET` | pasangan Client ID Web |

Opsional tapi dibutuhkan agar fitur terkait hidup:

| Variabel | Mengaktifkan |
| --- | --- |
| `CLOUDINARY_CLOUD_NAME` / `_API_KEY` / `_API_SECRET` | kirim foto, video, voice note |
| `TURN_URL` / `TURN_USERNAME` / `TURN_CREDENTIAL` | panggilan lintas operator (tanpa TURN, panggilan gagal di jaringan seluler) |
| `FIREBASE_PROJECT_ID` / `FIREBASE_SERVICE_ACCOUNT_JSON` | push notification saat app tertutup |
| `CORS_ORIGINS` | biarkan `*` selama uji; isi origin eksplisit sebelum publik |
| `API_BASE_URL` | `http://play.notmemc.my.id:3186` (dipakai untuk URL media absolut) |
| `MAX_FILE_SIZE_MB` | default `25` |

> **Jangan pernah** menaruh `MONGODB_URI` atau secret lain di aplikasi Flutter.
> Semua nilai sensitif hanya hidup di server ini.

## 5. Pasang URL-nya di aplikasi Flutter

`mobile/lib/config/app_config.dart` membaca konfigurasi dari `--dart-define`.
APK yang sekarang ada di artifact CI masih menunjuk ke `https://api.miyu.app`.
Build ulang dengan endpoint Anda:

```bash
cd mobile
flutter build apk --release \
  --dart-define=API_BASE_URL=http://play.notmemc.my.id:3186 \
  --dart-define=SOCKET_URL=http://play.notmemc.my.id:3186 \
  --dart-define=APP_ENV=production
```

Atau, agar CI yang membangunnya, set dua **repository variable** (bukan secret,
nilainya publik):

```bash
gh variable set API_BASE_URL  --body "http://play.notmemc.my.id:3186"
gh variable set SOCKET_URL    --body "http://play.notmemc.my.id:3186"
gh variable set APP_ENV       --body "production"
```

Workflow `android-build.yml` sudah membaca `vars.API_BASE_URL` / `vars.SOCKET_URL`
dan menanamkannya ke APK lewat `--dart-define`.

### HTTP polos vs HTTPS

`http://` + port eksplisit berarti trafik **tidak terenkripsi**. Token JWT dan
isi pesan bisa disadap di jaringan publik. Untuk pemakaian nyata, pasang
Cloudflare (SSL mode **Full**) atau nginx di depan panel, lalu:

- pakai `https://play.notmemc.my.id` (port 443) di `API_BASE_URL`/`SOCKET_URL`,
- pastikan proxy meneruskan `Upgrade` + `Connection: upgrade` (default Cloudflare
  sudah mendukung WebSocket; nginx butuh dua baris `proxy_set_header` di
  [DEPLOYMENT.md](DEPLOYMENT.md)).

Selama masih `http://`, Android mengizinkannya karena
`android:usesCleartextTraffic="true"` sudah aktif di `AndroidManifest.xml`.
Jangan hapus atribut itu sebelum backend punya TLS, atau aplikasi akan gagal
connect tanpa pesan yang jelas.

## 6. Verifikasi setelah server jalan

Dari komputer Anda:

```bash
# 1. Health
curl -s http://play.notmemc.my.id:3186/api/health
# {"success":true,"data":{"status":"ok","service":"miyu-backend","env":"production",...}}

# 2. Socket.IO handshake (harus mengembalikan 0{"sid":...})
curl -s "http://play.notmemc.my.id:3186/socket.io/?EIO=4&transport=polling"
```

Kalau **health 200 tapi handshake socket gagal**, berarti ada proxy di depan
container yang membuang header `Upgrade` — matikan proxy itu atau tambahkan
konfigurasi WebSocket.

Kalau **health timeout**, cek console panel: biasanya server mendengarkan di
port lain (pastikan `SERVER_PORT=3186` ada di environment) atau proses mati
karena `Cannot find module` (startup command salah path).

## 7. Batasan Pterodactyl yang perlu Anda tahu

| Hal | Kenyataan |
| --- | --- |
| **Restart / stop** | Setiap restart memutus semua socket; klien Miyu sudah auto-reconnect (50 percobaan, backoff 1,2–8 detik). |
| **Satu instance** | Socket.IO single-node. Kalau nanti di-scale ke dua server, presence/typing tidak tersambung antar-node — perlu `@socket.io/redis-adapter`. |
| **Backup** | Panel tidak mem-backup MongoDB. Atur Atlas backup atau `mongodump` terjadwal. |
| **Sleep / suspend** | Server yang di-suspend tidak menerima push; FCM juga butuh Firebase dikonfigurasi. |
| **Lisensi egg** | Beberapa egg Node.js mewajibkan `package.json` di root. Kalau startup gagal dengan pesan itu, pakai Opsi A (isi `backend/` sebagai root). |
