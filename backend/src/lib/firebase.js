import { initializeApp, cert, applicationDefault, getApps } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';

/** Build production dependencies. Credentials come from env / ADC only; nothing is read from the repo. */
export function createFirebaseDeps(config) {
  if (!getApps().length) {
    let credential;
    if (config.serviceAccountJson) {
      const raw = config.serviceAccountJson.trim();
      const json = raw.startsWith('{') ? raw : Buffer.from(raw, 'base64').toString('utf8');
      credential = cert(JSON.parse(json));
    } else {
      credential = applicationDefault();
    }
    initializeApp({ credential, projectId: config.projectId });
  }
  const db = getFirestore();
  db.settings({ ignoreUndefinedProperties: true });
  return {
    db,
    auth: getAuth(),
    messaging: getMessaging(),
    fv: { serverTimestamp: () => FieldValue.serverTimestamp(), delete: () => FieldValue.delete() },
  };
}
