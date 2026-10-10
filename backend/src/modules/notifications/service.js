import { ts } from '../../lib/time.js';

const PREF_FOR_TYPE = {
  join_request: 'joinRequests',
  join_approved: 'approvals',
  join_rejected: 'approvals',
  removed: 'approvals',
  participant_joined: 'activityUpdates',
  participant_left: 'activityUpdates',
  activity_cancelled: 'activityUpdates',
  activity_updated: 'activityUpdates',
  reminder: 'reminders',
  moderation: 'moderation',
  friend_request: 'friends',
  friend_accepted: 'friends',
};

/** Actor fields attached to notification `data` so clients can render an avatar and "X wants to ...". */
export const actorData = (uid, profile) => (profile
  ? { actorId: uid, actorName: profile.displayName ?? '', actorPhotoUrl: profile.photoUrl ?? null }
  : {});

const BAD_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);

/**
 * In-app notification (Firestore doc, read by the owner) + FCM push. Every call is best-effort:
 * a notification failure must never fail the business operation, so errors are logged and swallowed.
 * Notification bodies never contain chat message text.
 */
export function createNotificationService({ db, messaging, fv, now, logger, config }) {
  async function notify(userId, { type, title, body, data = {} }) {
    try {
      const priv = await db.doc(`users/${userId}/private/profile`).get();
      const prefKey = PREF_FOR_TYPE[type];
      if (prefKey && priv.data()?.notificationPrefs?.[prefKey] === false) return { skipped: true };

      await db.collection('notifications').add({
        userId, type, title, body, data, read: false, createdAt: fv.serverTimestamp(),
      });

      const tokenSnap = await db.collection('deviceTokens').where('uid', '==', userId).get();
      const tokens = tokenSnap.docs.map((d) => d.data().token).filter(Boolean);
      if (!tokens.length || !messaging) return { sent: 0 };
      const strData = Object.fromEntries(Object.entries({ type, ...data }).filter(([, v]) => v !== null && v !== undefined).map(([k, v]) => [k, String(v)]));
      let sent = 0;
      for (let i = 0; i < tokens.length; i += 500) {
        const chunk = tokens.slice(i, i + 500);
        const res = await messaging.sendEachForMulticast({ tokens: chunk, notification: { title, body }, data: strData });
        sent += res.successCount;
        await Promise.all(
          res.responses.map((r, idx) =>
            !r.success && BAD_TOKEN_CODES.has(r.error?.code)
              ? tokenSnap.docs.find((d) => d.data().token === chunk[idx])?.ref.delete()
              : null,
          ),
        );
      }
      return { sent };
    } catch (err) {
      logger.warn({ userId, type, err: { name: err?.name, code: err?.code } }, 'notification failed');
      return { error: true };
    }
  }

  async function notifyMany(userIds, payload) {
    const ids = [...new Set(userIds)];
    await Promise.all(ids.map((id) => notify(id, payload)));
  }

  /** Reminders for scheduled activities starting within REMINDER_LEAD_MINUTES; idempotent via reminderSentAt. */
  async function sendReminders() {
    const t = now();
    const snap = await db
      .collection('activities')
      .where('status', '==', 'scheduled')
      .where('startAt', '>=', ts(t))
      .where('startAt', '<=', ts(t + config.reminderLeadMinutes * 60_000))
      .orderBy('startAt')
      .limit(200)
      .get();
    let activities = 0;
    for (const doc of snap.docs) {
      const a = doc.data();
      if (a.reminderSentAt) continue;
      const claimed = await db.runTransaction(async (tx) => {
        const cur = await tx.get(doc.ref);
        if (!cur.exists || cur.data().reminderSentAt || cur.data().status !== 'scheduled') return false;
        tx.update(doc.ref, { reminderSentAt: fv.serverTimestamp() });
        return true;
      });
      if (!claimed) continue;
      const members = await db.collection(`activities/${doc.id}/members`).where('status', '==', 'approved').get();
      await notifyMany(members.docs.map((m) => m.id), {
        type: 'reminder',
        title: 'Starting soon',
        body: `${a.title} starts soon at ${a.venueName}`,
        data: { activityId: doc.id },
      });
      activities++;
    }
    return { activitiesReminded: activities };
  }

  /** Marks ended scheduled activities as completed (read-only chat retention starts from updatedAt). */
  async function completeEnded() {
    const snap = await db
      .collection('activities')
      .where('status', '==', 'scheduled')
      .where('endAt', '<', ts(now()))
      .limit(200)
      .get();
    let completed = 0;
    for (const doc of snap.docs) {
      const ok = await db.runTransaction(async (tx) => {
        const cur = await tx.get(doc.ref);
        if (!cur.exists || cur.data().status !== 'scheduled') return false;
        tx.update(doc.ref, { status: 'completed', updatedAt: fv.serverTimestamp() });
        return true;
      });
      if (ok) completed++;
    }
    return { completed };
  }

  return { notify, notifyMany, sendReminders, completeEnded };
}
