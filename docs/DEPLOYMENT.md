# Deployment runbook (backend on Google Cloud Run + Android release)

Written 2026-10-13 after the first successful Cloud Run deploy. Read this before touching deploys. **No secrets are in this file**; it names where they live.

## What runs where

| Thing | Value |
|---|---|
| Backend (primary) | Cloud Run service `nomad`, project `cortiq-5f624`, region `europe-west1` |
| Backend URL | `https://nomad-266138323486.europe-west1.run.app` (also `https://nomad-jeshascsma-ew.a.run.app`) |
| Backend (backup, currently **off**) | Render `https://nomad-emek.onrender.com` |
| Firebase project the app and API use | `nomad-a1150` (a **different** project from the Cloud Run one) |
| Container image | `europe-west1-docker.pkg.dev/cortiq-5f624/cloud-run-source-deploy/nomad/nomad:<commit-sha>` |
| Cloud Run service account | `266138323486-compute@developer.gserviceaccount.com` (default compute SA) |
| GitHub repo | `AbhishekTilwar/nomad`, branch `main` |
| gcloud account used | `abhishektilwar02@gmail.com` (owns `cortiq-5f624`; has **no** access to `nomad-a1150`) |

## How a deploy happens

Push to `main` -> Cloud Build trigger **`nomad-deploy`** (id `89039e73-022a-48ad-a452-906408377be5`, global) runs [`cloudbuild.yaml`](../cloudbuild.yaml): build the root [`Dockerfile`](../Dockerfile) -> push image -> `gcloud run deploy nomad`. The build runs as the compute service account.

Manual run of the same thing: `gcloud builds triggers run nomad-deploy --project cortiq-5f624 --region global --branch=main`.

One-off build from your machine (does not need a push):
```
gcloud builds submit --config cloudbuild.yaml --substitutions=COMMIT_SHA=manual-$(date +%H%M) \
  --project cortiq-5f624 --region europe-west1 \
  --service-account projects/cortiq-5f624/serviceAccounts/266138323486-compute@developer.gserviceaccount.com .
```

## Service configuration (Cloud Run -> Variables & secrets)

| Name | Value | Notes |
|---|---|---|
| `FIREBASE_PROJECT_ID` | `nomad-a1150` | **Required.** The server refuses to start without it. |
| `NODE_ENV` | `production` | |
| `TRUST_PROXY` | `1` | Cloud Run is behind a proxy (rate limits use the client IP). |
| `ALLOWED_ORIGINS` | empty | Mobile apps send no Origin. Never `*`. |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | **secret** `firebase-admin-key` (Secret Manager, `cortiq-5f624`), version `latest` | The `nomad-a1150` Firebase Admin key. Secret accessor granted to the compute SA. |
| `PORT` | set by Cloud Run (8080) | Don't set it. |

Optional (defaults are fine): `CRON_SECRET` (>= 24 chars, enables `/internal/jobs/*`), `LOG_LEVEL`, rate-limit settings. See `backend/.env.example` and `backend/src/config/env.js`.

Update the key: `gcloud secrets versions add firebase-admin-key --project cortiq-5f624 --data-file=<new-key.json>`, then deploy a new revision (`gcloud run services update nomad ... --update-secrets=FIREBASE_SERVICE_ACCOUNT_JSON=firebase-admin-key:latest`). Delete the downloaded key file afterwards.

## Why cross-project access uses a key, not IAM

The Cloud Run project (`cortiq-5f624`) differs from the Firebase project (`nomad-a1150`). Granting the Cloud Run service account roles on `nomad-a1150` was refused: our gcloud account has no access there, and the console rejected the principal ("Email addresses and domains must be associated with an active Google Account..."), most likely an organisation domain-sharing policy. So the server authenticates with a Firebase Admin **service-account key** stored as a secret. If you later grant IAM instead (`roles/datastore.user`, `roles/firebaseauth.admin`, `roles/firebasemessaging.admin` on `nomad-a1150`), you can remove the secret and the app keeps working (Application Default Credentials).

## Check a deploy worked

```
curl -s https://nomad-266138323486.europe-west1.run.app/health        # {"status":"ok",...}
curl -s -o /dev/null -w "%{http_code}\n" https://nomad-266138323486.europe-west1.run.app/api/v1/users/me   # 401 without a token
```
A real-data check: create a throwaway email sign-up with the web API key from `app/android/app/google-services.json` (Identity Toolkit `accounts:signUp`), call `GET /api/v1/users/me` with its ID token (expect **404 "Profile not created yet"**, which proves token verification and a Firestore read), then delete the throwaway account (`accounts:delete`).

If `/health` returns an HTML page titled **"Placeholder | Cloud Run"**, our image is not deployed (that is Cloud Run's default sample).

## Problems we hit and what fixed them (2026-10-13)

1. **"Container failed to start and listen on the port defined by PORT=8080"** repeated on every revision.
   - Cause A: the image in use came from commit `25644f6` (before the Dockerfile existed); its start command ran `npm ci` and exited 0, so no server ever listened. Fix: add the root `Dockerfile` (`CMD npm start`) and build from it.
   - Cause B (also required): `FIREBASE_PROJECT_ID` was not set; `loadConfig` throws before `listen()`. Reproduce locally with `env -i NODE_ENV=production PORT=8099 node backend/src/server.js`.
   - Find the real error: `gcloud logging read 'resource.type="cloud_run_revision" AND resource.labels.service_name="nomad" AND resource.labels.revision_name="<rev>"' --project cortiq-5f624 --limit 30 --freshness=3d`. The console message is generic; the log shows the cause.
2. **Builds from pushes failed in 0 seconds** with `if 'build.service_account' is specified, the build must either specify 'build.logs_bucket', ... or use CLOUD_LOGGING_ONLY`. The auto-created trigger ran as the compute service account with no logging option, and an autodetect trigger cannot carry options. Fix: `cloudbuild.yaml` with `options.logging: CLOUD_LOGGING_ONLY`, and a new trigger (`nomad-deploy`) using it (editing the old trigger's build config was rejected as an invalid argument).
3. **`${PROJECT_ID}` inside a user substitution** (`_IMAGE`) is rejected ("could not parse reference"). The project id is hard-coded in `_IMAGE`.
4. **`gcloud auth login` through the Claude Code `!` prefix saves nothing** (no TTY for the code hand-back). Run it in a real terminal, or let the tool open the browser flow (localhost callback) and click Allow.
5. **Old trigger** `rmgpgab-nomad-europe-west1-AbhishekTilwar-nomad--mataj` (id `151a4587-1726-469d-ace4-a8a5125fbc08`) still exists and still fails instantly on every push (harmless noise). Delete or disable it in Cloud Build -> Triggers once `nomad-deploy` is confirmed.

## Dockerfile / image notes

- [`Dockerfile`](../Dockerfile) is at the **repo root** (`COPY backend/...`), Node 22, `npm ci --omit=dev`, `CMD npm start`, `PORT=8080`.
- There is **no `.dockerignore` yet**: `COPY backend/ ./` copies a local `backend/node_modules` and `backend/.env` into the image if they exist on the build machine (cloud builds from a clean git checkout are unaffected; local `gcloud builds submit .` uploads ~100 MB including them). Add one listing `backend/node_modules`, `backend/.env`, `backend/test`, `.git`.

## Android release build (against Cloud Run)

Firebase identifiers come from `app/android/app/google-services.json` (not secret; the file is git-ignored). Details and the zsh array gotcha: [RELEASE_BUILD.md](RELEASE_BUILD.md). Command (from `app/`):
```
eval $(python3 - <<'PY'
import json
d=json.load(open('android/app/google-services.json')); c=d['client'][0]
print("FB_KEY=%s FB_APP=%s FB_SENDER=%s FB_PROJECT=%s FB_BUCKET=%s" % (c['api_key'][0]['current_key'], c['client_info']['mobilesdk_app_id'], d['project_info']['project_number'], d['project_info']['project_id'], d['project_info'].get('storage_bucket','')))
PY
)
D=(--dart-define=FIREBASE_API_KEY=$FB_KEY --dart-define=FIREBASE_APP_ID=$FB_APP --dart-define=FIREBASE_MESSAGING_SENDER_ID=$FB_SENDER --dart-define=FIREBASE_PROJECT_ID=$FB_PROJECT --dart-define=FIREBASE_STORAGE_BUCKET=$FB_BUCKET --dart-define=API_BASE_URL=https://nomad-266138323486.europe-west1.run.app/api/v1)
flutter build apk --release --split-per-abi "${D[@]}"      # 3 APKs; send app-arm64-v8a-release.apk
flutter build appbundle --release "${D[@]}"                # Play Store bundle (needs a real upload key)
```
Check the address baked in: `unzip -p build/app/outputs/flutter-apk/app-arm64-v8a-release.apk lib/arm64-v8a/libapp.so | strings | grep -o "https://nomad[a-z0-9.-]*"`.

**Backup server (off):** add `--dart-define=API_BACKUP_URL=https://nomad-emek.onrender.com/api/v1` to `D` to enable automatic failover (see "Primary and backup server" in RELEASE_BUILD.md). Failover covers unreachable server, 502/503/504, a non-JSON reply, and slow reads, but **not** plain 500s. Both servers must use the same Firebase project and the same backend code.

## Still open

- Signing: release builds use the **debug key**; Play upload needs a real keystore and the SHA-1/SHA-256 of the signing key added in Firebase (Google sign-in fails otherwise).
- Delete the downloaded Firebase Admin key files (e.g. in `~/Downloads`) once stored in Secret Manager; rotate keys you no longer need (also the unrelated `cortiq-5f624` and `dapp-79473` keys that sit there).
- Render server is outdated vs the app (older backend); redeploy it before ever enabling it as a backup.
- Not exercised against Cloud Run yet: creating plans, joining, chat and private messages with a full account (only login + a Firestore read were verified).
