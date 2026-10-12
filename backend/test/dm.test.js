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
