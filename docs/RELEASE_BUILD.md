# Android release build

Built 2026-10-11 from the working tree (version 1.1.0+2). Artifacts are in `app/build/` (git-ignored):

| File | Size | Use |
|---|---|---|
| `flutter-apk/app-arm64-v8a-release.apk` | 41 MB | Most phones; side-loading and testing |
| `flutter-apk/app-armeabi-v7a-release.apk` | 34 MB | Older 32-bit phones |
| `flutter-apk/app-x86_64-release.apk` | 44 MB | x86 emulators |
| `flutter-apk/app-release.apk` | 109 MB | One universal APK (all CPUs) |
| `bundle/release/app-release.aab` | 93 MB | Play Store upload |

## Command
Firebase identifiers come from `android/app/google-services.json` (not secrets). In zsh, pass the defines as an array, not one unquoted string (zsh does not split it, and the app then shows "Firebase isn't configured"):

```zsh
cd app
eval $(python3 - <<'PY'
import json
d=json.load(open('android/app/google-services.json')); c=d['client'][0]
print("FB_KEY=%s FB_APP=%s FB_SENDER=%s FB_PROJECT=%s FB_BUCKET=%s" % (c['api_key'][0]['current_key'], c['client_info']['mobilesdk_app_id'], d['project_info']['project_number'], d['project_info']['project_id'], d['project_info'].get('storage_bucket','')))
PY
)
D=(--dart-define=FIREBASE_API_KEY=$FB_KEY --dart-define=FIREBASE_APP_ID=$FB_APP \
   --dart-define=FIREBASE_MESSAGING_SENDER_ID=$FB_SENDER --dart-define=FIREBASE_PROJECT_ID=$FB_PROJECT \
   --dart-define=FIREBASE_STORAGE_BUCKET=$FB_BUCKET --dart-define=API_BASE_URL=https://<your-api>/api/v1)
flutter build apk --release --split-per-abi "${D[@]}"
flutter build appbundle --release "${D[@]}"
```

## Symptom: "Couldn't load your account" on a release build
That is the missing server address (item 1 below), not a connectivity problem. The release app signs in through Firebase directly, then asks *our* backend for the profile; with no `API_BASE_URL` it asks `localhost` on the phone and fails. From now on a release built without a real address shows "Server address isn't set" at launch instead, and a refused connection reads "Couldn't reach Nomad Mingle" (it used to say "No internet connection"). The address must be **https**: release builds block plain `http://` (only debug builds allow it).

## Before this can ship (not done, needs the owner)
1. **API address.** The repo has no production API URL, so these builds were made *without* `API_BASE_URL`, which defaults to `http://localhost:8080/api/v1`. The app starts, but sign-in/profile/plans will fail on a real phone until it is built with the deployed URL (see `backend/render.yaml`; the backend is not confirmed deployed).
2. **Signing.** `android/app/build.gradle.kts` signs release with the **debug key** (TODO in the file); no keystore exists. These APKs cannot be uploaded to Play. Create an upload keystore, reference it from `key.properties`, keep it out of git, and back it up.
3. **Google sign-in** needs the release SHA-1/SHA-256 added in Firebase (TASKS.md "Manual setup").
4. **App icon** is still the default Flutter one (waiting for `app/assets/branding/app_icon.png`, then `tool/generate_icons.sh`).
5. **Size.** 109 MB universal / 41 MB per CPU is mostly on-device ML Kit translation and the vector-map style; consider dropping or lazy-loading translation if size matters.
6. Privacy policy and Terms are placeholders (launch blocker per TASKS.md). iOS not built (no Xcode here).

## Verified
Release build compiled, shrank and installed; on the emulator (arm64) it launches against the real Firebase project and shows the first-run intro; no crash in logcat. Not verified: sign-in, anything needing the API, Google sign-in, install on a physical phone.
