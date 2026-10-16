# Performance, request-cost and app-size audit

Date: 2026-10-16. App version audited: 1.1.0 (version code 4 → 5).

Every number below is tagged **measured** (I ran it), **from code** (counted by reading the source; not observed at runtime) or **not measured** (needs telemetry or a device we did not have). Nothing here is estimated and presented as measured.

## 1. What is already good (left alone)

- Images: all remote images go through `CachedNetworkImage` with `memCacheWidth` sized to the widget (avatars 3x their size, gallery 400, edit tiles 300, profile hero 1000). Uploads are compressed on-device (avatar 512 px / ~60 KB, gallery 1080 px / ~200 KB, cover 1280 px / ~220 KB) and stored under random, never-reused names.
- Chat is realtime by design: one Firestore listener for the open room (`limit(30)`, older pages loaded on scroll, listener cancelled on dispose), one shared listener for the newest community message, one for DMs (`limit(50)`).
- The blocked-users list is cached with a TTL and in-flight de-duplicated (`ChatRepository.blockedIds`).
- Search/viewport requests are debounced (`DiscoverController`, `ExploreController`).
- Listeners and timers inspected (`StreamSubscription`, `Timer`) are cancelled in `dispose`; no leaks found by reading.
- Skeletons already exist for chat history, profile stats, avatars, explore and requests.
- Release builds are minified (R8 mapping present in the bundle).

## 2. Request audit (from code; not measured at runtime)

HTTP = our Cloud Run API. Firestore listener reads are counted separately (initial snapshot = one read per document returned, later updates = one read per changed document).

| Trigger | HTTP requests | Firestore | Notes |
|---|---|---|---|
| App launch with a saved session | `GET /users/me` x1 | none | ID token comes from the local Firebase Auth cache |
| Map / Discover | `GET /activities` per settled viewport | none | debounced; one per pan/zoom stop |
| Chats tab, first visit | `GET /users/me/activities` hosted(50) + joined(50) + hosted(10); `GET /users/me/friend-requests`; `GET /users/me/blocks` (5-minute TTL cache); `GET /activities/:id/members` **once per scheduled hosted plan, up to 10** | DM listener: up to 50 docs initial; community listener: 1 doc | Tab is kept alive (indexed stack), so this is once per session, plus again on each tap of the Requests chip |
| Open a plan chat | `GET /activities/:id`, `GET /activities/:id/members` | room listener: up to 30 docs initial | `POST` per message sent |
| Open Community | `GET /community` | room listener: up to 30 docs initial | |
| Profile tab | `GET /users/me/activities` x3 (hosted, joined, past), `GET /users/me/friends` | none | profile header uses the session profile already in memory |
| Public profile | `GET /users/:uid` | none | refetched on every visit |

Biggest request cost: the Chats tab Requests badge. It is an N+1: one members call per hosted plan to count pending join requests. The backend returns no pending-count field (`/users/me/activities` items carry `lastMessage` only), so fixing it properly needs a backend change (see section 6).

## 3. Changes made

| Change | Latency | Traffic / billing | Freshness |
|---|---|---|---|
| `ApiClient.get` shares one in-flight request between identical concurrent GETs (same path and query) | a second caller no longer waits on its own round trip | fewer duplicate calls when screens mount together | none lost: a request finishing removes the entry, failures are not remembered, writes are never merged |
| `ApiClient.requestCounts`: counts requests actually sent by `METHOD /path` with ids collapsed to `:id` | none | none | holds no tokens, bodies or query values; for tests and local measurement |
| Uploaded photos carry `Cache-Control: public, max-age=31536000, immutable` | fewer conditional re-requests on repeat views | fewer Storage egress requests | safe: names are random and never overwritten. **Applies to new uploads only**; existing objects keep the 1-hour default |
| Create-plan cover preview and add-photo preview use `CachedNetworkImage` with a decode size instead of `Image.network` | no re-download when the screen rebuilds | fewer downloads | none |
| Chats list loading state shows the real filter row and the pinned Community tile, with row skeletons that match a chat row's geometry | static UI is visible immediately; no layout shift | none | none |

Tests added: `test/core/api_dedupe_test.dart` (7 tests) and a Chats loading test in `test/features/route_smoke_test.dart` (fails on the old screen, passes on the new one). The dedupe tests also caught a deadlock in my first version of the change (`whenComplete` returning the map's own future).

### Not changed, on purpose

- Chat remains fully realtime; nothing was cached in a way that could show stale messages.
- No security rules, validation or authorisation moved to the client.
- Profile skeletons: the profile header reads the in-memory session profile (no blank screen), and the stats and avatar already have skeletons. Nothing static was given a skeleton.
- No Cloud Run, Firestore or Storage configuration was changed.

## 4. Measurements

### Server (measured, 2026-10-16, from this machine, unauthenticated endpoints)

- Warm round trip to `https://nomad-266138323486.europe-west1.run.app`: 0.43 to 0.51 s (`/health` and API 401 responses, 3 samples each).
- First request after idle: 4.6 s (one sample). The service is configured with `minScale=0`, `startup-cpu-boost=true`, `containerConcurrency=80`, `maxScale=20`.
- Authenticated response sizes and Firestore reads: **not measured** (needs a signed-in session or production telemetry).

### App size (measured)

| Artifact | Baseline (v4) | After (v5) | Change |
|---|---|---|---|
| Uploaded AAB | 93.7 MiB (98,259,806 B) | 91.6 MiB (96,054,005 B) | -2.2% |
| Base module for an arm64 phone (sum of compressed entries; an estimate of the Play download, not a Play figure) | 20.8 MiB | 20.1 MiB | -3% |
| arm64 release APK (sideload) | 42.0 MiB | 40.7 MiB | -3% |

What contributed: `--split-debug-info` moves Dart debug info out of `libapp.so` (3.5 → 2.96 MB per ABI).

What was tried and rejected:

- Removing the four unused Firebase plugins (`firebase_analytics`, `firebase_crashlytics`, `firebase_messaging`, `firebase_app_check`; none is imported in `lib/`) saved only 0.6 MB of the 44 MB arm64 APK (1.4%). Kept, because App Check and push are planned (`docs/SECURITY.md`) and the saving is small.
- `ndk.debugSymbolLevel = SYMBOL_TABLE` made no difference (symbols stayed 38.1 MiB), so it was not kept.

Why the AAB is larger than a download: 38 MiB of the AAB is native debug symbols that Play never sends to users, and the bundle carries three ABIs where a phone receives one. The build prints "failed to strip debug symbols" because the Android SDK command-line tools are not installed on this machine; installing them (Android Studio, SDK Manager, Command-line Tools) may let Flutter strip the libraries and shrink the AAB further. **Not tested.**

Largest remaining items per ABI (compressed): ML Kit translation library 6.5 MB, Flutter engine 5.1 MB, app code 3.0 MB, dex 2.6 MB, assets 1.7 MB (four Inter weights ~1.6 MB). Reducing these means removing or subsetting features (translation, fonts), which was out of scope.

### Launch and runtime (limited)

- Emulator (arm64, API 36) release build: `am start -W` TotalTime 1.97 to 3.17 s on one install and 0.5 to 3.1 s on another, on identical code. That spread is larger than any change made here, so **no launch-time improvement is claimed**. Real-device numbers are not measured. The splash intentionally holds for at least 1.8 s (`splashMinDuration`).
- My first emulator timings were invalid: the emulator had an older debug-signed build that Android refused to update, so both runs timed the same old app. They were discarded.
- Not measured: login flow, memory, frame jank, offline recovery, expired sessions, reconnecting chat. No test account was available and no physical device was attached.

## 5. Android release version

- Single source of truth: `version: 1.1.0+5` in `app/pubspec.yaml`; `build.gradle.kts` uses `flutter.versionCode` and `flutter.versionName`, so there is no second setting to conflict.
- Verified in the generated AAB manifest: versionCode **5**, versionName **1.1.0**. Signed with the upload key (SHA-1 `62:22:40:3A:D7:F0:4B:7C:CB:21:79:C1:63:E5:16:B3:EE:1D:0E:A7`).
- Note: split-per-abi APKs add an ABI offset (arm64 shows 2005). That does not apply to the AAB.
- Play says version code 4 was used. I have no view into Play Console, so I cannot confirm that 5 is free; if Play rejects it, bump the number after `+`.
- Signing keys, application ID and Firebase configuration were not changed.

Release build command (from `app/`; keep `build/symbols` for each release, it is needed to read Dart stack traces):

```
mkdir -p build/symbols
flutter build appbundle --release --split-debug-info=build/symbols "${D[@]}"
mkdir -p ~/nomadmingle-symbols/<version> && cp build/symbols/* ~/nomadmingle-symbols/<version>/
```

## 6. Remaining bottlenecks, by impact

1. **Chats tab Requests N+1** (up to 10 extra requests per first visit and per Requests-chip tap). Needs a backend field such as a pending-request count on hosted items in `/users/me/activities`, or one endpoint returning all pending join requests. Backend deploy, so needs your approval.
2. **Cloud Run cold start (4.6 s measured once).** Setting min instances to 1 removes it at a monthly cost; infrastructure change, needs your approval. Production latency telemetry should be checked before deciding.
3. **Profile tab makes four requests** (three `/users/me/activities` roles plus friends). A single stats endpoint would replace them; backend change.
4. **Public profile and plan detail are refetched on every visit.** A short TTL cache would help, but needs a decision on how stale a profile or a member list may be.
5. **Telemetry gap.** There is no production request, latency or Firestore-read measurement. Crashlytics and Analytics are installed but not initialised in Dart. Without them, the numbers in section 2 cannot be turned into measured ones.
6. **Debug symbols and ABIs inflate the uploaded AAB.** See section 4; installing the SDK command-line tools is the first thing to try.
7. **Device-only checks still required:** real-device cold start, frame timing on the map and chat list, memory over a long chat session, offline and reconnect behaviour, Google sign-in on a Play-installed build.
