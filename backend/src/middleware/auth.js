import { wrap } from '../lib/http.js';
import { unauthenticated, restricted, forbidden } from '../lib/errors.js';
import { toMillis } from '../lib/time.js';

const RESTRICTED = new Set(['suspended', 'deleted']);
// Restricted users may still see their own status and delete their own account.
const isRestrictedExempt = (req) => req.path === '/users/me' && (req.method === 'GET' || req.method === 'DELETE');

/**
 * Verifies the Firebase ID token with the Admin SDK (optionally checking revocation) and loads
 * the denormalised public profile to enforce account status on every request.
 */
export function authenticate({ auth, db, config }) {
  return wrap(async (req, _res, next) => {
    const header = req.get('authorization') || '';
    const m = /^Bearer\s+(\S+)$/i.exec(header);
    if (!m) throw unauthenticated();
    let decoded;
    try {
      decoded = await auth.verifyIdToken(m[1], config.checkRevoked);
    } catch {
      throw unauthenticated('Invalid or expired token');
    }
    const snap = await db.doc(`users/${decoded.uid}`).get();
    const profile = snap.exists ? snap.data() : null;
    const status = profile?.accountStatus ?? null;
    req.user = {
      uid: decoded.uid,
      claims: decoded,
      profile,
      accountStatus: status,
      createdAtMs: toMillis(profile?.createdAt),
    };
    if (RESTRICTED.has(status) && !isRestrictedExempt(req)) {
      throw restricted('Your account is not active', { accountStatus: status });
    }
    next();
  });
}

/** Require a completed profile (created through PUT /users/me). */
export function requireProfile(req, _res, next) {
  if (!req.user?.profile || !req.user.profile.profileCompleted) {
    return next(forbidden('Complete your profile first', { reason: 'profile_incomplete' }));
  }
  return next();
}
