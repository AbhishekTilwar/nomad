# Nomad Mingle REST API (v1)

Base: `/api/v1`. Auth: `Authorization: Bearer <Firebase ID token>` on everything except `/health`, `/ready`.

Response envelope: success `{ "data": ... , "nextCursor"?: string|null }`; error `{ "error": { "code": "string", "message": "string", "details"?: any } }`.
Error codes: `unauthenticated`(401) `forbidden`(403) `not_found`(404) `validation_failed`(400) `conflict`(409) `rate_limited`(429) `account_restricted`(403) `internal`(500).

## Users
- `GET /users/me` → own profile + private fields (no DOB; returns `ageRange`, `role`)
- `PUT /users/me` (create/complete profile on first call) / `PATCH /users/me`: `displayName(2-40) bio(<=300) city interests[] preferredActivityTypes[] dateOfBirth(ISO, required on creation, must be >=18) photoUrl countryCode(ISO alpha-2|null) instagram(handle 1-30 [A-Za-z0-9._], leading @ stripped|null)`
- `DELETE /users/me` → deletes profile data, blocks, tokens; marks messages' sender as deleted user; deletes Auth user
- `GET /users/:uid` → public fields only, plus `friendship: none|friends|request_sent|request_received` relative to the caller
- `PUT /users/me/location {lat, lng, discoverable}` → `{discoverable}`. Stores only a 2-decimal approximate location while discoverable; `discoverable:false` removes it. (20/min/user)
- `GET /users/travelers?lat&lng&radiusKm(50,max 100)&limit(30,max 50)&cursor` → `data: [{uid, displayName, photoUrl, countryCode, city, distanceKm}]`, `meta: nextCursor, total`. Discoverable, active, completed-profile users seen in the last 30 days, excluding the caller and blocks either way; sorted by distance. Scans at most 300 user docs per request (latitude band), so very dense areas may be truncated.
- Friends: `POST /users/:uid/friend-request` → 201 `{friendship:'request_sent'}` (200 `{friendship:'friends'}` if they had already requested you; 400 self, 403 blocked, 404 unknown, 409 already friends/pending, 429 over 100 pending); `POST /users/:uid/friend-request/accept` → `{friendship:'friends'}` (404 no request, 403 own request, 409 already friends); `DELETE /users/:uid/friend` (cancel/decline/unfriend, idempotent) → `{friendship:'none'}`; `GET /users/me/friends?limit(50,max 100)&cursor` → `[{uid, displayName, photoUrl, countryCode}]` + `nextCursor`; `GET /users/me/friend-requests?limit` → incoming `[{uid, displayName, photoUrl, countryCode, requestedAt}]`. Blocking removes any friendship. (30/min/user on request/accept)
- `GET /users/me/activities?role=hosted|joined|past&limit&cursor` → the caller's activities (see Implementation notes)
- `GET /users/me/blocks`, `POST /users/:uid/block`, `DELETE /users/:uid/block`
- `PUT /users/me/notification-prefs`, `POST /users/me/device-tokens {token, platform}`, `DELETE /users/me/device-tokens/:token`

## Activities
- `GET /activities/:id/members` on a private activity returns only the host entry unless the caller is the host or an approved member (`participantCount` stays on the activity).
- `GET /activities?city&category&q&from&to&free&minSpots&sort=date|proximity|relevance&lat&lng&radiusKm&limit&cursor`
- `GET /activities/map?lat&lng&radiusKm&category&limit` (lightweight marker payload)
- `GET /activities/:id` → includes `viewer: {membershipStatus, isHost}`
- `POST /activities`, `PATCH /activities/:id` (host only)
- `POST /activities/:id/join` → `{status: approved|requested}`; `/leave`; `/cancel` (host); `/approve/:uid`, `/reject/:uid` (host); `POST /activities/:id/remove/:uid` (host)
- `GET /activities/:id/members` (host: all incl. requests; others: approved only)
- `GET|POST /activities/:id/messages` (approved members/host only)

## Community
- `GET /community` → room info + viewer restrictions
- `POST /community/messages {text, clientMessageId}`; `POST /community/messages/:id/report`

## Safety / admin
- `POST /reports {targetType, targetId, reason, details?, context?}`
- Admin (role moderator|admin, verified server-side from Auth custom claim + private profile): `GET /admin/reports?status`, `POST /admin/reports/:id/dismiss`, `POST /admin/messages/:room/:id/hide|remove`, `POST /admin/users/:uid/suspend|mute|reinstate`, `POST /admin/activities/:id/cancel`, `GET /admin/metrics`

## Ops
`GET /health` (liveness), `GET /ready` (Firestore reachable).

## Community limits (env-configurable)
`NEW_ACCOUNT_AGE_HOURS=72`, `NEW_ACCOUNT_MSG_LIMIT=5`, `ESTABLISHED_MSG_LIMIT=20`, `RATE_WINDOW_MINUTES=10`, `MESSAGE_MAX_LENGTH=500`, `DUPLICATE_WINDOW_SECONDS=30`, `VIOLATION_COOLDOWN_MINUTES=10`, `NEW_ACCOUNT_BLOCK_LINKS=true`.

---

## Implementation notes (backend v1 — authoritative where they refine the above)

**Status codes**: `201` on creates (`PUT /users/me` first call, `POST /activities`, `POST /community/messages`, `POST /reports`, block, device-token); `200` otherwise. Idempotent replay of a message with the same `clientMessageId` returns `200` with the original message and consumes no quota. `413` (`validation_failed`) for bodies over `BODY_LIMIT`; `503` (`internal`) when a request times out or Firestore contention is exhausted (retry).

**Users**: `GET /users/me` returns `404 not_found` until the profile is created with `PUT /users/me`. `PUT` requires `displayName`, `city`, and (on creation) `dateOfBirth`; unknown fields (e.g. `role`, `accountStatus`) are rejected with `400`. `dateOfBirth` is immutable once set (`409`). `GET /users/:uid` hides suspended/deleted users (`404`). Suspended/deleted accounts get `403 account_restricted` everywhere except `GET|DELETE /users/me`. Muted users are restricted only from posting messages.

**Activities**
- `startAt` must be in the future (and within 1 year), `endAt` after `startAt` (max 24 h). Enforced on create and on PATCH of times.
- `category` is a lowercase slug (`^[a-z0-9_-]{2,30}$`), not a fixed enum.
- A host may have at most `MAX_ACTIVE_HOSTED_ACTIVITIES` (default 10) scheduled activities (`409`).
- `visibility=private` activities are not listed, are `404` for non-members, and every join is a `requested` (approval) join. Join by id is still possible (ids are unguessable).
- Join conflicts (`409`, `details.reason`): `already_joined`, `full`, `rejected`, `is_host`, `not_scheduled`, `ended`. A user `removed` by the host gets `403 forbidden` on rejoin; `left` users may rejoin.
- Listing: `GET /activities` returns items in `data` + `nextCursor` (opaque). Date sort is index-backed (`status[+city][+category]+startAt`); `q`, `free`, `minSpots` and `visibility` are applied in memory over scanned pages (up to 5 batches), so a page can be shorter than `limit` only at the end. With `lat`+`lng` (`radiusKm` default 10, max 100) the geohash path is used: items carry `distanceKm`; `sort` defaults to `proximity`; each page re-reads the covering cells (max 150 docs per cell). `sort=relevance` reorders within the fetched page only.
- `GET /activities/map` marker: `{id,title,category,latitude,longitude,startAt,city,spotsLeft,costType,distanceKm}`; `lat`,`lng` required, `radiusKm` default 10.
- `GET /activities/:id/messages?limit&cursor` returns newest first (`createdAt desc`), visible messages only, excluding senders the caller blocked.
- Messages in a cancelled/completed activity are read-only (`POST` → `409`, `details.reason=read_only`) and readable by approved members for 30 days after `updatedAt`.

**Community / chat**: `text` is NFKC-normalised, control/zero-width characters stripped, trimmed; empty → `400`; > `MESSAGE_MAX_LENGTH` → `400` (not counted as a violation). Rejections counted as *violations* (escalate cooldown): duplicate text inside `DUPLICATE_WINDOW_SECONDS` (`429`, `details.reason=duplicate_message`), links from a new account (`400`), over-limit (`429`, `details.reason=rate_limit`). Every `429` carries `details.retryAfterSeconds` and a `Retry-After` header. Every `VIOLATION_THRESHOLD` (default 3) violations start a cooldown of `VIOLATION_COOLDOWN_MINUTES × 2^(level-1)` capped at `VIOLATION_MAX_COOLDOWN_MINUTES`; rejections during cooldown (`details.reason=cooldown`) do not escalate further; violations decay after `VIOLATION_DECAY_HOURS`. Activity chat shares the same limiter and `userRateLimits/{uid}` document. Additional env: `VIOLATION_THRESHOLD=3`, `VIOLATION_MAX_COOLDOWN_MINUTES=1440`, `VIOLATION_DECAY_HOURS=24`, `MAX_ACTIVE_HOSTED_ACTIVITIES=10`.
`POST /community/messages` returns `409 conflict` (`details.reason=room_closed`) when `communityRooms/global.isActive=false` (checked with a 30 s per-instance cache).
`GET /community` → `{room, viewer:{accountStatus, canPost, muted, mutedUntil, cooldownUntil, isNewAccount, limits:{messagesPerWindow, windowMinutes, maxLength, linksAllowed}}}`.
`POST /community/messages/:id/report {reason, details?}` is sugar for `POST /reports` with `targetType=message, context.roomType=community`.

**Reports**: `context.roomType` (`community|activity`) is required for `targetType=message`; `activity` also needs `context.activityId` and the reporter must be an approved participant. The server captures `textSnapshot` (client-supplied snapshots are ignored). One report per reporter+target: second attempt → `409` (`details.reason=already_reported`). Cannot report yourself / your own message / your own activity (`400`); missing target → `404`.

**Admin**: `:room` in `/admin/messages/:room/:id/(hide|remove)` is the literal `community` or an activity id. Bodies: hide/remove/dismiss/suspend/reinstate/cancel require `{reason (3-300 chars)}`; `mute` also takes `durationHours` (1-720, default 24); hide/remove/suspend/mute accept `reportId` (closes the report as `actioned`). `GET /admin/reports?status=open|actioned|dismissed&limit&cursor`. Moderators cannot act on staff accounts; nobody can act on themselves. `GET /admin/metrics` → `{users, scheduledActivities, openReports, suspendedUsers, generatedAt}`.

**Ops / jobs**: `POST /api/v1/internal/jobs/reminders` and `POST /api/v1/internal/jobs/complete-ended` are NOT Firebase-authenticated; they require header `x-cron-secret: $CRON_SECRET` (constant-time compare) and return `404` when `CRON_SECRET` is unset. Call them every ~15 minutes from a scheduler (Render Cron Job / Cloud Scheduler). Reminders go to approved members of activities starting within `REMINDER_LEAD_MINUTES` (default 60), once per activity (`reminderSentAt`).

**Notifications** (in-app doc + FCM, best-effort, honouring `notificationPrefs`): `join_request` (host), `join_approved`/`join_rejected`/`removed` (user), `participant_joined`/`participant_left`/`activity_updated`/`activity_cancelled`/`reminder`, `moderation`, `friend_request`/`friend_accepted` (pref `friends`). Every notification `data` carries `actorId`, `actorName`, `actorPhotoUrl` when an actor is known (not for reminders/moderation/system or staff cancellations). FCM `data` always includes `type` and `activityId` where relevant; chat text is never placed in notifications.

**My activities** (`GET /users/me/activities?role=hosted|joined|past&limit(1-50, default 20)&cursor`; default `role=joined`): items have the same shape as `GET /activities` items plus `viewer: {membershipStatus:'approved', isHost, role:'host'|'participant'}` and, when the activity has a visible message, `lastMessage: {text, createdAt, senderName, senderId}` (omitted otherwise; not filtered for blocked senders, so clients should hide the preview when `senderId` is blocked). Only `approved` memberships count (requests/left/removed excluded). `hosted` = I am host, `scheduled` and not ended, ordered by `startAt` asc; `joined` = same but as participant; `past` = cancelled/completed or ended, any role, `startAt` desc. Implementation: `collectionGroup('members')` where `userId==uid && status=='approved'` (existing index), scanning at most 200 memberships, activities loaded by id, filtered/sorted in memory; `cursor` is an opaque offset; `participants: [{uid, displayName, photoUrl}]` is a preview of up to 3 approved members (not the full roster; use `GET /activities/:id/members` for that); `lastMessage` costs one indexed read per returned item, `participants` up to 3. `clientMessageId` for message POSTs must match `[A-Za-z0-9_-]{8,64}`; the stored message id is `{uid}_{clientMessageId}`.
