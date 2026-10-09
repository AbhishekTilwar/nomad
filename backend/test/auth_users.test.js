import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createEnv } from './helpers/env.js';

let env;
before(async () => { env = await createEnv(); });
after(async () => { await env.close(); });

test('health and ready need no auth', async () => {
  assert.equal((await env.api('GET', '/health')).status, 200);
  const r = await env.api('GET', '/ready');
  assert.equal(r.status, 200);
});

test('missing token -> 401 unauthenticated', async () => {
  const r = await env.api('GET', '/api/v1/users/me');
  assert.equal(r.status, 401);
  assert.equal(r.body.error.code, 'unauthenticated');
});

test('invalid token -> 401, malformed header -> 401', async () => {
  assert.equal((await env.api('GET', '/api/v1/users/me', { token: 'garbage' })).status, 401);
  const r = await env.api('GET', '/api/v1/users/me', { headers: { authorization: 'Basic abc' } });
  assert.equal(r.status, 401);
});

test('unknown routes return enveloped 404', async () => {
  const r = await env.api('GET', '/api/v1/nope', { token: env.auth.issue('x') });
  assert.equal(r.status, 404);
  assert.equal(r.body.error.code, 'not_found');
});

test('profile: create requires DOB, enforces >=18, never exposes DOB', async () => {
  const token = env.auth.issue('u1');
  const noDob = await env.api('PUT', '/api/v1/users/me', { token, body: { displayName: 'Asha', city: 'pune' } });
  assert.equal(noDob.status, 400);
  assert.equal(noDob.body.error.code, 'validation_failed');

  const underage = await env.api('PUT', '/api/v1/users/me', { token, body: { displayName: 'Kid', city: 'pune', dateOfBirth: '2012-01-01' } });
  assert.equal(underage.status, 400);

  // 18th birthday is tomorrow relative to the fixed clock (2026-10-10) -> still 17
  const almost = await env.api('PUT', '/api/v1/users/me', { token, body: { displayName: 'Almost', city: 'pune', dateOfBirth: '2008-10-11' } });
  assert.equal(almost.status, 400);
  const exact = await env.api('PUT', '/api/v1/users/me', { token, body: { displayName: 'Exact', city: 'pune', dateOfBirth: '2008-10-10' } });
  assert.equal(exact.status, 201);

  const me = await env.api('GET', '/api/v1/users/me', { token });
  assert.equal(me.status, 200);
  assert.equal(me.body.data.ageRange, '18-24');
  assert.equal(me.body.data.private.role, 'user');
  assert.ok(!JSON.stringify(me.body).includes('2008-10-10'), 'DOB must never be returned');
  assert.ok(!('dateOfBirth' in me.body.data));
  assert.equal(me.body.data.accountStatus, 'active');
});

test('profile validation: display name length, bad city, unknown fields (no accountStatus/role injection)', async () => {
  const token = env.auth.issue('u2');
  const bad = await env.api('PUT', '/api/v1/users/me', { token, body: { displayName: 'A', city: 'delhi', dateOfBirth: '1990-01-01' } });
  assert.equal(bad.status, 400);
  const inject = await env.api('PUT', '/api/v1/users/me', {
    token, body: { displayName: 'Mallory', city: 'pune', dateOfBirth: '1990-01-01', accountStatus: 'active', role: 'admin' },
  });
  assert.equal(inject.status, 400, 'strict schema rejects server-controlled fields');
});

test('public profile exposes only public fields; other users cannot read private data', async () => {
  const a = await env.signup('pa', { name: 'Alice' });
  const b = await env.signup('pb', { name: 'Bob' });
  const r = await env.api('GET', '/api/v1/users/pa', { token: b.token });
  assert.equal(r.status, 200);
  assert.equal(r.body.data.displayName, 'Alice');
  for (const k of ['dateOfBirth', 'private', 'role', 'notificationPrefs', 'mutedUntil', 'accountStatus']) {
    assert.ok(!(k in r.body.data), `${k} must not be public`);
  }
  assert.ok(!JSON.stringify(r.body).includes('1995-05-05'));
  // there is no endpoint that returns another user's private profile
  const sneaky = await env.api('GET', '/api/v1/users/pa/private', { token: b.token });
  assert.equal(sneaky.status, 404);
  assert.equal((await env.api('GET', '/api/v1/users/ghost', { token: b.token })).status, 404);
  assert.ok(a);
});

test('PATCH updates, DOB immutable, host snapshot refreshed', async () => {
  const h = await env.signup('ph', { name: 'Hosty' });
  const act = await env.createActivity(h);
  const p = await env.api('PATCH', '/api/v1/users/me', { token: h.token, body: { displayName: 'Renamed', bio: 'hi' } });
  assert.equal(p.status, 200);
  assert.equal(p.body.data.displayName, 'Renamed');
  const a = await env.api('GET', `/api/v1/activities/${act.id}`, { token: h.token });
  assert.equal(a.body.data.hostDisplayName, 'Renamed');
  const dob = await env.api('PATCH', '/api/v1/users/me', { token: h.token, body: { dateOfBirth: '1980-01-01' } });
  assert.equal(dob.status, 409);
});

test('suspended account is blocked everywhere except GET /users/me', async () => {
  const u = await env.signup('sus1');
  await env.db.doc('users/sus1').update({ accountStatus: 'suspended' });
  const r = await env.api('GET', '/api/v1/activities', { token: u.token });
  assert.equal(r.status, 403);
  assert.equal(r.body.error.code, 'account_restricted');
  assert.equal((await env.api('GET', '/api/v1/users/me', { token: u.token })).status, 200);
});

test('body size limit and malformed JSON', async () => {
  const token = env.auth.issue('big');
  const big = await env.api('PUT', '/api/v1/users/me', { token, body: JSON.stringify({ bio: 'x'.repeat(50_000) }) });
  assert.equal(big.status, 413);
  const bad = await env.api('PUT', '/api/v1/users/me', { token, body: '{not json' });
  assert.equal(bad.status, 400);
});

test('CORS: allowed origin echoed, unknown origin rejected, no wildcard', async () => {
  const ok = await env.api('GET', '/health', { headers: { origin: 'https://app.example.test' } });
  assert.equal(ok.headers.get('access-control-allow-origin'), 'https://app.example.test');
  const bad = await env.api('GET', '/health', { headers: { origin: 'https://evil.example' } });
  assert.equal(bad.status, 403);
});

test('device tokens and notification prefs', async () => {
  const u = await env.signup('dt1');
  const tok = 'fcm-token-'.padEnd(60, 'x');
  assert.equal((await env.api('POST', '/api/v1/users/me/device-tokens', { token: u.token, body: { token: tok, platform: 'android' } })).status, 201);
  assert.equal((await env.api('POST', '/api/v1/users/me/device-tokens', { token: u.token, body: { token: 'short', platform: 'android' } })).status, 400);
  const prefs = await env.api('PUT', '/api/v1/users/me/notification-prefs', { token: u.token, body: { reminders: false } });
  assert.equal(prefs.body.data.reminders, false);
  assert.equal(prefs.body.data.joinRequests, true);
  const other = await env.signup('dt2');
  const del = await env.api('DELETE', `/api/v1/users/me/device-tokens/${tok}`, { token: other.token });
  assert.equal(del.status, 403);
  assert.equal((await env.api('DELETE', `/api/v1/users/me/device-tokens/${tok}`, { token: u.token })).status, 200);
});

test('DELETE /users/me removes profile data and anonymises messages', async () => {
  const u = await env.signup('del1', { established: true });
  const v = await env.signup('del2');
  await env.api('POST', '/api/v1/community/messages', { token: u.token, body: { text: 'hello world' } });
  await env.api('POST', `/api/v1/users/del2/block`, { token: u.token });
  const r = await env.api('DELETE', '/api/v1/users/me', { token: u.token });
  assert.equal(r.status, 200);
  assert.ok(env.auth.deleted.has('del1'));
  assert.equal((await env.db.doc('users/del1').get()).exists, false);
  assert.equal((await env.db.doc('users/del1/private/profile').get()).exists, false);
  const msgs = await env.db.collection('communityRooms/global/messages').get();
  assert.equal(msgs.docs[0].data().senderName, 'Deleted user');
  assert.equal((await env.db.collection('userBlocks/del1/blocked').get()).size, 0);
  assert.ok(v);
});
