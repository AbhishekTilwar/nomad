import { conflict, forbidden, invalid, notFound, rateLimited, restricted } from '../../lib/errors.js';
import { encodeCursor, decodeCursor } from '../../lib/pagination.js';
import { parse } from '../../lib/http.js';
import { toJson } from '../../lib/serialize.js';
import { containsLink, dupKey } from '../../lib/text.js';
import { toMillis, ts } from '../../lib/time.js';
import { cleanMessageText, messageBodySchema } from './schemas.js';

const RETENTION_MS = 30 * 24 * 3600_000;
const ROOM_TOUCH_INTERVAL_MS = 30_000;

/**
 * Chat write path for both the community room and activity chats. Every accepted or rejected-as-
 * violation message goes through ONE Firestore transaction on userRateLimits/{uid}, so concurrent
 * requests from the same user cannot exceed the limit (the loser of a write conflict is retried
 * against fresh state). Message text is stored but never logged.
 */
export function createChatService({ db, fv, now, config, users, logger }) {
  const cfg = config.community;
  const schema = messageBodySchema(cfg.maxLength);
  let lastRoomTouch = 0;
  let roomActiveCache = { at: 0, value: true };

  /** Kill switch: communityRooms/global.isActive=false stops posting. Cached 30 s per instance (1 read). */
  async function communityRoomActive() {
    const t = now();
    if (t - roomActiveCache.at < ROOM_TOUCH_INTERVAL_MS) return roomActiveCache.value;
    const snap = await db.doc('communityRooms/global').get();
    roomActiveCache = { at: t, value: !snap.exists || snap.data().isActive !== false };
    return roomActiveCache.value;
  }

  const parseMessageBody = (body) => {
    const b = parse(schema, body);
    return { text: cleanMessageText(b.text, cfg.maxLength), clientMessageId: b.clientMessageId };
  };

  const msgView = (snap) => {
    const d = snap.data();
    return {
      id: snap.id, senderId: d.senderId, senderName: d.senderName, senderPhotoUrl: d.senderPhotoUrl ?? null,
      text: d.text, createdAt: toJson(d.createdAt), moderationStatus: d.moderationStatus,
    };
  };

  /** Core write. `room` = { type: 'community' } | { type: 'activity', activityId }. */
  async function submit(user, room, { text, clientMessageId }) {
    const { uid } = user;
    if (room.type === 'community' && !(await communityRoomActive())) {
      throw conflict('The community room is temporarily closed', { reason: 'room_closed' });
    }
    const colPath = room.type === 'community' ? 'communityRooms/global/messages' : `activities/${room.activityId}/messages`;
    const msgId = clientMessageId ? `${uid}_${clientMessageId}` : db.collection(colPath).doc().id;
    const msgRef = db.doc(`${colPath}/${msgId}`);
    const rlRef = db.doc(`userRateLimits/${uid}`);
    const privRef = db.doc(`users/${uid}/private/profile`);
    const textKey = dupKey(text);

    const outcome = await db.runTransaction(async (tx) => {
      const t = now();
      const reads = [tx.get(privRef), tx.get(rlRef), tx.get(msgRef)];
      if (room.type === 'activity') {
        reads.push(tx.get(db.doc(`activities/${room.activityId}`)), tx.get(db.doc(`activities/${room.activityId}/members/${uid}`)));
      }
      const [priv, rl, existing, aSnap, mSnap] = await Promise.all(reads);

      // --- account state
      const status = user.accountStatus;
      if (status === 'suspended' || status === 'deleted') return { error: restricted('Your account is not active', { accountStatus: status }) };
      const mutedUntilMs = toMillis(priv.data()?.mutedUntil);
      if ((mutedUntilMs && mutedUntilMs > t) || (status === 'muted' && !mutedUntilMs)) {
        return { error: restricted('You are muted and cannot post', { accountStatus: 'muted', mutedUntil: mutedUntilMs ? new Date(mutedUntilMs).toISOString() : null }) };
      }

      // --- room access
      if (room.type === 'activity') {
        if (!aSnap.exists) return { error: notFound('Activity not found') };
        if (!mSnap.exists || mSnap.data().status !== 'approved') return { error: forbidden('Only approved participants can use this chat', { reason: 'not_a_member' }) };
        if (aSnap.data().status !== 'scheduled') return { error: conflict('This activity chat is read-only', { reason: 'read_only' }) };
      }

      // --- idempotent retry of the same clientMessageId: return the stored message, count nothing
      if (existing.exists) return { duplicate: true, message: msgView(existing) };

      // --- rate limiting
      const st = rl.exists ? rl.data() : {};
      const isNew = user.createdAtMs == null || t - user.createdAtMs < cfg.newAccountAgeHours * 3600_000;
      const limit = isNew ? cfg.newAccountMsgLimit : cfg.establishedMsgLimit;
      const windowMs = cfg.windowMinutes * 60_000;
      const cooldownMs = toMillis(st.cooldownUntil);
      if (cooldownMs && cooldownMs > t) {
        return { error: rateLimited('You are temporarily rate limited', { reason: 'cooldown', retryAfterSeconds: Math.ceil((cooldownMs - t) / 1000) }) };
      }
      let windowStart = toMillis(st.windowStart);
      let count = st.count ?? 0;
      if (windowStart == null || t - windowStart >= windowMs) { windowStart = t; count = 0; }

      const violate = (err) => {
        let violations = st.violations ?? 0;
        const lastV = toMillis(st.lastViolationAt);
        if (lastV && t - lastV > cfg.violationDecayHours * 3600_000) violations = 0;
        violations += 1;
        let cooldownUntil = cooldownMs ? ts(cooldownMs) : null;
        if (violations % cfg.violationThreshold === 0) {
          const level = violations / cfg.violationThreshold;
          const mins = Math.min(cfg.violationCooldownMinutes * 2 ** (level - 1), cfg.violationMaxCooldownMinutes);
          cooldownUntil = ts(t + mins * 60_000);
          err.details = { ...(err.details ?? {}), cooldownMinutes: mins };
        }
        tx.set(rlRef, {
          windowStart: ts(windowStart), count, lastTextHash: st.lastTextHash ?? null, lastMessageAt: st.lastMessageAt ?? null,
          cooldownUntil, violations, lastViolationAt: ts(t),
        });
        if (priv.exists) tx.update(privRef, { violationCount: (priv.data().violationCount ?? 0) + 1 });
        return { error: err };
      };

      const lastAt = toMillis(st.lastMessageAt);
      if (st.lastTextHash === textKey && lastAt && t - lastAt < cfg.duplicateWindowSeconds * 1000) {
        return violate(rateLimited('Please do not repeat the same message', { reason: 'duplicate_message', retryAfterSeconds: Math.ceil((cfg.duplicateWindowSeconds * 1000 - (t - lastAt)) / 1000) }));
      }
      if (isNew && cfg.newAccountBlockLinks && containsLink(text)) {
        return violate(invalid('New accounts cannot post links yet', [{ path: 'text', message: 'Links are not allowed for new accounts' }]));
      }
      if (count >= limit) {
        return violate(rateLimited('You are sending messages too quickly', { reason: 'rate_limit', retryAfterSeconds: Math.max(1, Math.ceil((windowStart + windowMs - t) / 1000)) }));
      }

      // --- accept
      tx.set(msgRef, {
        senderId: uid, senderName: user.profile.displayName, senderPhotoUrl: user.profile.photoUrl ?? null,
        text, createdAt: fv.serverTimestamp(), moderationStatus: 'visible',
      });
      tx.set(rlRef, {
        windowStart: ts(windowStart), count: count + 1, lastTextHash: textKey, lastMessageAt: ts(t),
        cooldownUntil: cooldownMs ? ts(cooldownMs) : null, violations: st.violations ?? 0, lastViolationAt: st.lastViolationAt ?? null,
      });
      return { accepted: true, id: msgId };
    });

    if (outcome.error) throw outcome.error;
    if (outcome.duplicate) return { message: outcome.message, duplicate: true };
    if (room.type === 'community') touchRoom();
    return { message: msgView(await msgRef.get()), duplicate: false };
  }

  /** Best-effort, throttled per instance: avoids a hot-document write on every message. */
  function touchRoom() {
    const t = now();
    if (t - lastRoomTouch < ROOM_TOUCH_INTERVAL_MS) return;
    lastRoomTouch = t;
    db.doc('communityRooms/global').set({ lastMessageAt: fv.serverTimestamp() }, { merge: true })
      .catch((err) => logger.warn({ err: { message: err?.message } }, 'room touch failed'));
  }

  const postCommunityMessage = (user, parsed) => submit(user, { type: 'community' }, parsed);
  const postActivityMessage = (user, activityId, parsed) => submit(user, { type: 'activity', activityId }, parsed);

  async function listActivityMessages(user, activityId, { limit, cursor }) {
    const [aSnap, mSnap] = await Promise.all([
      db.doc(`activities/${activityId}`).get(),
      db.doc(`activities/${activityId}/members/${user.uid}`).get(),
    ]);
    if (!aSnap.exists) throw notFound('Activity not found');
    if (!mSnap.exists || mSnap.data().status !== 'approved') throw forbidden('Only approved participants can read this chat', { reason: 'not_a_member' });
    const a = aSnap.data();
    if (a.status !== 'scheduled' && now() > toMillis(a.updatedAt) + RETENTION_MS) throw forbidden('This chat has been archived', { reason: 'archived' });

    let q = db.collection(`activities/${activityId}/messages`).where('moderationStatus', '==', 'visible').orderBy('createdAt', 'desc');
    const c = decodeCursor(cursor);
    if (cursor) {
      const cur = c?.id ? await db.doc(`activities/${activityId}/messages/${c.id}`).get() : null;
      if (!cur?.exists) throw invalid('Invalid cursor');
      q = q.startAfter(cur);
    }
    const snap = await q.limit(limit + 1).get();
    const hasMore = snap.size > limit;
    const docs = snap.docs.slice(0, limit);
    const blocked = await users.blockedIds(user.uid);
    return {
      items: docs.filter((d) => !blocked.has(d.data().senderId)).map(msgView),
      nextCursor: hasMore ? encodeCursor({ id: docs[docs.length - 1].id }) : null,
    };
  }

  async function communityRoom(user) {
    const ref = db.doc('communityRooms/global');
    let snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        name: 'Mingle Community', description: 'Say hi to fellow nomads in Mumbai and Pune. Be kind and keep it safe.',
        isActive: true, createdAt: fv.serverTimestamp(), lastMessageAt: null,
      }, { merge: true });
      snap = await ref.get();
    }
    const t = now();
    const [priv, rl] = await Promise.all([db.doc(`users/${user.uid}/private/profile`).get(), db.doc(`userRateLimits/${user.uid}`).get()]);
    const mutedUntilMs = toMillis(priv.data()?.mutedUntil);
    const muted = (mutedUntilMs && mutedUntilMs > t) || (user.accountStatus === 'muted' && !mutedUntilMs);
    const isNew = user.createdAtMs == null || t - user.createdAtMs < cfg.newAccountAgeHours * 3600_000;
    const cooldownMs = toMillis(rl.data()?.cooldownUntil);
    const inCooldown = Boolean(cooldownMs && cooldownMs > t);
    return {
      room: { id: 'global', ...toJson(snap.data()) },
      viewer: {
        accountStatus: user.accountStatus,
        canPost: !muted && !inCooldown && snap.data().isActive !== false,
        muted: Boolean(muted),
        mutedUntil: mutedUntilMs ? new Date(mutedUntilMs).toISOString() : null,
        cooldownUntil: inCooldown ? new Date(cooldownMs).toISOString() : null,
        isNewAccount: isNew,
        limits: {
          messagesPerWindow: isNew ? cfg.newAccountMsgLimit : cfg.establishedMsgLimit,
          windowMinutes: cfg.windowMinutes,
          maxLength: cfg.maxLength,
          linksAllowed: !(isNew && cfg.newAccountBlockLinks),
        },
      },
    };
  }

  return { parseMessageBody, postCommunityMessage, postActivityMessage, listActivityMessages, communityRoom };
}
