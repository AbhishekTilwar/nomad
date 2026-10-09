# Nomad Mingle — Cost control

No pricing or free-tier promises are made here: Firebase/Google Cloud and Render pricing and quotas change. Check the current pricing pages and set **budget alerts before launch**. Everything below is about *what drives usage* and how to keep it bounded.

## Cost drivers
| Driver | Why it grows | Mitigation in this repo |
|---|---|---|
| Firestore document reads | Chat listeners (every new message is a read per listening client), activity lists, rules `get()`/`exists()` lookups | Chat listeners should be limited (`limitToLast(50)`) and `visible`-only; API list pages capped at 50; geohash cover reads up to 9 cells × 150 docs per page (use small radii; cache on the client); rule evaluations for chat do ~3 extra document lookups per request (billed as reads) |
| Firestore writes | Each chat message = 1 message write + 1 rate-limit write; join/leave = 2 writes; notifications = 1 write per recipient | Rate limits cap messages per user (5/20 per 10 min); `lastMessageAt` on the room is throttled (≤1 write/30 s/instance) to avoid a hot document |
| Aggregation queries | `GET /admin/metrics` runs 4 `count()` queries | Admin-only; billed per index entries scanned; do not poll |
| FCM | Free to send, but each notification also writes a doc | Honour `notificationPrefs`; reminders sent once per activity |
| Cloud Storage | Image uploads + egress | 5 MB cap per file, raster types only; compress client-side (aim for <500 KB); serve resized images |
| Cloud Functions / Run | None used; the API is a single Render service | Cron endpoints are plain HTTP |
| Render | Always-on instance hours; free instances sleep (cold starts) | Choose plan via `render.yaml` `plan`; one small instance is enough initially |
| Auth | Phone/SMS verification is the expensive provider; email/Google are cheap | Prefer email/Google; if SMS is used, enable App Check + regional allow-lists to prevent SMS toll fraud |
| Indexes | Each composite index multiplies write cost and storage | Only the indexes in `firebase/firestore.indexes.json`; do not add speculative ones |

## Built-in guards
- Chat: per-user transaction limiter, 500-char cap, duplicate detection, cooldown escalation.
- API: per-IP (300/min) and per-user (120/min) limits, 32 KB body limit, 15 s request timeout (all env-tunable).
- Hosting: max 10 upcoming activities per host; list `limit` ≤ 50, map ≤ 200.
- Retention: cancelled/completed chats are read-only after 30 days; a scheduled archive/cleanup job is **not implemented yet** — add a TTL policy on `notifications` (`createdAt`-based) and an archival job for old messages.

## How to monitor
1. Google Cloud Console → Billing → **Budgets & alerts**: create a budget with alerts at e.g. 50/90/100 % and a Pub/Sub or email notification. Alerts do not stop spend by themselves.
2. Firebase Console → Usage and billing; Firestore → **Usage** tab (reads/writes/deletes per day). Cloud Monitoring metrics: `firestore.googleapis.com/document/read_count`, `.../write_count`.
3. Render dashboard → service metrics (CPU/memory/bandwidth) and instance hours.
4. Review the API logs (pino JSON) for `status=429` spikes (abuse) and `ms` outliers (expensive queries).
5. After each release, compare reads/user/day against the previous week.

## Practical practices
- Use the Firestore emulator for development; never point load tests at production.
- Keep chat listeners scoped to the visible room and detach on screen exit.
- Prefer API pagination over loading entire collections; avoid client-side polling.
- Revisit radius defaults and cell caps in `activities/queryService.js` if nearby queries dominate reads.
- If costs spike: lower `*_RATE_LIMIT_PER_MIN` / `ESTABLISHED_MSG_LIMIT`, or close the community room by setting `communityRooms/global.isActive=false` (the API then rejects community posts with `409 room_closed` within ~30 s; activity chats are unaffected).
