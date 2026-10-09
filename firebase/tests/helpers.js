import { readFileSync } from 'node:fs';
import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { Timestamp, setLogLevel } from 'firebase/firestore';

setLogLevel('silent'); // PERMISSION_DENIED stream noise is expected in negative tests


export const PROJECT = 'demo-nomadmingle';
const ts = (ms) => Timestamp.fromMillis(ms);

export async function makeEnv() {
  return initializeTestEnvironment({
    projectId: PROJECT,
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
    storage: { rules: readFileSync(new URL('../storage.rules', import.meta.url), 'utf8') },
  });
}

const profile = (name, status = 'active') => ({
  displayName: name, photoUrl: null, bio: '', city: 'mumbai', interests: [], ageRange: '25-34', accountStatus: status,
  profileCompleted: true, emailVerified: true, stats: { hosted: 0, attended: 0 }, createdAt: ts(1), updatedAt: ts(1),
});
const member = (uid, status, role = 'participant') => ({
  userId: uid, role, status, displayName: uid, photoUrl: null, requestedAt: ts(1), approvedAt: null, joinedAt: null, leftAt: null,
});
const activity = (over = {}) => ({
  title: 'Run', hostId: 'alice', visibility: 'public', status: 'scheduled', city: 'mumbai', category: 'fitness',
  startAt: ts(Date.now() + 86_400_000), updatedAt: ts(Date.now()), participantCount: 2, capacity: 5, ...over,
});
const msg = (sender, status = 'visible') => ({ senderId: sender, senderName: sender, senderPhotoUrl: null, text: 'hello', createdAt: ts(5), moderationStatus: status });

/** Seeds fixtures with rules disabled (as the Admin SDK would). */
export async function seed(testEnv) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const { doc, setDoc } = await import('firebase/firestore');
    const db = ctx.firestore();
    const put = (path, data) => setDoc(doc(db, path), data);
    for (const [uid, status] of [['alice', 'active'], ['bob', 'active'], ['carol', 'suspended'], ['mike', 'muted'], ['dave', 'active'], ['erin', 'active'], ['frank', 'active'], ['gina', 'active'], ['zed', 'deleted']]) {
      await put(`users/${uid}`, profile(uid, status));
      await put(`users/${uid}/private/profile`, { dateOfBirth: '1990-01-01', role: uid === 'alice' ? 'admin' : 'user', notificationPrefs: {}, violationCount: 0, mutedUntil: null });
    }
    await put('activities/pub', activity());
    await put('activities/priv', activity({ visibility: 'private' }));
    await put('activities/old', activity({ status: 'cancelled', updatedAt: ts(Date.now() - 40 * 86_400_000) }));
    await put('activities/recent', activity({ status: 'cancelled', updatedAt: ts(Date.now() - 2 * 86_400_000) }));
    for (const a of ['pub', 'priv', 'old', 'recent']) {
      await put(`activities/${a}/members/alice`, member('alice', 'approved', 'host'));
      await put(`activities/${a}/members/bob`, member('bob', 'approved'));
      await put(`activities/${a}/members/dave`, member('dave', 'requested'));
      await put(`activities/${a}/members/erin`, member('erin', 'left'));
      await put(`activities/${a}/members/frank`, member('frank', 'removed'));
      await put(`activities/${a}/members/carol`, member('carol', 'approved'));
      await put(`activities/${a}/messages/visible`, msg('bob'));
      await put(`activities/${a}/messages/hidden`, msg('bob', 'hidden'));
    }
    await put('communityRooms/global', { name: 'Mingle Community', isActive: true });
    await put('communityRooms/global/messages/visible', msg('bob'));
    await put('communityRooms/global/messages/hidden', msg('bob', 'hidden'));
    await put('communityRooms/global/messages/removed', msg('bob', 'removed'));
    await put('userBlocks/bob/blocked/dave', { blockedAt: ts(1), targetDisplayName: 'dave' });
    await put('reports/r1', { reporterId: 'bob', targetType: 'user', targetId: 'dave', status: 'open' });
    await put('moderationActions/a1', { actorId: 'alice', action: 'mute' });
    await put('userRateLimits/bob', { count: 1 });
    await put('deviceTokens/h1', { uid: 'bob', token: 'x' });
    await put('notifications/n1', { userId: 'bob', type: 'x', read: false, createdAt: ts(1) });
    await put('notifications/n2', { userId: 'alice', type: 'x', read: false, createdAt: ts(1) });
  });
}
