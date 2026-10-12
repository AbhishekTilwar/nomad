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
   --dart-define=FIREBASE_STORAGE_BUCKET=$FB_BUCKET --dart-define=API_BASE_URL=https://nomad-266138323486.europe-west1.run.app/api/v1)
# Render backup is switched OFF for now. To turn it back on, add this to D (before the closing paren):
#   --dart-define=API_BACKUP_URL=https://nomad-emek.onrender.com/api/v1
flutter build apk --release --split-per-abi "${D[@]}"
flutter build appbundle --release "${D[@]}"
```

## Primary and backup server
`API_BASE_URL` is the main server (Google Cloud Run) and `API_BACKUP_URL` is the fallback (Render). The app switches to the backup for the same request when the primary can't be reached, takes over 12 s to answer a read, returns 502/503/504, or answers with something that isn't our API (e.g. Cloud Run's "Placeholder" page). Writes are only re-sent to the backup if they never reached the primary (never after a timeout). After a failover the backup is used for 3 minutes, then the primary is tried again. The backend must be deployed to **both** (same Firebase project) or users will see different data depending on which one answers.

**Status 2026-10-13:** `https://nomad-266138323486.europe-west1.run.app` answers 200 on every path but serves Google's default "Placeholder | Cloud Run" page, i.e. the API is not deployed there yet. Until it is, builds using it as primary will fall back to Render on the first request.

## Symptom: "Couldn't load your account" on a release build
That is the missing server address (item 1 below), not a connectivity problem. The release app signs in through Firebase directly, then asks *our* backend for the profile; with no `API_BASE_URL` it asks `localhost` on the phone and fails. From now on a release built without a real address shows "Server address isn't set" at launch instead, and a refused connection reads "Couldn't reach Nomad Mingle" (it used to say "No internet connection"). The address must be **https**: release builds block plain `http://` (only debug builds allow it).

## Before this can ship (not done, needs the owner)
1. ~~API address~~ **Done:** builds now use `https://nomad-emek.onrender.com/api/v1` (health check returns 200; API returns 401 without a token, as expected). Earlier builds had no address and failed on phones.
1a. **Cold starts.** The first request after the server has been idle took about 31 s to answer, so the app's request timeout was raised from 15 s to 45 s. A sleeping server still means a slow first launch; an always-on Render plan removes that (`plan:` in `backend/render.yaml`).
2. **Signing.** `android/app/build.gradle.kts` signs release with the **debug key** (TODO in the file); no keystore exists. These APKs cannot be uploaded to Play. Create an upload keystore, reference it from `key.properties`, keep it out of git, and back it up.
3. **Google sign-in** needs the release SHA-1/SHA-256 added in Firebase (TASKS.md "Manual setup").
4. **App icon** is still the default Flutter one (waiting for `app/assets/branding/app_icon.png`, then `tool/generate_icons.sh`).
5. **Size.** 109 MB universal / 41 MB per CPU is mostly on-device ML Kit translation and the vector-map style; consider dropping or lazy-loading translation if size matters.
6. Privacy policy and Terms are placeholders (launch blocker per TASKS.md). iOS not built (no Xcode here).

## Verified
Release build compiled, shrank and installed; on the emulator (arm64) it launches against the real Firebase project and shows the first-run intro; no crash in logcat. Not verified: sign-in, anything needing the API, Google sign-in, install on a physical phone.

## Known issue: "Validation failed" during onboarding on a release build
Not reproducible against this repo's backend code: a new Google-style user (Google photo URL, gender, skipped interests, "Tell your story" fields) succeeds at every step; the only rejected inputs are a display name under 2 or over 40 characters. The likely cause is that the **deployed server is older than the app**: the `gender` field and the profile extras were added on 2026-10-11, and `backend/render.yaml` has `autoDeploy: false`, so Render only updates on a manual deploy. **Unconfirmed** until the deployed server is checked.

To fix: in Render, open the service and choose *Manual Deploy → Deploy latest commit* (main is already pushed). To verify, `GET https://nomad-emek.onrender.com/health` now returns `{"status":"ok","version":"<commit>"}` once the new code is live (version is null on a server that predates this change, which itself tells you it is old).

The app now also names the field in validation errors ("Name: Too big…") and says "The server doesn't recognise something this app sent… The server may need updating" for unknown fields, so the next report is self-explanatory.
