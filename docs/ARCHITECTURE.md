# Architecture

```
Flutter app (app/)  ──ID token──▶  Node/Express API (backend/)  ──Admin SDK──▶  Firestore / Auth / FCM
      │  direct reads (rules-authorized listeners: chat messages)                    ▲
      └──────────────────────────────────────────────────────────────────────────────┘
```

**Principle:** the client reads chat via Firestore listeners; every *write* with business meaning (profile, activity, join, message, report, block) goes through the API, which verifies the Firebase ID token and enforces authorization, validation, capacity and rate limits. Firestore rules deny those writes from clients (defense in depth; Admin SDK bypasses rules, so the API enforces its own checks).

## Flutter (feature-oriented)
```
lib/
  app/        wiring: MaterialApp.router, go_router (router.dart), Provider setup
  core/       config (AppConfig, MapConfig), theme tokens, api client, validators, shared widgets
  features/
    auth/         data (AuthRepository + Firebase impl) · application (SessionController) · presentation
    onboarding/   3-step profile setup
    profile/      repository, model, profile + edit screens
    activities/   models, ActivityRepository (API)
    explore/      ExploreController + map/list screen
    chat/         shared message model (global + activity chats)
    shell/        bottom navigation (5 tabs), status screens
```
- **State:** `Provider` + `ChangeNotifier`. `SessionController` is the single source of truth (auth + profile → `SessionStatus`); `go_router` redirects purely from it (`redirectFor`, unit-tested).
- **Testability:** repositories are interfaces; tests inject fakes (`test/support/fakes.dart`).
- **Config:** `--dart-define` only; nothing secret. `USE_EMULATOR=true` uses a dummy `demo-nomadmingle` project.
- **Navigation:** 5 tabs (Explore, Discover, Create, Chats, Profile). The global "Mingle Community" chat is a full-screen route opened from an Explore app-bar icon — *not* a tab.
- **Map:** `flutter_map` + `MapConfig` (tile URL/attribution from dart-defines). The map widget only talks to `ActivityRepository`, so the geohash backend can be swapped for a geo service.

## Backend
Modular monolith (Express, ES modules) with modules per domain; see `backend/README.md` and `docs/API.md`.

## Decisions
| Decision | Reason |
|---|---|
| Direct Firestore reads only for chat | cheap real-time, rules-protected; all else via API |
| Dummy `demo-` project for emulators | works with zero credentials; never invent real IDs |
| Email verification required for password accounts | spam/abuse reduction without SMS cost |
| DOB stored in private subdocument, ≥18 validated server-side | privacy + eligibility |
| Roles via Auth custom claims + private profile, never client-writable | admin safety |
