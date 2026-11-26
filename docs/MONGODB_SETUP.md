# MongoDB Atlas setup

Miyu stores users, conversations, messages, groups, calls, notifications,
devices, blocked users and refresh tokens in MongoDB Atlas. **Only the backend
connects to the database** — the Flutter app never receives a MongoDB URI.

## 1. Create the cluster

1. Sign up at https://www.mongodb.com/cloud/atlas/register.
2. **Build a Database → M0 Free** → choose the region closest to your backend.
3. Provider: AWS / GCP / Azure (all work).

## 2. Database user

**Security → Database Access → Add New Database User**

- Authentication: **Password**
- Username: `miyu-api`
- Password: generate a long random one and store it in your password manager.
- Privileges: **Read and write to any database** (or restrict to `miyu`).

## 3. Network access

**Security → Network Access → Add IP Address**

- Development: **Add Current IP Address**
- Backend hosting (Render/Railway/Fly/VPS): add that provider's egress IPs, or
  `0.0.0.0/0` **only** if your provider uses dynamic IPs. The database user and
  TLS still protect access, but a narrow allow-list is preferable.

## 4. Connection string

**Database → Connect → Drivers** and copy the SRV URI:

```
mongodb+srv://miyu-api:<password>@cluster0.xxxxx.mongodb.net/?retryWrites=true&w=majority
```

Append the database name so Miyu writes to its own namespace:

```
mongodb+srv://miyu-api:<password>@cluster0.xxxxx.mongodb.net/miyu?retryWrites=true&w=majority
```

Put it in `backend/.env` as `MONGODB_URI` — never in the Flutter project.

> Password special characters must be URL-encoded (`@` → `%40`, `#` → `%23`).

## 5. Collections and indexes

Mongoose creates the collections on first write. The models declare these
indexes automatically:

| Collection | Indexes |
| --- | --- |
| `users` | `googleId` unique, `email` unique, `username` unique, text index on name/username |
| `conversations` | `participants + lastActivity`, `conversationType + group` |
| `messages` | `conversationId + createdAt` (pagination), `senderId + clientMessageId` unique (duplicate protection), `conversationId + readBy` |
| `groups` | `members`, text index on name/description |
| `calls` | `callerId + createdAt`, `receiverIds + createdAt`, `status` |
| `notifications` | `user + createdAt`, `read` |
| `devices` | `fcmToken` unique, `user + fcmToken` |
| `blockedusers` | `blocker + blocked` unique |
| `refreshtokens` | `tokenHash` unique, `family`, TTL on `expiresAt` |

TTL indexes garbage-collect expired refresh tokens automatically.

## 6. Verify connectivity

```bash
cd backend
npm run dev
# [db] MongoDB connected
```

Then sign in once from the app and check Atlas → **Browse Collections →
miyu.users** for your document.

## 7. Backups & production notes

- M0 includes on-demand snapshots on paid tiers only; export with
  `mongodump` for free-tier backups.
- Enable **Atlas alerts** for connections, disk and CPU.
- Add a read-only user for analytics tools instead of sharing the API user.
- Rotate the database password if it ever appears in logs or a screenshot.
- The backend redacts `*.token`, `authorization` headers and database URIs from
  its structured logs (`backend/src/config/logger.js`).
