import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createEnv } from './helpers/env.js';

let env;
before(async () => { env = await createEnv(); });
after(async () => { await env.close(); });
const A = '/api/v1/activities';
const post = (u, text) => env.api('POST', '/api/v1/community/messages', { token: u.token, body: { text } });

async function staff(uid, role, { claim = role, profile = role } = {}) {
  const u = await env.signup(uid, { claims: claim ? { role: claim } : {}, established: true });
  if (profile) await env.db.doc(`users/${uid}/private/profile`).update({ role: profile });
  return u;
}

// ------------------------------------------------------------------ reports
test('reports: create for community message, user and activity; snapshot is server-captured', async () => {
  const a = await env.signup('ra', { established: true }); const b = await env.signup('rb', { established: true });
  const m = await post(a, 'rude words here');
  const r = await env.api('POST', '/api/v1/reports', { token: b.token, body: {
    targetType: 'message', targetId: m.body.data.id, reason: 'harassment', details: 'abusive',
    context: { roomType: 'community', textSnapshot: 'FORGED' },
  } });
  assert.equal(r.status, 201);
  const doc = (await env.db.doc(`reports/${r.body.data.id}`).get()).data();
  assert.equal(doc.reporterId, 'rb');
  assert.equal(doc.targetUserId, 'ra');
  assert.equal(doc.status, 'open');
  assert.equal(doc.context.textSnapshot, 'rude words here');

  const viaCommunity = await env.api('POST', `/api/v1/community/messages/${m.body.data.id}/report`, { token: (await env.signup('rc')).token, body: { reason: 'spam' } });
  assert.equal(viaCommunity.status, 201);

  assert.equal((await env.api('POST', '/api/v1/reports', { token: b.token, body: { targetType: 'user', targetId: 'ra', reason: 'unsafe' } })).status, 201);
  const act = await env.createActivity(a);
  assert.equal((await env.api('POST', '/api/v1/reports', { token: b.token, body: { targetType: 'activity', targetId: act.id, reason: 'unsafe' } })).status, 201);
});

test('reports: cannot report self, missing target 404, duplicates 409, bad payloads 400', async () => {
  const a = await env.signup('rd1', { established: true }); const b = await env.signup('rd2', { established: true });
  const own = await post(a, 'my own message');
  const R = (u, body) => env.api('POST', '/api/v1/reports', { token: u.token, body });
  assert.equal((await R(a, { targetType: 'user', targetId: 'rd1', reason: 'spam' })).status, 400);
  assert.equal((await R(a, { targetType: 'message', targetId: own.body.data.id, reason: 'spam', context: { roomType: 'community' } })).status, 400);
  const act = await env.createActivity(a);
  assert.equal((await R(a, { targetType: 'activity', targetId: act.id, reason: 'spam' })).status, 400);
  assert.equal((await R(b, { targetType: 'user', targetId: 'ghost', reason: 'spam' })).status, 404);
  assert.equal((await R(b, { targetType: 'activity', targetId: 'ghost', reason: 'spam' })).status, 404);
  assert.equal((await R(b, { targetType: 'message', targetId: 'ghost', reason: 'spam', context: { roomType: 'community' } })).status, 404);
  assert.equal((await R(b, { targetType: 'message', targetId: own.body.data.id, reason: 'spam' })).status, 400, 'roomType required');
  assert.equal((await R(b, { targetType: 'user', targetId: 'rd1', reason: 'nonsense' })).status, 400);
  assert.equal((await R(b, { targetType: 'user', targetId: 'rd1', reason: 'spam', details: 'x'.repeat(1001) })).status, 400);
  assert.equal((await R(b, { targetType: 'bogus', targetId: 'rd1', reason: 'spam' })).status, 400);

  assert.equal((await R(b, { targetType: 'user', targetId: 'rd1', reason: 'spam' })).status, 201);
  const dup = await R(b, { targetType: 'user', targetId: 'rd1', reason: 'harassment' });
  assert.equal(dup.status, 409);
  assert.equal(dup.body.error.details.reason, 'already_reported');
  const burst = await Promise.all(Array.from({ length: 5 }, () => R(b, { targetType: 'activity', targetId: act.id, reason: 'spam' })));
  assert.equal(burst.filter((r) => r.status === 201).length, 1, 'concurrent duplicate reports collapse to one');
  assert.equal((await env.db.collection('reports').where('reporterId', '==', 'rd2').where('targetId', '==', act.id).get()).size, 1);
});

test('reports: activity-chat messages can only be reported by participants', async () => {
  const host = await env.signup('rh', { established: true }); const m = await env.signup('rm', { established: true }); const out = await env.signup('ro', { established: true });
  const act = await env.createActivity(host);
  await env.api('POST', `${A}/${act.id}/join`, { token: m.token });
  const msg = await env.api('POST', `${A}/${act.id}/messages`, { token: host.token, body: { text: 'activity chat text' } });
  const body = { targetType: 'message', targetId: msg.body.data.id, reason: 'spam', context: { roomType: 'activity', activityId: act.id } };
  assert.equal((await env.api('POST', '/api/v1/reports', { token: out.token, body })).status, 403);
  assert.equal((await env.api('POST', '/api/v1/reports', { token: m.token, body })).status, 201);
});

// ------------------------------------------------------------------ blocks
test('blocks: create, list, idempotent, unblock; self and unknown targets rejected', async () => {
  const a = await env.signup('ba'); const b = await env.signup('bb', { name: 'Bee' });
  assert.equal((await env.api('POST', '/api/v1/users/ba/block', { token: a.token })).status, 400);
  assert.equal((await env.api('POST', '/api/v1/users/ghost/block', { token: a.token })).status, 404);
  assert.equal((await env.api('POST', '/api/v1/users/bb/block', { token: a.token })).status, 201);
  assert.equal((await env.api('POST', '/api/v1/users/bb/block', { token: a.token })).status, 201, 'idempotent');
  const list = await env.api('GET', '/api/v1/users/me/blocks', { token: a.token });
  assert.deepEqual(list.body.data.map((x) => [x.uid, x.targetDisplayName]), [['bb', 'Bee']]);
  assert.equal((await env.api('GET', '/api/v1/users/me/blocks', { token: b.token })).body.data.length, 0, 'blocks are private to the blocker');
  assert.equal((await env.api('DELETE', '/api/v1/users/bb/block', { token: a.token })).status, 200);
  assert.equal((await env.api('GET', '/api/v1/users/me/blocks', { token: a.token })).body.data.length, 0);
  assert.equal((await env.api('DELETE', '/api/v1/users/bb/block', { token: a.token })).status, 200);
});

// ------------------------------------------------------------------ admin
const ADMIN = '/api/v1/admin';

test('admin routes: unauthenticated 401, plain user 403', async () => {
  assert.equal((await env.api('GET', `${ADMIN}/reports`)).status, 401);
  const u = await env.signup('au1');
  for (const [m, p] of [['GET', '/reports'], ['GET', '/metrics'], ['POST', '/users/au1/suspend'], ['POST', '/messages/community/x/hide'], ['POST', '/reports/x/dismiss'], ['POST', '/activities/x/cancel']]) {
    const r = await env.api(m, ADMIN + p, { token: u.token, body: m === 'POST' ? { reason: 'because' } : undefined });
    assert.equal(r.status, 403, `${m} ${p}`);
    assert.equal(r.body.error.code, 'forbidden');
  }
});

test('admin requires BOTH the auth claim and the private profile role', async () => {
  const claimOnly = await staff('au2', 'admin', { profile: 'user' });
  assert.equal((await env.api('GET', `${ADMIN}/metrics`, { token: claimOnly.token })).status, 403);
  const profileOnly = await staff('au3', 'admin', { claim: null });
  assert.equal((await env.api('GET', `${ADMIN}/metrics`, { token: profileOnly.token })).status, 403);
  const wrongClaim = await staff('au4', 'admin', { claim: 'superuser' });
  assert.equal((await env.api('GET', `${ADMIN}/metrics`, { token: wrongClaim.token })).status, 403);
  const both = await staff('au5', 'admin');
  const r = await env.api('GET', `${ADMIN}/metrics`, { token: both.token });
  assert.equal(r.status, 200);
  assert.ok(r.body.data.users >= 5);
  const mod = await staff('au6', 'moderator');
  assert.equal((await env.api('GET', `${ADMIN}/reports`, { token: mod.token })).status, 200);
});

test('admin: list/dismiss reports, hide/remove messages, all audited', async () => {
  const admin = await staff('ad1', 'admin');
  const a = await env.signup('ad2', { established: true }); const b = await env.signup('ad3', { established: true });
  const m1 = await post(a, 'bad message one'); const m2 = await post(a, 'bad message two');
  const rep1 = await env.api('POST', '/api/v1/reports', { token: b.token, body: { targetType: 'message', targetId: m1.body.data.id, reason: 'spam', context: { roomType: 'community' } } });
  const rep2 = await env.api('POST', '/api/v1/reports', { token: b.token, body: { targetType: 'message', targetId: m2.body.data.id, reason: 'spam', context: { roomType: 'community' } } });
  const list = await env.api('GET', `${ADMIN}/reports?status=open`, { token: admin.token });
  assert.equal(list.status, 200);
  assert.ok(list.body.data.length >= 2);
  assert.equal((await env.api('GET', `${ADMIN}/reports?status=weird`, { token: admin.token })).status, 400);

  const hide = await env.api('POST', `${ADMIN}/messages/community/${m1.body.data.id}/hide`, { token: admin.token, body: { reason: 'spam', reportId: rep1.body.data.id } });
  assert.equal(hide.status, 200);
  const stored = (await env.db.doc(`communityRooms/global/messages/${m1.body.data.id}`).get()).data();
  assert.equal(stored.moderationStatus, 'hidden');
  assert.equal(stored.text, 'bad message one', 'evidence retained');
  assert.equal((await env.db.doc(`reports/${rep1.body.data.id}`).get()).data().status, 'actioned');
  assert.equal((await env.api('POST', `${ADMIN}/messages/community/${m2.body.data.id}/remove`, { token: admin.token, body: { reason: 'spam' } })).status, 200);
  assert.equal((await env.api('POST', `${ADMIN}/messages/community/ghost/hide`, { token: admin.token, body: { reason: 'spam' } })).status, 404);
  assert.equal((await env.api('POST', `${ADMIN}/messages/community/${m1.body.data.id}/hide`, { token: admin.token, body: {} })).status, 400, 'reason required');

  const dismiss = await env.api('POST', `${ADMIN}/reports/${rep2.body.data.id}/dismiss`, { token: admin.token, body: { reason: 'not abusive' } });
  assert.equal(dismiss.status, 200);
  assert.equal((await env.api('POST', `${ADMIN}/reports/${rep2.body.data.id}/dismiss`, { token: admin.token, body: { reason: 'again' } })).status, 409);

  const actions = (await env.db.collection('moderationActions').where('actorId', '==', 'ad1').get()).docs.map((d) => d.data());
  assert.deepEqual(actions.map((x) => x.action).sort(), ['dismiss_report', 'hide_message', 'remove_message']);
  assert.ok(actions.every((x) => x.reason && x.targetId && x.createdAt));
  // moderated sender gets an in-app notification without the message text
  const n = await env.db.collection('notifications').where('userId', '==', 'ad2').get();
  assert.ok(n.docs.some((d) => d.data().type === 'moderation' && !JSON.stringify(d.data()).includes('bad message')));
});

test('admin: suspend / mute / reinstate users with audit trail and immediate effect', async () => {
  const admin = await staff('as1', 'admin'); const mod = await staff('as2', 'moderator');
  const u = await env.signup('as3', { established: true });
  assert.equal((await post(u, 'before suspension')).status, 201);

  assert.equal((await env.api('POST', `${ADMIN}/users/as1/suspend`, { token: admin.token, body: { reason: 'self' } })).status, 403, 'cannot moderate self');
  assert.equal((await env.api('POST', `${ADMIN}/users/as1/suspend`, { token: mod.token, body: { reason: 'coup' } })).status, 403, 'moderator cannot touch admin');
  assert.equal((await env.api('POST', `${ADMIN}/users/ghost/suspend`, { token: mod.token, body: { reason: 'nobody' } })).status, 404);

  const mute = await env.api('POST', `${ADMIN}/users/as3/mute`, { token: mod.token, body: { reason: 'cool off', durationHours: 2 } });
  assert.equal(mute.status, 200);
  assert.equal(mute.body.data.accountStatus, 'muted');
  const muted = await post(u, 'muted message');
  assert.equal(muted.status, 403);
  assert.equal(muted.body.error.code, 'account_restricted');

  assert.equal((await env.api('POST', `${ADMIN}/users/as3/suspend`, { token: mod.token, body: { reason: 'repeat abuse' } })).status, 200);
  assert.ok(env.auth.revoked.has('as3'));
  assert.equal((await env.api('GET', '/api/v1/activities', { token: u.token })).status, 403);
  assert.equal((await env.api('GET', '/api/v1/users/as3', { token: admin.token })).status, 404, 'suspended users are hidden from public profile');

  assert.equal((await env.api('POST', `${ADMIN}/users/as3/reinstate`, { token: mod.token, body: { reason: 'appeal granted' } })).status, 200);
  assert.equal((await post(u, 'welcome back')).status, 201);
  const actions = (await env.db.collection('moderationActions').where('targetId', '==', 'as3').get()).docs.map((d) => d.data().action).sort();
  assert.deepEqual(actions, ['mute', 'reinstate', 'suspend']);
  assert.equal((await env.api('POST', `${ADMIN}/users/as3/mute`, { token: mod.token, body: { reason: 'x', durationHours: 99999 } })).status, 400);
});

test('admin: cancel activity notifies participants and is audited', async () => {
  const admin = await staff('ac1', 'admin');
  const host = await env.signup('ac2'); const p = await env.signup('ac3');
  const act = await env.createActivity(host);
  await env.api('POST', `${A}/${act.id}/join`, { token: p.token });
  const r = await env.api('POST', `${ADMIN}/activities/${act.id}/cancel`, { token: admin.token, body: { reason: 'unsafe venue' } });
  assert.equal(r.status, 200);
  assert.equal((await env.db.doc(`activities/${act.id}`).get()).data().status, 'cancelled');
  const actions = await env.db.collection('moderationActions').where('targetId', '==', act.id).get();
  assert.equal(actions.docs[0].data().action, 'cancel_activity');
  const nHost = await env.db.collection('notifications').where('userId', '==', 'ac2').get();
  assert.ok(nHost.docs.some((d) => d.data().type === 'activity_cancelled'), 'host is notified of admin cancellation');
  assert.equal((await env.api('POST', `${ADMIN}/activities/${act.id}/cancel`, { token: admin.token, body: { reason: 'again' } })).status, 409);
});
