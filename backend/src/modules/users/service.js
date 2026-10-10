import { conflict, forbidden, invalid, notFound } from '../../lib/errors.js';
import { toJson } from '../../lib/serialize.js';
import { sha256 } from '../../lib/text.js';
import { toMillis, ts } from '../../lib/time.js';
import { encodeCursor, decodeCursor } from '../../lib/pagination.js';
import { haversineKm } from '../../lib/geo.js';
import { friendshipId } from './friends.js';

export const PUBLIC_FIELDS = [
  'displayName', 'photoUrl', 'bio', 'city', 'interests', 'ageRange', 'accountStatus',
  'countryCode', 'instagram', 'profileCompleted', 'emailVerified', 'stats', 'createdAt', 'updatedAt',
];
const DEFAULT_PREFS = { joinRequests: true, approvals: true, activityUpdates: true, reminders: true, moderation: true, friends: true };
/** Max user docs read per travelers query (cost cap) and how long a location stays fresh. */
const TRAVELERS_SCAN = 300;
const LOCATION_FRESH_MS = 30 * 24 * 3600_000;
const KM_PER_DEG_LAT = 111.19;
const round2 = (n) => Math.round(n * 100) / 100;
const DELETED_NAME = 'Deleted user';

export function ageOn(dob, nowMs) {
  const [y, m, d] = dob.split('-').map(Number);
  const n = new Date(nowMs);
  let age = n.getUTCFullYear() - y;
  if (n.getUTCMonth() + 1 < m || (n.getUTCMonth() + 1 === m && n.getUTCDate() < d)) age--;
  return age;
}

export function ageRangeFor(age) {
  if (age < 25) return '18-24';
  if (age < 35) return '25-34';
  if (age < 45) return '35-44';
  if (age < 55) return '45-54';
  return '55+';
}

async function deleteQuery(query, size = 300) {
  // Repeatedly delete up to `size` docs until the query is empty.
  for (;;) {
    const snap = await query.limit(size).get();
    if (snap.empty) return;
    const batch = query.firestore.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
    if (snap.size < size) return;
  }
}

export function createUsersService({ db, auth, fv, now, logger, activities }) {
  const pubRef = (uid) => db.doc(`users/${uid}`);
  const privRef = (uid) => db.doc(`users/${uid}/private/profile`);

  const publicView = (data) => {
    const out = {};
    for (const k of PUBLIC_FIELDS) if (data[k] !== undefined) out[k] = data[k];
    return toJson(out);
  };

  async function getMe(uid) {
    const [pub, priv] = await Promise.all([pubRef(uid).get(), privRef(uid).get()]);
    if (!pub.exists) throw notFound('Profile not created yet');
    const p = priv.data() ?? {};
    return {
      uid,
      ...publicView(pub.data()),
      discoverable: pub.data().discoverable === true,
      private: toJson({
        preferredActivityTypes: p.preferredActivityTypes ?? [],
        notificationPrefs: { ...DEFAULT_PREFS, ...(p.notificationPrefs ?? {}) },
        role: p.role ?? 'user',
        mutedUntil: p.mutedUntil ?? null,
        ageVerifiedAt: p.ageVerifiedAt ?? null,
        // dateOfBirth intentionally never returned.
      }),
    };
  }

  async function upsertProfile(user, body, { partial }) {
    const { uid } = user;
    const t = now();
    const result = await db.runTransaction(async (tx) => {
      const [pub, priv] = await Promise.all([tx.get(pubRef(uid)), tx.get(privRef(uid))]);
      const existing = pub.exists ? pub.data() : null;
      const existingPriv = priv.exists ? priv.data() : null;

      if (partial && !existing) throw notFound('Profile not created yet; use PUT /users/me');
      if (!existing && !body.dateOfBirth) {
        throw invalid('Validation failed', [{ path: 'dateOfBirth', message: 'dateOfBirth is required to create a profile' }]);
      }
      const privUpdate = {};
      let ageRange = existing?.ageRange;
      if (body.dateOfBirth) {
        const storedDob = existingPriv?.dateOfBirth;
        if (storedDob && storedDob !== body.dateOfBirth) throw conflict('dateOfBirth cannot be changed');
        if (!storedDob) {
          const age = ageOn(body.dateOfBirth, t);
          if (age < 18) {
            throw invalid('You must be at least 18 to use Nomad Mingle', [{ path: 'dateOfBirth', message: 'Must be at least 18 years old' }]);
          }
          if (age > 110) throw invalid('Validation failed', [{ path: 'dateOfBirth', message: 'Invalid date' }]);
          privUpdate.dateOfBirth = body.dateOfBirth;
          privUpdate.ageVerifiedAt = ts(t);
          ageRange = ageRangeFor(age);
        }
      }

      const merged = { ...(existing ?? {}) };
      for (const k of ['displayName', 'bio', 'city', 'interests', 'photoUrl', 'countryCode', 'instagram']) if (body[k] !== undefined) merged[k] = body[k];
      const pubDoc = {
        displayName: merged.displayName,
        photoUrl: merged.photoUrl ?? null,
        bio: merged.bio ?? '',
        city: merged.city,
        interests: merged.interests ?? [],
        countryCode: merged.countryCode ?? null,
        instagram: merged.instagram ?? null,
        ageRange,
        accountStatus: existing?.accountStatus ?? 'active',
        profileCompleted: Boolean(merged.displayName && merged.city && ageRange),
        emailVerified: user.claims?.email_verified === true,
        stats: existing?.stats ?? { hosted: 0, attended: 0 },
        createdAt: existing?.createdAt ?? fv.serverTimestamp(),
        updatedAt: fv.serverTimestamp(),
      };
      // Travelers fields are owned by PUT /users/me/location; a profile edit must not wipe them.
      for (const k of ['discoverable', 'approxLat', 'approxLng', 'locationUpdatedAt']) {
        if (existing?.[k] !== undefined) pubDoc[k] = existing[k];
      }
      tx.set(pubRef(uid), pubDoc);

      if (!existingPriv) {
        tx.set(privRef(uid), {
          dateOfBirth: privUpdate.dateOfBirth,
          ageVerifiedAt: privUpdate.ageVerifiedAt,
          preferredActivityTypes: body.preferredActivityTypes ?? [],
          notificationPrefs: DEFAULT_PREFS,
          role: 'user',
          mutedUntil: null,
          violationCount: 0,
        });
      } else {
        const upd = { ...privUpdate };
        if (body.preferredActivityTypes !== undefined) upd.preferredActivityTypes = body.preferredActivityTypes;
        if (Object.keys(upd).length) tx.update(privRef(uid), upd);
      }
      const snapshotChanged =
        existing && (body.displayName !== undefined && body.displayName !== existing.displayName ||
          body.photoUrl !== undefined && body.photoUrl !== (existing.photoUrl ?? null));
      return { created: !existing, snapshotChanged, name: pubDoc.displayName, photo: pubDoc.photoUrl };
    });

    if (result.snapshotChanged) await refreshHostSnapshots(uid, result.name, result.photo);
    return { ...(await getMe(uid)), created: result.created };
  }

  async function refreshHostSnapshots(uid, name, photo) {
    try {
      const snap = await db.collection('activities').where('hostId', '==', uid).where('status', '==', 'scheduled').limit(400).get();
      if (snap.empty) return;
      const batch = db.batch();
      snap.docs.forEach((d) => batch.update(d.ref, { hostDisplayName: name, hostPhotoUrl: photo }));
      await batch.commit();
    } catch (err) {
      logger.warn({ err: { message: err?.message } }, 'host snapshot refresh failed');
    }
  }

  async function getPublic(uid) {
    const snap = await pubRef(uid).get();
    const d = snap.data();
    if (!snap.exists || d.accountStatus === 'deleted' || d.accountStatus === 'suspended') throw notFound('User not found');
    const { accountStatus: _s, emailVerified: _e, ...rest } = publicView(d);
    return { uid, ...rest };
  }

  // ---- blocks
  async function listBlocks(uid) {
    const snap = await db.collection(`userBlocks/${uid}/blocked`).orderBy('blockedAt', 'desc').limit(500).get();
    return snap.docs.map((d) => ({ uid: d.id, ...toJson(d.data()) }));
  }

  async function block(uid, target) {
    if (uid === target) throw invalid('You cannot block yourself');
    const t = await pubRef(target).get();
    if (!t.exists || t.data().accountStatus === 'deleted') throw notFound('User not found');
    await db.doc(`userBlocks/${uid}/blocked/${target}`).set({
      blockedAt: fv.serverTimestamp(),
      targetDisplayName: t.data().displayName ?? '',
    });
    await db.doc(`friendships/${friendshipId(uid, target)}`).delete(); // blocking ends any friendship/request
    return { blocked: true };
  }

  async function unblock(uid, target) {
    await db.doc(`userBlocks/${uid}/blocked/${target}`).delete();
    return { blocked: false };
  }

  async function blockedIds(uid) {
    const snap = await db.collection(`userBlocks/${uid}/blocked`).limit(500).get();
    return new Set(snap.docs.map((d) => d.id));
  }

  // ---- travelers
  async function setLocation(uid, { lat, lng, discoverable }) {
    if (!discoverable) {
      await pubRef(uid).update({
        discoverable: false, approxLat: fv.delete(), approxLng: fv.delete(), locationUpdatedAt: fv.delete(),
      });
      return { discoverable: false };
    }
    // ~1.1 km precision: exact coordinates are never stored on the public doc.
    await pubRef(uid).update({
      discoverable: true, approxLat: round2(lat), approxLng: round2(lng), locationUpdatedAt: fv.serverTimestamp(),
    });
    return { discoverable: true };
  }

  /**
   * Bounded latitude-band query (discoverable + approxLat range, scan cap TRAVELERS_SCAN) then Haversine
   * filter/sort in memory; offset cursor. Blocks are checked lazily in distance order.
   */
  async function listTravelers(user, { lat, lng, radiusKm, limit, cursor }) {
    const c = decodeCursor(cursor);
    if (c === undefined || (c && !(Number.isInteger(c.o) && c.o >= 0))) throw invalid('Invalid cursor');
    const offset = c?.o ?? 0;
    const dLat = radiusKm / KM_PER_DEG_LAT + 0.01;
    const snap = await db.collection('users')
      .where('discoverable', '==', true)
      .where('approxLat', '>=', lat - dLat).where('approxLat', '<=', lat + dLat)
      .orderBy('approxLat').limit(TRAVELERS_SCAN).get();
    const minUpdated = now() - LOCATION_FRESH_MS;
    const cands = [];
    for (const d of snap.docs) {
      const u = d.data();
      if (d.id === user.uid || u.accountStatus !== 'active' || u.profileCompleted !== true) continue;
      if (typeof u.approxLng !== 'number' || !u.locationUpdatedAt || toMillis(u.locationUpdatedAt) < minUpdated) continue;
      const km = haversineKm(lat, lng, u.approxLat, u.approxLng);
      if (km > radiusKm) continue;
      cands.push({ uid: d.id, u, km });
    }
    cands.sort((a, b) => a.km - b.km || (a.uid < b.uid ? -1 : 1));
    const mine = await blockedIds(user.uid);
    const out = [];
    let hasMore = false;
    for (const x of cands) {
      if (mine.has(x.uid)) continue;
      if ((await db.doc(`userBlocks/${x.uid}/blocked/${user.uid}`).get()).exists) continue;
      if (out.length === offset + limit) { hasMore = true; break; }
      out.push({
        uid: x.uid, displayName: x.u.displayName, photoUrl: x.u.photoUrl ?? null,
        countryCode: x.u.countryCode ?? null, city: x.u.city, distanceKm: Math.round(x.km * 10) / 10,
      });
    }
    const items = out.slice(offset);
    return { items, nextCursor: hasMore ? encodeCursor({ o: offset + limit }) : null, total: cands.length };
  }

  // ---- prefs / tokens
  async function setPrefs(uid, prefs) {
    const upd = {};
    for (const [k, v] of Object.entries(prefs)) upd[`notificationPrefs.${k}`] = v;
    if (!Object.keys(upd).length) throw invalid('No preferences supplied');
    await privRef(uid).update(upd);
    return { ...DEFAULT_PREFS, ...(await privRef(uid).get()).data().notificationPrefs };
  }

  async function addDeviceToken(uid, { token, platform }) {
    await db.doc(`deviceTokens/${sha256(token)}`).set({ uid, token, platform, updatedAt: fv.serverTimestamp() });
    return { registered: true };
  }

  async function removeDeviceToken(uid, token) {
    const ref = db.doc(`deviceTokens/${sha256(token)}`);
    const snap = await ref.get();
    if (snap.exists && snap.data().uid !== uid) throw forbidden('Token belongs to another user');
    if (snap.exists) await ref.delete();
    return { removed: true };
  }

  // ---- account deletion
  async function deleteAccount(user) {
    const { uid } = user;
    await pubRef(uid).set({ accountStatus: 'deleted', updatedAt: fv.serverTimestamp() }, { merge: true });

    const hosted = await db.collection('activities').where('hostId', '==', uid).where('status', '==', 'scheduled').get();
    for (const a of hosted.docs) {
      try {
        await activities.cancelActivity({ activityId: a.id, actor: { uid }, reason: 'Host deleted their account', system: true });
      } catch (err) { logger.warn({ err: { message: err?.message } }, 'cancel on delete failed'); }
    }
    const memberships = await db.collectionGroup('members').where('userId', '==', uid).get();
    for (const m of memberships.docs) {
      const activityId = m.ref.parent.parent.id;
      if (m.data().role !== 'host' && ['approved', 'requested'].includes(m.data().status)) {
        try { await activities.leaveActivity({ activityId, uid, silent: true }); } catch { /* activity may be closed */ }
      }
      await m.ref.update({ displayName: DELETED_NAME, photoUrl: null });
    }
    for (;;) {
      const snap = await db.collectionGroup('messages').where('senderId', '==', uid).limit(300).get();
      const todo = snap.docs.filter((d) => !d.data().senderDeleted);
      if (!todo.length) break;
      const batch = db.batch();
      todo.forEach((d) => batch.update(d.ref, { senderName: DELETED_NAME, senderPhotoUrl: null, senderDeleted: true }));
      await batch.commit();
      if (snap.size < 300) break;
    }
    await deleteQuery(db.collection('deviceTokens').where('uid', '==', uid));
    await deleteQuery(db.collection('notifications').where('userId', '==', uid));
    await deleteQuery(db.collection(`userBlocks/${uid}/blocked`));
    await deleteQuery(db.collection('friendships').where('users', 'array-contains', uid));
    await db.doc(`userRateLimits/${uid}`).delete();
    await privRef(uid).delete();
    await pubRef(uid).delete();
    try {
      await auth.deleteUser(uid);
    } catch (err) {
      if (err?.code !== 'auth/user-not-found') throw err;
    }
    return { deleted: true };
  }

  return { getMe, upsertProfile, getPublic, setLocation, listTravelers, listBlocks, block, unblock, blockedIds, setPrefs, addDeviceToken, removeDeviceToken, deleteAccount };
}
