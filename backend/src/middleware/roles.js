import { forbidden } from '../lib/errors.js';
import { wrap } from '../lib/http.js';

const RANK = { user: 0, moderator: 1, admin: 2 };

/**
 * Staff gate. The Auth custom claim `role` AND the private profile role must both grant
 * moderator/admin; the effective role is the lower of the two. A stale claim alone is not enough
 * and a Firestore edit alone is not enough.
 */
export function requireStaff({ db }) {
  return wrap(async (req, _res, next) => {
    const claimRank = RANK[req.user.claims?.role] ?? 0;
    if (claimRank < 1) throw forbidden('Staff access required');
    const priv = await db.doc(`users/${req.user.uid}/private/profile`).get();
    const profileRank = RANK[priv.data()?.role] ?? 0;
    const rank = Math.min(claimRank, profileRank);
    if (rank < 1) throw forbidden('Staff access required');
    req.staff = { uid: req.user.uid, role: rank >= 2 ? 'admin' : 'moderator' };
    next();
  });
}
