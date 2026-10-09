import { conflict, forbidden, invalid, notFound } from '../../lib/errors.js';
import { encodeCursor, decodeCursor } from '../../lib/pagination.js';
import { toJson } from '../../lib/serialize.js';
import { ts } from '../../lib/time.js';

/** Moderation. Every state change commits together with an append-only moderationActions entry. */
export function createAdminService({ db, auth, fv, now, notifications, activities, logger }) {
  const audit = (tx, staff, action, targetType, targetId, reason, reportId) => {
    tx.set(db.collection('moderationActions').doc(), {
      actorId: staff.uid, action, targetType, targetId, reportId: reportId ?? null, reason, createdAt: fv.serverTimestamp(),
    });
  };

  async function listReports({ status, limit, cursor }) {
    let q = db.collection('reports').where('status', '==', status).orderBy('createdAt', 'desc');
    if (cursor) {
      const c = decodeCursor(cursor);
      const cur = c?.id ? await db.doc(`reports/${c.id}`).get() : null;
      if (!cur?.exists) throw invalid('Invalid cursor');
      q = q.startAfter(cur);
    }
    const snap = await q.limit(limit + 1).get();
    const docs = snap.docs.slice(0, limit);
    return {
      items: docs.map((d) => ({ id: d.id, ...toJson(d.data()) })),
      nextCursor: snap.size > limit ? encodeCursor({ id: docs[docs.length - 1].id }) : null,
    };
  }

  const closeReport = async (tx, reportRef, staff, status) => {
    tx.update(reportRef, { status, reviewedBy: staff.uid, reviewedAt: fv.serverTimestamp() });
  };

  async function dismissReport(staff, id, reason) {
    await db.runTransaction(async (tx) => {
      const ref = db.doc(`reports/${id}`);
      const snap = await tx.get(ref);
      if (!snap.exists) throw notFound('Report not found');
      if (snap.data().status !== 'open') throw conflict('Report already reviewed');
      await closeReport(tx, ref, staff, 'dismissed');
      audit(tx, staff, 'dismiss_report', 'report', id, reason, id);
    });
    return { status: 'dismissed' };
  }

  /** room: 'community' or an activity id. */
  async function moderateMessage(staff, room, id, action, { reason, reportId }) {
    const path = room === 'community' ? `communityRooms/global/messages/${id}` : `activities/${room}/messages/${id}`;
    const ref = db.doc(path);
    const newStatus = action === 'hide' ? 'hidden' : 'removed';
    const senderId = await db.runTransaction(async (tx) => {
      const reads = [tx.get(ref)];
      if (reportId) reads.push(tx.get(db.doc(`reports/${reportId}`)));
      const [msg, rep] = await Promise.all(reads);
      if (!msg.exists) throw notFound('Message not found');
      if (reportId && !rep.exists) throw notFound('Report not found');
      tx.update(ref, { moderationStatus: newStatus, moderatedBy: staff.uid, moderatedAt: fv.serverTimestamp() });
      if (reportId && rep.data().status === 'open') await closeReport(tx, db.doc(`reports/${reportId}`), staff, 'actioned');
      audit(tx, staff, `${action}_message`, 'message', id, reason, reportId);
      return msg.data().senderId;
    });
    await notifications.notify(senderId, {
      type: 'moderation', title: 'Message moderated', body: 'One of your messages was removed for breaking community guidelines.', data: { room },
    });
    return { moderationStatus: newStatus };
  }

  async function changeUser(staff, uid, action, { reason, reportId, durationHours }) {
    if (uid === staff.uid) throw forbidden('You cannot moderate yourself');
    const result = await db.runTransaction(async (tx) => {
      const pubRef = db.doc(`users/${uid}`);
      const privRef = db.doc(`users/${uid}/private/profile`);
      const repRef = reportId ? db.doc(`reports/${reportId}`) : null;
      const [pub, priv, rep] = await Promise.all([tx.get(pubRef), tx.get(privRef), repRef ? tx.get(repRef) : null]);
      if (!pub.exists) throw notFound('User not found');
      const targetRole = priv.data()?.role ?? 'user';
      if (targetRole !== 'user' && staff.role !== 'admin') throw forbidden('Only admins can moderate staff accounts');
      if (pub.data().accountStatus === 'deleted') throw conflict('Account is deleted');
      const upd = { updatedAt: fv.serverTimestamp() };
      let mutedUntil = null;
      if (action === 'suspend') upd.accountStatus = 'suspended';
      if (action === 'mute') { upd.accountStatus = 'muted'; mutedUntil = ts(now() + durationHours * 3600_000); }
      if (action === 'reinstate') upd.accountStatus = 'active';
      tx.update(pubRef, upd);
      if (priv.exists) tx.update(privRef, { mutedUntil });
      else tx.set(privRef, { mutedUntil, role: 'user', violationCount: 0 }, { merge: true });
      if (rep?.exists && rep.data().status === 'open') await closeReport(tx, repRef, staff, 'actioned');
      audit(tx, staff, action, 'user', uid, reason, reportId);
      return { accountStatus: upd.accountStatus, mutedUntil: mutedUntil ? mutedUntil.toDate().toISOString() : null };
    });
    if (action === 'suspend') {
      try { await auth.revokeRefreshTokens(uid); } catch (err) { logger.warn({ err: { message: err?.message } }, 'revoke tokens failed'); }
    }
    if (action === 'mute') {
      await notifications.notify(uid, { type: 'moderation', title: 'You have been muted', body: 'You cannot post in chats for a while.', data: {} });
    }
    return result;
  }

  async function cancelActivity(staff, id, reason) {
    const out = await activities.cancelActivity({ activityId: id, actor: { uid: staff.uid }, system: true });
    await db.runTransaction(async (tx) => audit(tx, staff, 'cancel_activity', 'activity', id, reason));
    return out;
  }

  async function metrics() {
    const c = async (q) => (await q.count().get()).data().count;
    const [users, scheduledActivities, openReports, suspendedUsers] = await Promise.all([
      c(db.collection('users')),
      c(db.collection('activities').where('status', '==', 'scheduled')),
      c(db.collection('reports').where('status', '==', 'open')),
      c(db.collection('users').where('accountStatus', '==', 'suspended')),
    ]);
    return { users, scheduledActivities, openReports, suspendedUsers, generatedAt: new Date(now()).toISOString() };
  }

  return { listReports, dismissReport, moderateMessage, changeUser, cancelActivity, metrics };
}
