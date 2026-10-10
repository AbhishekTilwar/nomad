# Nomad Mingle — Data Model

Single source of truth shared by the Flutter client, the Node API, Firestore rules and indexes.
All timestamps are Firestore `Timestamp`s set with server time. Clients never write server-controlled fields.

## Write policy (summary)

| Data | Client writes directly | Backend (Admin SDK) writes |
|---|---|---|
| `users/{uid}` public profile | no (via `PATCH /users/me`) | yes |
| `users/{uid}/private/profile` | no | yes |
| `activities/**` | no | yes |
| `activities/{id}/messages` | no | yes (after membership + validation) |
| `communityRooms/global/messages` | no | yes (after rate limit + validation) |
| `reports`, `moderationActions`, `userRateLimits` | no | yes |
| `userBlocks/{uid}/blocked/{target}` | no | yes |
| `deviceTokens`, `notifications` | no (read own notifications) | yes |
| Storage `users/{uid}/avatar/*`, `activities/{uid}/covers/*` | yes, size/type-restricted | - |

Chat reads are direct Firestore listeners (rules-authorized); chat writes always go through the API because rate limits, moderation state and membership checks cannot be expressed safely in rules.

## `users/{uid}` (public profile, readable by any signed-in user)
`displayName`, `photoUrl`, `bio`, `city` (`mumbai|pune|other`), `interests[]`, `ageRange` (e.g. `18-24`), `accountStatus` (`active|muted|suspended|deleted`), `countryCode` (ISO alpha-2 or null), `instagram` (handle or null), `profileCompleted`, `emailVerified`, `stats.hosted`, `stats.attended`, `createdAt`, `updatedAt`.
Travelers (written by `PUT /users/me/location`, never returned by any API view): `discoverable`, `approxLat`/`approxLng` (rounded to 2 decimals, ~1.1 km; removed when not discoverable), `locationUpdatedAt`. Note: rules let any signed-in user `get` this doc, so clients that read it directly can see the approximate coordinates.

## `users/{uid}/private/profile` (owner read, backend write)
`dateOfBirth` (ISO date), `ageVerifiedAt`, `preferredActivityTypes[]`, `notificationPrefs{joinRequests,approvals,activityUpdates,reminders,moderation,friends}`, `role` (`user|moderator|admin`, **never** client-writable; admin also set via Auth custom claims, see SECURITY.md), `mutedUntil`, `violationCount`.

> Role and account status live in backend-only data. `users/{uid}.accountStatus` is a denormalized public mirror written only by the backend.

## `activities/{activityId}`
`title`, `description`, `category`, `hostId`, `hostDisplayName`, `hostPhotoUrl` (snapshot at creation, refreshed on host profile update), `city`, `venueName`, `latitude`, `longitude`, `geohash` (precision 9), `startAt`, `endAt`, `capacity` (2–50), `participantCount` (includes host), `costType` (`free|paid`), `costDescription`, `coverImageUrl`, `approvalRequired`, `visibility` (`public|private`), `safetyNotes`, `cancellationPolicy`, `status` (`scheduled|cancelled|completed`), `createdAt`, `updatedAt`.

`participantCount` is only modified inside Firestore transactions in the API (join / approve / leave / remove) that also write the member doc, so the count and membership cannot drift.

## `activities/{activityId}/members/{uid}`
`userId`, `role` (`host|participant`), `status` (`requested|approved|rejected|left|removed`), `displayName`, `photoUrl` (snapshots), `requestedAt`, `approvedAt`, `joinedAt`, `leftAt`. Doc id = uid → duplicates impossible. A host doc is created with the activity (`approved`).

## `activities/{activityId}/messages/{messageId}`
`senderId`, `senderName`, `senderPhotoUrl` (snapshot at send time; not rewritten when profile changes), `text`, `createdAt`, `moderationStatus` (`visible|hidden|removed`).
Readable only by members with `status == approved` (rules use `exists/get` on the member doc).
Retention: cancelled/completed activities stay readable by former approved members for 30 days (read-only), then archived by a scheduled job. Users who `left`/were `removed` lose read access immediately.

## `communityRooms/global`
`name` ("Mingle Community"), `description`, `isActive`, `createdAt`, `lastMessageAt`.

## `communityRooms/global/messages/{messageId}`
Same fields as activity messages. Readable by any signed-in user with an active account; only `visible` messages are queried by the client. Hidden/removed messages retain `text` for evidence but are excluded from client queries (rules deny reading non-visible docs).

## `userBlocks/{uid}/blocked/{targetUid}`
`blockedAt`, `targetDisplayName`. Owner-readable. Client filters blocked sender ids locally (a shared room cannot be perfectly isolated).

## `reports/{reportId}` (backend only; moderators via API)
`reporterId`, `targetType` (`message|user|activity`), `targetId`, `context{roomType: community|activity, activityId?, messageId?, textSnapshot?}`, `reason` (`spam|harassment|unsafe|inappropriate|other`), `details`, `status` (`open|actioned|dismissed`), `createdAt`, `reviewedBy`, `reviewedAt`.

## `moderationActions/{actionId}` (audit trail, append-only)
`actorId`, `action` (`hide_message|remove_message|mute|suspend|reinstate|cancel_activity|dismiss_report`), `targetType`, `targetId`, `reportId?`, `reason`, `createdAt`.

## `userRateLimits/{uid}`
`windowStart`, `count`, `lastTextHash`, `lastMessageAt`, `cooldownUntil`, `violations`. Updated inside a transaction only when a message is *accepted or rejected as a violation*. Never touched on reads.

## `deviceTokens/{tokenHash}`
`uid`, `token`, `platform`, `updatedAt`. Backend only.

## `friendships/{uidA_uidB}` (backend only; client read/write denied)
Id = the two uids sorted and joined with `_`. `users[a,b]` (sorted), `requesterId`, `status` (`pending|accepted`), `createdAt`, `updatedAt`. Declining, cancelling, unfriending and blocking delete the doc. Max 100 outgoing pending requests per user.

## `notifications/{id}`
`userId`, `type` (incl. `friend_request`, `friend_accepted`), `title`, `body`, `data{}` (carries `actorId`, `actorName`, `actorPhotoUrl` when an actor is known), `read`, `createdAt`. Owner may read; backend writes.

## Geohash strategy
Activities store `geohash` (precision 9). Nearby query: compute the geohash cover (center + 8 neighbours at a precision matching the radius), run one range query per prefix (`geohash >= p` and `< p~`) with `status == scheduled`, `startAt >= now` ordering by geohash, merge, dedupe by id, filter with Haversine, sort. Pagination is cursor-per-prefix; limitation: results are exact-radius but ordering across cells is by merged sort, so deep pages cost reads on each cell. Interface `ActivityQueryService` abstracts this so a dedicated geo service can replace it.

## Composite indexes
Also: `users(discoverable, approxLat)` for travelers (latitude band, scan cap 300 docs, longitude/radius filtered in memory); `friendships(users CONTAINS, status, updatedAt desc)` and `(users CONTAINS, status, createdAt desc)`.

See `firebase/firestore.indexes.json`.

---

## Implementation notes (backend v1 additions)

Backend-only fields added beyond the model above (clients must ignore unknown fields):
- `activities`: `reminderSentAt` (set once by the reminder job; never returned by the API).
- `members`: `displayName` becomes `"Deleted user"` and `photoUrl` null after account deletion.
- `messages` (both rooms): `senderDeleted` (bool, set on account deletion together with `senderName="Deleted user"`, `senderPhotoUrl=null`), `moderatedBy`, `moderatedAt`. Message document id is `{uid}_{clientMessageId}` when the client supplies a `clientMessageId` (idempotent retries), otherwise auto-id.
- `reports`: `targetUserId` (owner of the reported content), `context` has `roomType`, `activityId?`, `messageId?`, `textSnapshot?` (server captured, max 500 chars). Document id is a deterministic hash of reporter+targetType+targetId, which enforces dedupe.
- `userRateLimits/{uid}`: `lastViolationAt` (violations decay after `VIOLATION_DECAY_HOURS`). `users/{uid}/private/profile.violationCount` is incremented on each violation.
- `moderationActions.action` additionally uses `hide_message` / `remove_message` naming as specified, plus `reportId` (nullable). `targetType` may be `report`.
- Public mirror `users/{uid}.accountStatus` is `muted` while a mute is active; the authoritative expiry is `private/profile.mutedUntil` (an expired mute is treated as active by the API).

Rules refinements (see `firebase/firestore.rules`): `users/{uid}` allows `get` but not `list` (no enumeration); activity docs are readable by active users only when `visibility=='public'` or the caller is host/member (client list queries must filter `visibility == 'public'`); `members` has a collection-group read rule for `userId == auth.uid` ("my activities"); activity chat reads additionally require an active account and, for cancelled/completed activities, `updatedAt + 30d`. Storage accepts only `image/(jpeg|png|webp|heic|heif)` (SVG denied) with object names matching `[A-Za-z0-9_-]{20,}.(jpg|jpeg|png|webp|heic)`.
