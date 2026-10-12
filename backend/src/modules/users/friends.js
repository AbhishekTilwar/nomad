import { conflict, forbidden, invalid, notFound, rateLimited } from '../../lib/errors.js';
import { toJson } from '../../lib/serialize.js';
import { decodeCursor, encodeCursor } from '../../lib/pagination.js';
import { actorData } from '../notifications/service.js';

/** Max outgoing pending friend requests per user (cost / spam guard). */
export const MAX_PENDING_OUTGOING = 100;
/** Max friendship docs scanned when listing incoming requests. */
const REQUEST_SCAN = 200;

export const friendshipId = (a, b) => [a, b].sort().join('_');

/** Friendships: friendships/{sortedUidA_sortedUidB} = { users, requesterId, status, createdAt, updatedAt }. */
export function createFriendsService({ db, fv, notifications }) {
  const fRef = (a, b) => db.doc(`friendships/${friendshipId(a, b)}`);
  const pubRef = (uid) => db.doc(`users/${uid}`);
  const usable = (d) => d && d.accountStatus !== 'deleted' && d.accountStatus !== 'suspended';

  async function statusWith(me, other) {
    if (me === other) return 'none';
    const s = await fRef(me, other).get();
    if (!s.exists) return 'none';
    const f = s.data();
    if (f.status === 'accepted') return 'friends';
    return f.requesterId === me ? 'request_sent' : 'request_received';
  }

  /**
   * True when both people are approved members of the same plan that isn't cancelled (they have been in
   * a group chat together). Bounded: looks at the caller's newest 200 memberships, then reads only the
   * other person's membership doc in each (one parallel read each) and the matching activity docs.
   */
  async function sharesPlan(a, b) {
    if (a === b) return false;
    const mine = await db.collectionGroup('members').where('userId', '==', a).where('status', '==', 'approved').limit(200).get();
    const activities = mine.docs.map((d) => d.ref.parent.parent);
    if (!activities.length) return false;
    const theirs = await Promise.all(activities.map((r) => r.collection('members').doc(b).get()));
    const shared = theirs.filter((s) => s.exists && s.data().status === 'approved').map((s) => s.ref.parent.parent);
    if (!shared.length) return false;
    const docs = await Promise.all(shared.map((r) => r.get()));
    return docs.some((s) => s.exists && s.data().status !== 'cancelled');
  }

  /** Private messages are allowed between friends and between people who share a plan. Block checks are separate. */
  async function canMessage(me, other) {
    if (me === other) return false;
    if ((await statusWith(me, other)) === 'friends') return true;
    return sharesPlan(me, other);
  }

  async function blockedEitherWay(a, b) {
    const [x, y] = await Promise.all([db.doc(`userBlocks/${a}/blocked/${b}`).get(), db.doc(`userBlocks/${b}/blocked/${a}`).get()]);
    return x.exists || y.exists;
  }

  async function sendRequest(user, target) {
    const me = user.uid;
    if (me === target) throw invalid('You cannot send a friend request to yourself');
    const t = await pubRef(target).get();
    if (!t.exists || !usable(t.data())) throw notFound('User not found');
    if (await blockedEitherWay(me, target)) throw forbidden('You cannot send a friend request to this user');

    const outcome = await db.runTransaction(async (tx) => {
      const snap = await tx.get(fRef(me, target));
      if (snap.exists) {
        const f = snap.data();
        if (f.status === 'accepted') throw conflict('You are already friends', { reason: 'already_friends' });
        if (f.requesterId === me) throw conflict('Friend request already sent', { reason: 'already_requested' });
        tx.update(fRef(me, target), { status: 'accepted', updatedAt: fv.serverTimestamp() });
        return 'friends';
      }
      const pending = await db.collection('friendships').where('requesterId', '==', me).where('status', '==', 'pending').count().get();
      if (pending.data().count >= MAX_PENDING_OUTGOING) {
        throw rateLimited('Too many pending friend requests', { reason: 'pending_limit', limit: MAX_PENDING_OUTGOING });
      }
      tx.set(fRef(me, target), {
        users: [me, target].sort(), requesterId: me, status: 'pending',
        createdAt: fv.serverTimestamp(), updatedAt: fv.serverTimestamp(),
      });
      return 'request_sent';
    });

    const name = user.profile.displayName;
    await notifications.notify(target, outcome === 'friends'
      ? { type: 'friend_accepted', title: 'New friend', body: `${name} accepted your friend request`, data: { userId: me, ...actorData(me, user.profile) } }
      : { type: 'friend_request', title: 'New friend request', body: `${name} wants to be your friend`, data: { userId: me, ...actorData(me, user.profile) } });
    return { friendship: outcome };
  }

  async function accept(user, other) {
    const me = user.uid;
    if (me === other) throw invalid('Invalid user');
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(fRef(me, other));
      if (!snap.exists) throw notFound('No friend request from this user');
      const f = snap.data();
      if (f.status === 'accepted') throw conflict('You are already friends', { reason: 'already_friends' });
      if (f.requesterId === me) throw forbidden('You cannot accept your own request');
      tx.update(fRef(me, other), { status: 'accepted', updatedAt: fv.serverTimestamp() });
    });
    await notifications.notify(other, {
      type: 'friend_accepted', title: 'Friend request accepted', body: `${user.profile.displayName} accepted your friend request`,
      data: { userId: me, ...actorData(me, user.profile) },
    });
    return { friendship: 'friends' };
  }

  /** Cancels a pending request you sent, declines one you received, or unfriends. Idempotent. */
  async function remove(me, other) {
    if (me === other) throw invalid('Invalid user');
    await fRef(me, other).delete();
    return { friendship: 'none' };
  }

  async function profiles(uids) {
    const snaps = await Promise.all(uids.map((u) => pubRef(u).get()));
    return snaps.map((s, i) => ({ uid: uids[i], d: s.exists ? s.data() : null }))
      .filter(({ d }) => usable(d))
      .map(({ uid, d }) => ({ uid, displayName: d.displayName, photoUrl: d.photoUrl ?? null, countryCode: d.countryCode ?? null }));
  }

  async function listFriends(me, { limit, cursor }) {
    const c = decodeCursor(cursor);
    if (cursor && !c?.id) throw invalid('Invalid cursor');
    let q = db.collection('friendships').where('users', 'array-contains', me).where('status', '==', 'accepted').orderBy('updatedAt', 'desc');
    if (c) {
      const last = await db.doc(`friendships/${c.id}`).get();
      if (!last.exists) throw invalid('Invalid cursor');
      q = q.startAfter(last);
    }
    const snap = await q.limit(limit + 1).get();
    const page = snap.docs.slice(0, limit);
    const items = await profiles(page.map((d) => d.data().users.find((u) => u !== me)));
    const nextCursor = snap.docs.length > limit ? encodeCursor({ id: page[page.length - 1].id }) : null;
    return { items, nextCursor };
  }

  async function listRequests(me, { limit }) {
    const snap = await db.collection('friendships').where('users', 'array-contains', me).where('status', '==', 'pending')
      .orderBy('createdAt', 'desc').limit(REQUEST_SCAN).get();
    const incoming = snap.docs.filter((d) => d.data().requesterId !== me).slice(0, limit);
    const profs = await profiles(incoming.map((d) => d.data().requesterId));
    const at = new Map(incoming.map((d) => [d.data().requesterId, toJson(d.data().createdAt)]));
    return profs.map((p) => ({ ...p, requestedAt: at.get(p.uid) ?? null }));
  }

  return { statusWith, sharesPlan, canMessage, sendRequest, accept, remove, listFriends, listRequests };
}
