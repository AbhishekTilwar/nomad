import { conflict, forbidden, invalid, notFound } from '../../lib/errors.js';
import { sha256 } from '../../lib/text.js';

export function createSafetyService({ db, fv }) {
  /** Resolves the report target to { targetUserId, context } or throws. Text snapshot is server-captured. */
  async function resolveTarget(user, { targetType, targetId, context }) {
    if (targetType === 'user') {
      if (targetId === user.uid) throw invalid('You cannot report yourself');
      const u = await db.doc(`users/${targetId}`).get();
      if (!u.exists) throw notFound('Report target not found');
      return { targetUserId: targetId, context: {} };
    }
    if (targetType === 'activity') {
      const a = await db.doc(`activities/${targetId}`).get();
      if (!a.exists) throw notFound('Report target not found');
      if (a.data().hostId === user.uid) throw invalid('You cannot report your own activity');
      return { targetUserId: a.data().hostId, context: { activityId: targetId } };
    }
    // message
    const roomType = context?.roomType;
    if (!roomType) throw invalid('context.roomType is required for message reports');
    let path;
    if (roomType === 'community') {
      path = `communityRooms/global/messages/${targetId}`;
    } else {
      const activityId = context.activityId;
      if (!activityId) throw invalid('context.activityId is required for activity messages');
      const m = await db.doc(`activities/${activityId}/members/${user.uid}`).get();
      if (!m.exists || m.data().status !== 'approved') throw forbidden('Only participants can report messages in this chat');
      path = `activities/${activityId}/messages/${targetId}`;
    }
    const msg = await db.doc(path).get();
    if (!msg.exists) throw notFound('Report target not found');
    if (msg.data().senderId === user.uid) throw invalid('You cannot report your own message');
    return {
      targetUserId: msg.data().senderId,
      context: { roomType, ...(roomType === 'activity' ? { activityId: context.activityId } : {}), messageId: targetId, textSnapshot: String(msg.data().text ?? '').slice(0, 500) },
    };
  }

  async function createReport(user, body) {
    const { targetUserId, context } = await resolveTarget(user, body);
    // Deterministic id => one report per reporter+target, enforced transactionally.
    const id = sha256(`${user.uid}|${body.targetType}|${body.targetId}`).slice(0, 40);
    const ref = db.doc(`reports/${id}`);
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (snap.exists) throw conflict('You have already reported this', { reason: 'already_reported' });
      tx.set(ref, {
        reporterId: user.uid, targetType: body.targetType, targetId: body.targetId, targetUserId,
        context, reason: body.reason, details: body.details ?? '', status: 'open',
        createdAt: fv.serverTimestamp(), reviewedBy: null, reviewedAt: null,
      });
    });
    return { id, status: 'open' };
  }

  return { createReport };
}
