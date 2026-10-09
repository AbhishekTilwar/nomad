# Nomad Mingle API (backend)

Express 5 + Firebase Admin modular monolith. Contract: [`../docs/API.md`](../docs/API.md) and [`../docs/DATA_MODEL.md`](../docs/DATA_MODEL.md). Security: [`../docs/SECURITY.md`](../docs/SECURITY.md). Cost: [`../docs/COST_CONTROL.md`](../docs/COST_CONTROL.md).

```
src/config      env validation (zod)            src/modules/users          profile, blocks, prefs, tokens, deletion
src/middleware  auth, roles, limits, errors     src/modules/activities     CRUD, membership transactions, geo query service
src/lib         geo, logger, text, pagination   src/modules/community      room + chat write path + rate limiter
src/app.js      composition root (DI)           src/modules/safety|admin   reports, moderation, audit trail
src/server.js   process entrypoint              src/modules/notifications  FCM/in-app dispatch, scheduled jobs
```

## Run locally
```bash
cd backend && npm ci
cp .env.example .env            # edit values; never commit .env
# Option A: emulators (no credentials). From /firebase (needs JDK 21+):
#   firebase emulators:start --only auth,firestore,storage --project demo-nomadmingle
export FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099
npm run dev                      # loads env from your shell; use `node --env-file=.env src/server.js` to load .env
```
`node --env-file=.env src/server.js` is the simplest way to use a `.env` file (Node 20+). With a real project use Application Default Credentials (`gcloud auth application-default login`) or `GOOGLE_APPLICATION_CREDENTIALS` pointing outside the repo.

## Tests and lint
```bash
npm test        # node:test, in-memory Firestore fake (see below)
npm run lint
```
**What the tests prove / don't prove.** `test/helpers/fakeFirestore.js` is an in-memory Firestore with optimistic-concurrency transactions (read versions are validated at commit; conflicting transactions are re-run) and simulated read latency so concurrent requests genuinely interleave; the concurrency tests assert exact capacity / rate-limit counts and that conflicts actually occurred. This proves the *application logic* is correct under Firestore's transaction semantics. It does not prove behaviour against the real service (pessimistic locking, retry limits of ~5 attempts under heavy contention, index requirements, latency). Indexes are not validated by the fake or the emulator. Security rules are tested separately against the real emulator in `/firebase/tests`.

## Configuration
All env vars are validated at startup (`src/config/env.js`, `.env.example` lists them with safe placeholders). Community limits are env-driven (`NEW_ACCOUNT_*`, `ESTABLISHED_MSG_LIMIT`, `RATE_WINDOW_MINUTES`, `MESSAGE_MAX_LENGTH`, `DUPLICATE_WINDOW_SECONDS`, `VIOLATION_*`).

## Admin bootstrap
`node scripts/set-admin-claim.js <uid> admin` — see [SECURITY.md](../docs/SECURITY.md#admin-bootstrap-first-admin). Requires `GOOGLE_APPLICATION_CREDENTIALS` (service account stored outside the repo).

## Scheduled jobs
`POST /api/v1/internal/jobs/reminders` and `/complete-ended` with header `x-cron-secret: $CRON_SECRET`. Disabled (404) when `CRON_SECRET` is empty. `render.yaml` defines a cron service calling both every 15 minutes.

## Deploying to Render (manual steps; nothing is deployed by this repo)
1. Push the repo to GitHub/GitLab. In Render: **New → Blueprint**, select the repo and point it at `backend/render.yaml` (or create a Web Service manually: root dir `backend`, build `npm ci --omit=dev`, start `node src/server.js`, health check `/health`).
2. Set env vars in the Render dashboard (never in git): `FIREBASE_PROJECT_ID`, `FIREBASE_SERVICE_ACCOUNT_JSON` (service-account JSON or its base64; use a dedicated service account with only Firestore/Auth/FCM roles), `ALLOWED_ORIGINS`, `CRON_SECRET` (auto-generated; copy to the cron service), `TRUST_PROXY=1` (Render sits behind one proxy, required for correct per-IP rate limiting).
3. Deploy the rules and indexes separately from `/firebase` (`firebase deploy --only firestore:rules,firestore:indexes,storage`) **before** the first release; composite indexes can take minutes to build and queries fail until ready.
4. Verify `GET /health` (liveness) and `GET /ready` (Firestore reachable). Use `/ready` for external uptime checks, `/health` for Render's health check.
5. Free-tier instances sleep when idle; the first request after sleep is slow and in-memory rate-limit counters reset. Use a paid instance for launch.
6. Rotate `CRON_SECRET` / the service-account key by updating the dashboard env vars and redeploying.

## Known gaps
- In-memory IP/user rate limiter is per instance.
- Reminders/completion are polling jobs; `stats.attended` is not incremented on completion yet.
- `q` search is substring-on-page, not full text. Geo pagination re-reads cells each page.
- Account deletion is a sequential best-effort process (not one transaction); re-running `DELETE /users/me` after a partial failure is safe.
- Archival of 30-day-old chats and notification TTL are not implemented.
- App Check verification is documented but not wired.
