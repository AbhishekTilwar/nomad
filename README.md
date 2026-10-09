# Nomad Mingle

*Find your people. Make a plan. Go together.* — a social meetup app (Mumbai & Pune first). Not a dating app.

| Part | Path | Tech |
|---|---|---|
| Mobile/web app | [`app/`](app) | Flutter 3.41, Provider, go_router, Firebase |
| API | [`backend/`](backend) | Node 20+, Express, firebase-admin, zod |
| Firebase config | [`firebase/`](firebase) | Firestore/Storage rules, indexes, emulator tests |
| Docs | [`docs/`](docs) | architecture, data model, API, security, cost |

Status and open work: see **[TASKS.md](TASKS.md)**. Nothing here is production-ready until the launch checklist is complete.

## Prerequisites
Flutter ≥ 3.41 (Dart 3.11), Node ≥ 20, Firebase CLI. For the Firestore emulator a recent JDK is required (see `firebase/` notes). iOS builds need full Xcode + CocoaPods; Android builds need the Android SDK (`flutter doctor`).

## Run locally (no Firebase project needed)
```bash
# 1. emulators + API
cd firebase && firebase emulators:start --project demo-nomadmingle
cd backend && cp .env.example .env && npm install && npm run dev

# 2. app (Chrome, emulator mode)
cd app && flutter pub get
flutter run -d chrome --dart-define=USE_EMULATOR=true --dart-define=API_BASE_URL=http://localhost:8080/api/v1
```
Android emulator: use `EMULATOR_HOST=10.0.2.2` and `API_BASE_URL=http://10.0.2.2:8080/api/v1`.

## Run against a real Firebase project
1. Create a project in the Firebase Console (you do this; no project IDs are committed). Enable Authentication → Google + Email/Password, Firestore, Storage, Cloud Messaging.
2. Register apps and either run `flutterfire configure` (generates `firebase_options.dart`, git-ignored) **or** pass the values:
   ```bash
   flutter run --dart-define=FIREBASE_API_KEY=... --dart-define=FIREBASE_APP_ID=... \
     --dart-define=FIREBASE_MESSAGING_SENDER_ID=... --dart-define=FIREBASE_PROJECT_ID=... \
     --dart-define=FIREBASE_STORAGE_BUCKET=... --dart-define=API_BASE_URL=https://<your-api>/api/v1
   ```
   (Client Firebase config is an identifier, not a secret.) Android/iOS also need `google-services.json` / `GoogleService-Info.plist` (git-ignored).
3. Backend: set `FIREBASE_PROJECT_ID` and credentials per `backend/.env.example` (service-account via `GOOGLE_APPLICATION_CREDENTIALS`, never committed).
4. Deploy rules/indexes yourself: `firebase deploy --only firestore:rules,firestore:indexes,storage` (not automated here).

## Map tiles
`MAP_TILE_URL` (default: public OSM tile server — **development only**, see OSM tile policy), `MAP_ATTRIBUTION`. Choose a commercial provider and check pricing/terms before launch; see `docs/COST_CONTROL.md`.

## Tests
```bash
cd app && flutter analyze && flutter test
cd backend && npm test
cd firebase && npm test        # needs the Firestore/Storage emulators
```

## Build
- Web: `flutter build web --dart-define=...`
- Android debug: `flutter build apk --debug` (verified here). Release signing: create a keystore and `android/key.properties` (git-ignored) — see `docs/LAUNCH_CHECKLIST.md`.
- iOS: requires macOS with Xcode; see `docs/LAUNCH_CHECKLIST.md`.

## Docs
[ARCHITECTURE](docs/ARCHITECTURE.md) · [DATA_MODEL](docs/DATA_MODEL.md) · [API](docs/API.md) · [SECURITY](docs/SECURITY.md) · [COST_CONTROL](docs/COST_CONTROL.md)
