import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createEnv } from './helpers/env.js';

let env;
before(async () => { env = await createEnv(); });
after(async () => { await env.close(); });
const U = '/api/v1/users';
const dm = (from, to, body) => env.api('POST', `${U}/${to}/messages`, { token: from.token, body });
const befriend = (a, b) => env.db.doc(`friendships/${[a, b].sort().join('_')}`).set({ users: [a, b].sort(), requesterId: a, status: 'accepted' });

test('dm: friends can message; dm doc, message and notification are written', async () => {
  const a = await env.signup('dm-a1', { name: 'Asha', established: true }); await env.signup('dm-a2', { name: 'Ben', established: true });
  await befriend('dm-a1', 'dm-a2');
  const r = await dm(a, 'dm-a2', { text: 'hello friend', clientMessageId: 'client-msg-1' });
  assert.equal(r.status, 201);
  assert.equal(r.body.data.text, 'hello friend');
  assert.equal(r.body.data.senderId, 'dm-a1');
  const doc = (await env.db.doc('dms/dm-a1_dm-a2').get()).data();
  assert.deepEqual(doc.users, ['dm-a1', 'dm-a2']);
  assert.equal(doc.lastMessage.text, 'hello friend');
  assert.equal(doc.lastMessage.senderId, 'dm-a1');
  assert.equal(doc.lastMessage.senderName, 'Asha');
  assert.ok(doc.updatedAt);
  const msg = (await env.db.doc(`dms/dm-a1_dm-a2/messages/${r.body.data.id}`).get()).data();
  assert.equal(msg.moderationStatus, 'visible');
  await new Promise((res) => setTimeout(res, 20));
  const n = await env.db.collection('notifications').where('userId', '==', 'dm-a2').get();
  assert.equal(n.docs[0].data().type, 'direct_message');
  assert.equal(n.docs[0].data().data.userId, 'dm-a1');
  assert.equal(n.docs[0].data().data.actorName, 'Asha');
});

test('dm: idempotent clientMessageId returns 200 and writes once', async () => {
  const a = await env.signup('dm-i1', { established: true }); await env.signup('dm-i2', { established: true });
  await befriend('dm-i1', 'dm-i2');
  const first = await dm(a, 'dm-i2', { text: 'once', clientMessageId: 'same-client-id' });
  const again = await dm(a, 'dm-i2', { text: 'once', clientMessageId: 'same-client-id' });
  assert.equal(first.status, 201);
  assert.equal(again.status, 200);
  assert.equal(again.body.data.id, first.body.data.id);
  assert.equal((await env.db.collection('dms/dm-i1_dm-i2/messages').get()).size, 1);
});

test('dm: non-friends and pending requests are rejected and nothing is written', async () => {
  const a = await env.signup('dm-n1', { established: true }); await env.signup('dm-n2', { established: true });
  const r = await dm(a, 'dm-n2', { text: 'hi stranger' });
  assert.equal(r.status, 403);
  assert.equal(r.body.error.details.reason, 'not_friends');
  await env.db.doc('friendships/dm-n1_dm-n2').set({ users: ['dm-n1', 'dm-n2'], requesterId: 'dm-n1', status: 'pending' });
  assert.equal((await dm(a, 'dm-n2', { text: 'still pending' })).status, 403);
  assert.equal((await env.db.doc('dms/dm-n1_dm-n2').get()).exists, false);
  assert.equal((await dm(a, 'dm-nobody', { text: 'ghost' })).status, 404);
  assert.equal((await dm(a, 'dm-n1', { text: 'myself' })).status, 400);
});

test('dm: blocked in either direction is rejected', async () => {
  const a = await env.signup('dm-b1', { established: true }); const b = await env.signup('dm-b2', { established: true });
  await befriend('dm-b1', 'dm-b2');
  await env.db.doc('userBlocks/dm-b2/blocked/dm-b1').set({ blockedAt: new Date() });
  assert.equal((await dm(a, 'dm-b2', { text: 'blocked by them' })).status, 403);
  await env.db.doc('userBlocks/dm-b2/blocked/dm-b1').delete();
  await env.db.doc('userBlocks/dm-b1/blocked/dm-b2').set({ blockedAt: new Date() });
  assert.equal((await dm(b, 'dm-b1', { text: 'blocked by me' })).status, 403);
  assert.equal((await env.db.doc('dms/dm-b1_dm-b2').get()).exists, false);
});

// ------------------------------------------------------------------ people who share a plan
const A = '/api/v1/activities';
const join = (u, id) => env.api('POST', `${A}/${id}/join`, { token: u.token });
const leave = (u, id) => env.api('POST', `${A}/${id}/leave`, { token: u.token });
const profileOf = (viewer, uid) => env.api('GET', `${U}/${uid}`, { token: viewer.token });

test('dm: people in the same plan can message without being friends', async () => {
  const host = await env.signup('dm-p-host', { name: 'Hema', established: true });
  const guest = await env.signup('dm-p-guest', { name: 'Gaurav', established: true });
  const act = await env.createActivity(host);
  assert.equal((await join(guest, act.id)).status, 200);

  const r = await dm(guest, 'dm-p-host', { text: 'see you at the start', clientMessageId: 'plan-msg-1' });
  assert.equal(r.status, 201, JSON.stringify(r.body));
  assert.equal(r.body.data.senderId, 'dm-p-guest');
  assert.equal((await env.db.doc('dms/dm-p-guest_dm-p-host').get()).exists, true);
  // And the other direction.
  assert.equal((await dm(host, 'dm-p-guest', { text: 'sounds good', clientMessageId: 'plan-msg-2' })).status, 201);
  // They are still not friends.
  assert.equal((await profileOf(guest, 'dm-p-host')).body.data.friendship, 'none');
});

test('dm: two guests of the same plan can message each other', async () => {
  const host = await env.signup('dm-g-host', { established: true });
  const g1 = await env.signup('dm-g-1', { established: true });
  const g2 = await env.signup('dm-g-2', { established: true });
  const act = await env.createActivity(host);
  await join(g1, act.id); await join(g2, act.id);
  assert.equal((await dm(g1, 'dm-g-2', { text: 'are you coming?', clientMessageId: 'guest-msg-1' })).status, 201);
});

test('dm: not in a shared plan, or only requested / left / cancelled, is still rejected', async () => {
  const host = await env.signup('dm-x-host', { established: true });
  const joined = await env.signup('dm-x-joined', { established: true });
  const outsider = await env.signup('dm-x-out', { established: true });
  const quitter = await env.signup('dm-x-quit', { established: true });
  const act = await env.createActivity(host);
  await join(joined, act.id);
  await join(quitter, act.id);
  await leave(quitter, act.id);

  // Different plans only.
  const other = await env.createActivity(outsider);
  assert.equal((await dm(outsider, 'dm-x-host', { text: 'hello', clientMessageId: 'share-x-msg-1' })).status, 403);
  assert.equal(other.id !== act.id, true);
  // Left the plan: no longer connected.
  const r = await dm(quitter, 'dm-x-host', { text: 'hello again', clientMessageId: 'share-x-msg-2' });
  assert.equal(r.status, 403);
  assert.equal(r.body.error.details.reason, 'not_friends');

  // Plan cancelled: the connection goes with it.
  assert.equal((await dm(joined, 'dm-x-host', { text: 'before cancel', clientMessageId: 'share-x-msg-3' })).status, 201);
  const gone = await env.signup('dm-x-gone', { established: true });
  const act2 = await env.createActivity(host, { title: 'Second plan to cancel' });
  await join(gone, act2.id);
  assert.equal((await env.api('POST', `${A}/${act2.id}/cancel`, { token: host.token })).status, 200);
  assert.equal((await dm(gone, 'dm-x-host', { text: 'after cancel', clientMessageId: 'share-x-msg-4' })).status, 403);
});

test('dm: a pending join request is not a shared plan', async () => {
  const host = await env.signup('dm-q-host', { established: true });
  const guest = await env.signup('dm-q-guest', { established: true });
  const act = await env.createActivity(host, { approvalRequired: true });
  const j = await join(guest, act.id);
  assert.equal(j.status, 200);
  assert.equal(j.body.data.status ?? j.body.data.membershipStatus ?? 'requested', 'requested');
  assert.equal((await dm(guest, 'dm-q-host', { text: 'let me in', clientMessageId: 'share-q-msg-1' })).status, 403);
});

test('dm: blocking still wins over a shared plan', async () => {
  const host = await env.signup('dm-k-host', { established: true });
  const guest = await env.signup('dm-k-guest', { established: true });
  const act = await env.createActivity(host);
  await join(guest, act.id);
  await env.db.doc('userBlocks/dm-k-host/blocked/dm-k-guest').set({ blockedAt: new Date() });
  const r = await dm(guest, 'dm-k-host', { text: 'hi', clientMessageId: 'share-k-msg-1' });
  assert.equal(r.status, 403);
  assert.equal(r.body.error.details.reason, 'blocked');
});

test('GET /users/:uid reports canMessage for friends and for people who share a plan', async () => {
  const me = await env.signup('dm-c-me', { established: true });
  await env.signup('dm-c-friend', { established: true });
  const mate = await env.signup('dm-c-mate', { established: true });
  const stranger = await env.signup('dm-c-stranger', { established: true });
  await befriend('dm-c-me', 'dm-c-friend');
  const act = await env.createActivity(mate);
  await join(me, act.id);

  assert.equal((await profileOf(me, 'dm-c-friend')).body.data.canMessage, true);
  assert.equal((await profileOf(me, 'dm-c-mate')).body.data.canMessage, true);
  assert.equal((await profileOf(me, 'dm-c-stranger')).body.data.canMessage, false);
  assert.equal((await profileOf(stranger, 'dm-c-me')).body.data.canMessage, false);
  assert.equal((await profileOf(me, 'dm-c-me')).body.data.canMessage, false);
});
