import { conflict, forbidden, invalid, notFound } from '../../lib/errors.js';
import { encodeGeohash } from '../../lib/geo.js';
import { toJson } from '../../lib/serialize.js';
import { toMillis, ts } from '../../lib/time.js';
import { createActivityQueryService } from './queryService.js';
import { actorData } from '../notifications/service.js';
import { decodeCursor, encodeCursor } from '../../lib/pagination.js';

/** Max membership docs scanned per "my activities" request (bounds read cost). */
const MY_ACTIVITIES_SCAN = 200;

const MAX_DURATION_MS = 24 * 3600_000;
const MAX_ADVANCE_MS = 366 * 24 * 3600_000;

export function validateTimes(startMs, endMs, nowMs) {
  const errs = [];
  if (startMs <= nowMs) errs.push({ path: 'startAt', message: 'startAt must be in the future' });
  if (startMs > nowMs + MAX_ADVANCE_MS) errs.push({ path: 'startAt', message: 'startAt must be within one year' });
  if (endMs <= startMs) errs.push({ path: 'endAt', message: 'endAt must be after startAt' });
  else if (endMs - startMs > MAX_DURATION_MS) errs.push({ path: 'endAt', message: 'Activity cannot last longer than 24 hours' });
  if (errs.length) throw invalid('Validation failed', errs);
}

export function createActivitiesService({ db, fv, now, notifications, config, query }) {
  const qs = query ?? createActivityQueryService({ db, now });
  const aRef = (id) => db.doc(`activities/${id}`);
  const mRef = (id, uid) => db.doc(`activities/${id}/members/${uid}`);

  const view = (snap) => {
    const { reminderSentAt: _r, ...rest } = snap.data();
    return { id: snap.id, ...toJson(rest) };
  };

  async function memberStatus(activityId, uid) {
    const m = await mRef(activityId, uid).get();
    return m.exists ? m.data().status : 'none';
  }

  /** Loads an activity the viewer may see; private activities are hidden from non-members. */
  async function loadVisible(id, uid) {
    const snap = await aRef(id).get();
    if (!snap.exists) throw notFound('Activity not found');
    const a = snap.data();
    const isHost = a.hostId === uid;
    const status = isHost ? 'approved' : await memberStatus(id, uid);
    if (a.visibility === 'private' && !isHost && status === 'none') throw notFound('Activity not found');
    return { snap, a, isHost, membershipStatus: status };
  }

  // ------------------------------------------------------------------ create / update
  async function createActivity(user, body) {
    const t = now();
    const startMs = Date.parse(body.startAt);
    const endMs = Date.parse(body.endAt);
    validateTimes(startMs, endMs, t);

    const active = await db.collection('activities').where('hostId', '==', user.uid).where('status', '==', 'scheduled').count().get();
    if (active.data().count >= config.maxActiveHosted) {
      throw conflict(`You can host at most ${config.maxActiveHosted} upcoming activities`, { reason: 'host_limit' });
    }

    const ref = db.collection('activities').doc();
    const userRef = db.doc(`users/${user.uid}`);
    await db.runTransaction(async (tx) => {
      const u = await tx.get(userRef);
      const stats = u.data()?.stats ?? { hosted: 0, attended: 0 };
      tx.set(ref, {
        title: body.title,
        description: body.description,
        category: body.category,
        hostId: user.uid,
        hostDisplayName: user.profile.displayName,
        hostPhotoUrl: user.profile.photoUrl ?? null,
        city: body.city,
        venueName: body.venueName,
        latitude: body.latitude,
        longitude: body.longitude,
        geohash: encodeGeohash(body.latitude, body.longitude, 9),
        startAt: ts(startMs),
        endAt: ts(endMs),
        capacity: body.capacity,
        participantCount: 1,
        costType: body.costType,
        costDescription: body.costDescription,
        coverImageUrl: body.coverImageUrl,
        approvalRequired: body.approvalRequired,
        visibility: body.visibility,
        safetyNotes: body.safetyNotes,
        cancellationPolicy: body.cancellationPolicy,
        status: 'scheduled',
        createdAt: fv.serverTimestamp(),
        updatedAt: fv.serverTimestamp(),
      });
      tx.set(mRef(ref.id, user.uid), {
        userId: user.uid, role: 'host', status: 'approved',
        displayName: user.profile.displayName, photoUrl: user.profile.photoUrl ?? null,
        requestedAt: null, approvedAt: fv.serverTimestamp(), joinedAt: fv.serverTimestamp(), leftAt: null,
      });
      tx.update(userRef, { 'stats.hosted': (stats.hosted ?? 0) + 1 });
    });
    return view(await ref.get());
  }

  async function updateActivity(user, id, body) {
    const t = now();
    let notifyChange = false;
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(aRef(id));
      if (!snap.exists) throw notFound('Activity not found');
      const a = snap.data();
      if (a.hostId !== user.uid) throw forbidden('Only the host can edit this activity');
      if (a.status !== 'scheduled') throw conflict('Only scheduled activities can be edited');
      const upd = { ...body };
      if (body.startAt !== undefined || body.endAt !== undefined) {
        const startMs = body.startAt !== undefined ? Date.parse(body.startAt) : toMillis(a.startAt);
        const endMs = body.endAt !== undefined ? Date.parse(body.endAt) : toMillis(a.endAt);
        if (body.startAt !== undefined) validateTimes(startMs, endMs, t);
        else if (endMs <= startMs) throw invalid('Validation failed', [{ path: 'endAt', message: 'endAt must be after startAt' }]);
        else if (endMs - startMs > MAX_DURATION_MS) throw invalid('Validation failed', [{ path: 'endAt', message: 'Activity cannot last longer than 24 hours' }]);
        upd.startAt = ts(startMs);
        upd.endAt = ts(endMs);
        if (body.startAt !== undefined) upd.reminderSentAt = fv.delete();
      }
      if (body.capacity !== undefined && body.capacity < a.participantCount) {
        throw conflict('Capacity cannot be lower than the current number of participants', { participantCount: a.participantCount });
      }
      if (body.latitude !== undefined) upd.geohash = encodeGeohash(body.latitude, body.longitude, 9);
      // Lowering the bar (approval off) does not auto-approve pending requests; host approves explicitly.
      tx.update(aRef(id), { ...upd, updatedAt: fv.serverTimestamp() });
      notifyChange = body.startAt !== undefined || body.venueName !== undefined || body.latitude !== undefined;
    });
    const snap = await aRef(id).get();
    if (notifyChange) {
      const members = await db.collection(`activities/${id}/members`).where('status', '==', 'approved').get();
      await notifications.notifyMany(members.docs.map((m) => m.id).filter((u) => u !== user.uid), {
        type: 'activity_updated', title: 'Activity updated', body: `${snap.data().title} has new details`, data: { activityId: id, ...actorData(user.uid, user.profile) },
      });
    }
    return view(snap);
  }

  // ------------------------------------------------------------------ reads
  async function getActivity(user, id) {
    const { snap, isHost, membershipStatus } = await loadVisible(id, user.uid);
    return { ...view(snap), viewer: { membershipStatus: isHost ? 'approved' : membershipStatus, isHost } };
  }

  function makeMatcher(q, fromMs) {
    const needle = q.q?.toLowerCase();
    return (a) => {
      if (a.visibility !== 'public') return false;
      if (toMillis(a.startAt) < fromMs) return false;
      if (q.category && a.category !== q.category) return false;
      if (q.city && a.city !== q.city) return false;
      if (q.free && a.costType !== 'free') return false;
      if (q.minSpots && a.capacity - a.participantCount < q.minSpots) return false;
      if (needle && !`${a.title} ${a.description} ${a.venueName}`.toLowerCase().includes(needle)) return false;
      return true;
    };
  }

  const relevance = (a, q, nowMs) => {
    let s = 0;
    const n = q.q?.toLowerCase();
    if (n && a.title.toLowerCase().includes(n)) s += 5;
    if (n && a.description?.toLowerCase().includes(n)) s += 1;
    s += Math.min(2, (a.capacity - a.participantCount) / 5);
    s += Math.max(0, 3 - (toMillis(a.startAt) - nowMs) / (3 * 24 * 3600_000));
    return s;
  };

  async function listActivities(_user, q) {
    const nowMs = now();
    const fromMs = q.from ? Math.max(Date.parse(q.from), 0) : nowMs;
    const toMs = q.to ? Date.parse(q.to) : null;
    const matches = makeMatcher(q, fromMs);
    let result;
    let distances = {};
    if (q.lat !== undefined) {
      const sort = q.sort ?? 'proximity';
      result = await qs.queryNearby({
        lat: q.lat, lng: q.lng, radiusKm: q.radiusKm ?? 10, fromMs, toMs,
        sort: sort === 'proximity' ? 'proximity' : 'date', matches, limit: q.limit, cursor: q.cursor,
      });
      distances = result.distances;
    } else {
      result = await qs.queryByDate({ city: q.city, category: q.category, fromMs, toMs, matches, limit: q.limit, cursor: q.cursor });
    }
    let items = result.docs.map((d) => ({ ...view(d), ...(distances[d.id] !== undefined ? { distanceKm: distances[d.id] } : {}) }));
    if (q.sort === 'relevance') {
      const byId = new Map(result.docs.map((d) => [d.id, d.data()]));
      items = items.sort((x, y) => relevance(byId.get(y.id), q, nowMs) - relevance(byId.get(x.id), q, nowMs));
    }
    return { items, nextCursor: result.nextCursor };
  }

  async function mapMarkers(q) {
    const nowMs = now();
    const matches = makeMatcher({ category: q.category }, nowMs);
    const r = await qs.queryNearby({
      lat: q.lat, lng: q.lng, radiusKm: q.radiusKm, fromMs: nowMs, toMs: null, sort: 'proximity', matches, limit: q.limit,
    });
    return r.docs.map((d) => {
      const a = d.data();
      return {
        id: d.id, title: a.title, category: a.category, latitude: a.latitude, longitude: a.longitude,
        startAt: toJson(a.startAt), city: a.city, spotsLeft: a.capacity - a.participantCount, costType: a.costType,
        distanceKm: r.distances[d.id],
      };
    });
  }

  async function listMembers(user, id) {
    const { isHost, a, membershipStatus } = await loadVisible(id, user.uid);
    if (a.visibility === 'private' && !isHost && membershipStatus !== 'approved') {
      // Private plans hide attendees from anyone who is not host or an approved member.
      const h = await mRef(id, a.hostId).get();
      return h.exists ? [{ uid: h.id, ...toJson(h.data()) }] : [];
    }
    let q = db.collection(`activities/${id}/members`);
    if (!isHost) q = q.where('status', '==', 'approved');
    const snap = await q.limit(500).get();
    return snap.docs.map((d) => ({ uid: d.id, ...toJson(d.data()) }));
  }

  /**
   * GET /users/me/activities. Approved memberships via collectionGroup('members') (userId+status index),
   * activities loaded by id, then filtered/sorted in memory (bounded by MY_ACTIVITIES_SCAN) and paged by an
   * opaque offset cursor. `lastMessage` is one indexed query per ITEM ON THE PAGE only.
   *  hosted: I am host, scheduled and not ended; joined: I am a participant, scheduled and not ended;
   *  past: cancelled/completed or ended (any role). hosted/joined sort by startAt asc, past by startAt desc.
   */
  async function listMyActivities(user, { role, limit, cursor }) {
    const c = decodeCursor(cursor);
    if (c === undefined || (c && !(Number.isInteger(c.o) && c.o >= 0))) throw invalid('Invalid cursor');
    const offset = c?.o ?? 0;
    const nowMs = now();
    const ms = await db.collectionGroup('members')
      .where('userId', '==', user.uid).where('status', '==', 'approved').limit(MY_ACTIVITIES_SCAN).get();
    const loaded = await Promise.all(ms.docs.map(async (m) => {
      const aSnap = await m.ref.parent.parent.get();
      return aSnap.exists ? { aSnap, memberRole: m.data().role } : null;
    }));
    const rows = loaded.filter(Boolean).filter(({ aSnap, memberRole }) => {
      const a = aSnap.data();
      const ended = a.status !== 'scheduled' || toMillis(a.endAt) < nowMs;
      if (role === 'past') return ended;
      if (ended) return false;
      return role === 'hosted' ? memberRole === 'host' : memberRole !== 'host';
    });
    const start = (r) => toMillis(r.aSnap.data().startAt);
    rows.sort((x, y) => (role === 'past' ? start(y) - start(x) : start(x) - start(y)) || (x.aSnap.id < y.aSnap.id ? -1 : 1));
    const page = rows.slice(offset, offset + limit);
    const items = await Promise.all(page.map(async ({ aSnap, memberRole }) => {
      const last = await db.collection(`activities/${aSnap.id}/messages`)
        .where('moderationStatus', '==', 'visible').orderBy('createdAt', 'desc').limit(1).get();
      const prev = await db.collection(`activities/${aSnap.id}/members`).where('status', '==', 'approved').limit(3).get();
      const item = {
        ...view(aSnap),
        participants: prev.docs.map((d) => ({ uid: d.id, displayName: d.data().displayName, photoUrl: d.data().photoUrl ?? null })),
        viewer: { membershipStatus: 'approved', isHost: memberRole === 'host', role: memberRole },
      };
      if (!last.empty) {
        const m = last.docs[0].data();
        item.lastMessage = { text: m.text, createdAt: toJson(m.createdAt), senderName: m.senderName, senderId: m.senderId };
      }
      return item;
    }));
    const next = offset + limit < rows.length ? encodeCursor({ o: offset + limit }) : null;
    return { items, nextCursor: next };
  }

  // ------------------------------------------------------------------ membership transitions
  async function joinActivity(user, id) {
    const t = now();
    const outcome = await db.runTransaction(async (tx) => {
      const [aSnap, mSnap] = await Promise.all([tx.get(aRef(id)), tx.get(mRef(id, user.uid))]);
      if (!aSnap.exists) throw notFound('Activity not found');
      const a = aSnap.data();
      if (a.status !== 'scheduled') throw conflict('Activity is not open for joining', { reason: 'not_scheduled' });
      if (toMillis(a.endAt) <= t) throw conflict('Activity has already ended', { reason: 'ended' });
      if (a.hostId === user.uid) throw conflict('You are the host of this activity', { reason: 'is_host' });
      const prev = mSnap.exists ? mSnap.data().status : null;
      if (prev === 'approved' || prev === 'requested') throw conflict('You have already joined or requested this activity', { reason: 'already_joined', status: prev });
      if (prev === 'rejected') throw conflict('Your request was declined by the host', { reason: 'rejected' });
      if (prev === 'removed') throw forbidden('You were removed from this activity', { reason: 'removed' });

      const needsApproval = a.approvalRequired || a.visibility === 'private';
      const base = {
        userId: user.uid, role: 'participant',
        displayName: user.profile.displayName, photoUrl: user.profile.photoUrl ?? null,
        requestedAt: fv.serverTimestamp(), approvedAt: null, joinedAt: null, leftAt: null,
      };
      if (needsApproval) {
        tx.set(mRef(id, user.uid), { ...base, status: 'requested' });
        return { status: 'requested', hostId: a.hostId, title: a.title };
      }
      if (a.participantCount >= a.capacity) throw conflict('Activity is full', { reason: 'full' });
      tx.set(mRef(id, user.uid), { ...base, status: 'approved', approvedAt: fv.serverTimestamp(), joinedAt: fv.serverTimestamp() });
      tx.update(aRef(id), { participantCount: a.participantCount + 1, updatedAt: fv.serverTimestamp() });
      return { status: 'approved', hostId: a.hostId, title: a.title };
    });

    await notifications.notify(outcome.hostId, outcome.status === 'requested'
      ? { type: 'join_request', title: 'New join request', body: `${user.profile.displayName} wants to join ${outcome.title}`, data: { activityId: id, userId: user.uid, ...actorData(user.uid, user.profile) } }
      : { type: 'participant_joined', title: 'New participant', body: `${user.profile.displayName} joined ${outcome.title}`, data: { activityId: id, userId: user.uid, ...actorData(user.uid, user.profile) } });
    return { status: outcome.status };
  }

  /** Shared host-guarded member transition. `fn(a, m)` returns the member/activity updates. */
  async function hostTransition({ id, hostUid, targetUid, system, fn }) {
    return db.runTransaction(async (tx) => {
      const [aSnap, mSnap] = await Promise.all([tx.get(aRef(id)), tx.get(mRef(id, targetUid))]);
      if (!aSnap.exists) throw notFound('Activity not found');
      const a = aSnap.data();
      if (!system && a.hostId !== hostUid) throw forbidden('Only the host can do this');
      if (a.status !== 'scheduled') throw conflict('Activity is not scheduled', { reason: 'not_scheduled' });
      if (!mSnap.exists) throw notFound('Member not found');
      if (mSnap.data().role === 'host') throw conflict('The host cannot be changed this way');
      const { member, countDelta = 0 } = fn(a, mSnap.data());
      tx.update(mRef(id, targetUid), member);
      if (countDelta) tx.update(aRef(id), { participantCount: a.participantCount + countDelta, updatedAt: fv.serverTimestamp() });
      return { title: a.title };
    });
  }

  async function approve(user, id, uid) {
    const r = await hostTransition({
      id, hostUid: user.uid, targetUid: uid,
      fn: (a, m) => {
        if (m.status !== 'requested') throw conflict('No pending request for this user', { status: m.status });
        if (a.participantCount >= a.capacity) throw conflict('Activity is full', { reason: 'full' });
        return { member: { status: 'approved', approvedAt: fv.serverTimestamp(), joinedAt: fv.serverTimestamp() }, countDelta: 1 };
      },
    });
    await notifications.notify(uid, { type: 'join_approved', title: "You're in!", body: `You were approved for ${r.title}`, data: { activityId: id, ...actorData(user.uid, user.profile) } });
    return { status: 'approved' };
  }

  async function reject(user, id, uid) {
    const r = await hostTransition({
      id, hostUid: user.uid, targetUid: uid,
      fn: (_a, m) => {
        if (m.status !== 'requested') throw conflict('No pending request for this user', { status: m.status });
        return { member: { status: 'rejected' } };
      },
    });
    await notifications.notify(uid, { type: 'join_rejected', title: 'Request declined', body: `Your request for ${r.title} was declined`, data: { activityId: id, ...actorData(user.uid, user.profile) } });
    return { status: 'rejected' };
  }

  async function removeMember(user, id, uid) {
    if (uid === user.uid) throw invalid('You cannot remove yourself');
    const r = await hostTransition({
      id, hostUid: user.uid, targetUid: uid,
      fn: (_a, m) => {
        if (m.status !== 'approved') throw conflict('User is not an approved participant', { status: m.status });
        return { member: { status: 'removed', leftAt: fv.serverTimestamp() }, countDelta: -1 };
      },
    });
    await notifications.notify(uid, { type: 'removed', title: 'Removed from activity', body: `You were removed from ${r.title}`, data: { activityId: id, ...actorData(user.uid, user.profile) } });
    return { status: 'removed' };
  }

  async function leaveActivity({ activityId: id, uid, silent = false }) {
    const out = await db.runTransaction(async (tx) => {
      const [aSnap, mSnap] = await Promise.all([tx.get(aRef(id)), tx.get(mRef(id, uid))]);
      if (!aSnap.exists) throw notFound('Activity not found');
      if (!mSnap.exists || !['approved', 'requested'].includes(mSnap.data().status)) throw conflict('You are not part of this activity');
      if (mSnap.data().role === 'host') throw conflict('Hosts must cancel the activity instead of leaving');
      const a = aSnap.data();
      if (a.status !== 'scheduled') throw conflict('Activity is not scheduled', { reason: 'not_scheduled' });
      const wasApproved = mSnap.data().status === 'approved';
      tx.update(mRef(id, uid), { status: 'left', leftAt: fv.serverTimestamp() });
      if (wasApproved) tx.update(aRef(id), { participantCount: a.participantCount - 1, updatedAt: fv.serverTimestamp() });
      return { hostId: a.hostId, title: a.title, name: mSnap.data().displayName, photo: mSnap.data().photoUrl ?? null, wasApproved };
    });
    if (out.wasApproved && !silent) {
      await notifications.notify(out.hostId, { type: 'participant_left', title: 'Participant left', body: `${out.name} left ${out.title}`, data: { activityId: id, userId: uid, ...actorData(uid, { displayName: out.name, photoUrl: out.photo }) } });
    }
    return { status: 'left' };
  }

  /** Host (or staff/system) cancels; participants and pending requesters are notified. */
  async function cancelActivity({ activityId: id, actor, system = false }) {
    const title = await db.runTransaction(async (tx) => {
      const snap = await tx.get(aRef(id));
      if (!snap.exists) throw notFound('Activity not found');
      const a = snap.data();
      if (!system && a.hostId !== actor.uid) throw forbidden('Only the host can cancel this activity');
      if (a.status !== 'scheduled') throw conflict('Activity is not scheduled', { reason: 'not_scheduled' });
      tx.update(aRef(id), { status: 'cancelled', updatedAt: fv.serverTimestamp() });
      return a.title;
    });
    const members = await db.collection(`activities/${id}/members`).where('status', 'in', ['approved', 'requested']).get();
    await notifications.notifyMany(members.docs.map((m) => m.id).filter((u) => u !== actor.uid), {
      type: 'activity_cancelled', title: 'Activity cancelled', body: `${title} was cancelled`, data: { activityId: id, ...actorData(actor.uid, actor.profile) },
    });
    return { status: 'cancelled' };
  }

  return {
    createActivity, updateActivity, getActivity, listActivities, mapMarkers, listMembers, listMyActivities,
    joinActivity, approve, reject, removeMember, leaveActivity, cancelActivity, memberStatus,
  };
}
