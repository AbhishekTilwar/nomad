# Nomad Mingle — Security

## Architecture in one paragraph
Clients (Flutter) authenticate with Firebase Auth and send ID tokens to the Express API. The API verifies every token with the Admin SDK, enforces account status, and performs **all writes** (Admin SDK bypasses rules). Clients read chat/notifications/“my activities” directly from Firestore under restrictive rules. Storage uploads (avatars, covers) are the only direct client writes, limited by Storage rules.

## Checklist (status reflects what is in this repo)
| Area | Control | Where |
|---|---|---|
| AuthN | ID token verified with Admin SDK on every request, `checkRevoked` on by default (`CHECK_REVOKED_TOKENS`) | `backend/src/middleware/auth.js` |
| Account state | suspended/deleted blocked on every route (except `GET/DELETE /users/me`); muted blocked from chat only; status re-read per request so suspension is immediate | `auth.js`, `community/chat.js` |
| Age gate | DOB required at creation, >=18 validated server-side, immutable, never returned or put in the public doc | `users/service.js` |
| AuthZ | host-only checks run inside the transaction against the stored `hostId`; membership checked for chat; staff = Auth claim `role` AND private profile `role` | `activities/service.js`, `middleware/roles.js` |
| Mass assignment | every body is a strict zod schema; server-controlled fields (`role`, `accountStatus`, `hostId`, `participantCount`...) are rejected | `*/schemas.js` |
| Data integrity | join/approve/leave/remove/create run in Firestore transactions; `participantCount` only changes with the member doc | `activities/service.js` |
| Abuse | per-IP and per-user rate limits (in-memory), community limiter in a Firestore transaction (works across instances), link blocking for new accounts, duplicate detection, escalating cooldown, activity host cap | `middleware/common.js`, `community/chat.js` |
| Input | JSON body limit (`BODY_LIMIT`), request timeout, text normalisation (control/zero-width stripped), https-only image URLs | `app.js`, `lib/text.js` |
| Transport/headers | helmet defaults; CORS allow-list from `ALLOWED_ORIGINS` (`*` is rejected at startup); `x-powered-by` off; Render terminates TLS | `app.js`, `config/env.js` |
| Secrets | env validated with zod; no credentials in repo; `.env`, `service-account*.json` git-ignored; error output never echoes values | `config/env.js`, `backend/.gitignore` |
| Logging | pino; `authorization`, cookies, cron secret, `text`, `body` redacted; message text is never logged; request logs carry method, route, status, latency, uid | `lib/logger.js` |
| Audit | every admin action appends to `moderationActions` in the same commit as the state change; reports keep text snapshots as evidence | `admin/service.js` |
| Privacy | account deletion removes profile, private data, blocks, tokens, notifications, rate-limit state; messages are anonymised (kept for abuse evidence); Auth user deleted | `users/service.js` |
| Rules | default deny; no `if true`; all write paths closed for clients; chat reads need approved membership + visible moderation state; no user enumeration | `firebase/firestore.rules` |
| Storage | owner-only paths, <=5 MB, raster images only (no SVG), unguessable object names | `firebase/storage.rules` |
| Cron endpoints | constant-time `x-cron-secret`; disabled unless `CRON_SECRET` is set | `notifications/routes.js` |

## Admin bootstrap (first admin)
There is intentionally no API to create an admin. Roles live in two places that must agree: the Auth custom claim `role` and `users/{uid}/private/profile.role`.

1. The future admin signs up in the app and completes their profile (so the private profile exists).
2. On a trusted machine, create a **service account key outside the repo** (Console → Project settings → Service accounts) or use `gcloud auth application-default login`. Never commit it; `service-account*.json` is git-ignored.
3. Run:
   ```bash
   export GOOGLE_APPLICATION_CREDENTIALS=/abs/path/outside/repo/sa.json
   export FIREBASE_PROJECT_ID=<your-project-id>
   cd backend && node scripts/set-admin-claim.js <uid> admin      # or moderator / user (revoke)
   ```
   Use `--dry-run` first. The script sets the claim, sets the private role, and revokes refresh tokens.
4. The admin signs out/in (or force-refreshes the ID token). Admin routes need **both** factors: a claim without the Firestore role (or vice versa) is rejected, and the effective role is the lower of the two. Revoke by running the script with role `user`.
5. Delete the service-account key when done; prefer short-lived ADC credentials.

## App Check (recommended, not yet enforced)
App Check proves requests come from your genuine app (Play Integrity on Android, App Attest/DeviceCheck on iOS). Suggested rollout:
1. Flutter: add `firebase_app_check`, activate with Play Integrity / App Attest providers (debug provider only for dev builds, token registered in the Console, never committed).
2. Console: enable App Check, run in **monitor mode** for Firestore and Storage and review the unverified-request ratio.
3. Enforce for Firestore + Storage once the ratio is ~0 for current app versions.
4. API: send the App Check token in `X-Firebase-AppCheck` and verify it server-side with `getAppCheck().verifyToken()` as an extra middleware (not implemented yet; add before `authenticate` and gate by an env flag so old app versions can be phased out).
App Check reduces scripted abuse and cost attacks but is not authentication and can be bypassed on rooted/compromised devices.

## Known gaps / deliberate trade-offs
- API rate limits are in-memory per instance. With multiple instances, effective limits multiply; the chat limiter is the exception (Firestore-backed). Use a shared store (Redis) or a gateway if you scale out.
- Blocks are client-filtered in the shared community room (as designed); the activity-messages API filters blocked senders server-side.
- Text search (`q`) is a substring match over scanned pages, not full-text; privacy-wise it only sees public activities.
- Link detection is a heuristic; determined spammers can obfuscate. Reports + moderation are the backstop.
- Firestore rules and backend were tested against an emulator/in-memory fake respectively, not a live project; run a staging pass before launch.
- Content moderation of images (avatars/covers) is not implemented; consider a Cloud Vision / manual review queue.
- Penetration test, dependency scanning (`npm audit` in CI) and a privacy policy / grievance-officer process (India DPDP Act) are launch tasks outside this repo.
