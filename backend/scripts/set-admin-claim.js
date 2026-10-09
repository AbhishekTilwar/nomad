#!/usr/bin/env node
/**
 * Admin bootstrap: grant (or revoke) the moderator/admin role for an existing Firebase Auth user.
 *
 * Sets BOTH factors the API requires:
 *   1. Auth custom claim            { role }
 *   2. users/{uid}/private/profile  role   (the user must have created a profile first)
 * then revokes the user's refresh tokens so the new claim takes effect on next sign-in.
 *
 * Usage:
 *   export GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/OUTSIDE/the/repo/service-account.json
 *   export FIREBASE_PROJECT_ID=<your-project-id>
 *   node scripts/set-admin-claim.js <uid> <admin|moderator|user> [--dry-run]
 *
 * Against the emulators (no credentials needed):
 *   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
 *   FIREBASE_PROJECT_ID=demo-nomadmingle node scripts/set-admin-claim.js <uid> admin
 *
 * Never commit the service account file. Run this from a trusted machine only.
 */
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

const [uid, role, flag] = process.argv.slice(2);
const ROLES = ['admin', 'moderator', 'user'];
if (!uid || !ROLES.includes(role)) {
  console.error('Usage: node scripts/set-admin-claim.js <uid> <admin|moderator|user> [--dry-run]');
  process.exit(2);
}
const usingEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST && process.env.FIREBASE_AUTH_EMULATOR_HOST);
if (!usingEmulator && !process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error('GOOGLE_APPLICATION_CREDENTIALS must point to a service account JSON stored outside the repo.');
  process.exit(2);
}
const projectId = process.env.FIREBASE_PROJECT_ID;
if (!projectId) {
  console.error('FIREBASE_PROJECT_ID is required.');
  process.exit(2);
}

initializeApp({ credential: usingEmulator ? undefined : applicationDefault(), projectId });
const auth = getAuth();
const db = getFirestore();

const user = await auth.getUser(uid);
const privRef = db.doc(`users/${uid}/private/profile`);
const profile = await db.doc(`users/${uid}`).get();
if (!profile.exists) {
  console.error('User has no profile yet. Ask them to sign in and complete the profile, then re-run.');
  process.exit(1);
}
console.log(`Target: ${uid} (${user.email ?? 'no email'}) -> role=${role}${flag === '--dry-run' ? ' [dry run]' : ''}`);
if (flag === '--dry-run') process.exit(0);

const claims = { ...(user.customClaims ?? {}) };
if (role === 'user') delete claims.role; else claims.role = role;
await auth.setCustomUserClaims(uid, claims);
await privRef.set({ role }, { merge: true });
await auth.revokeRefreshTokens(uid);
console.log('Done. The user must sign in again (or force-refresh their ID token) to receive the new claim.');
