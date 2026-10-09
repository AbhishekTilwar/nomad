import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { Writable } from 'node:stream';
import { Timestamp } from 'firebase-admin/firestore';
import { createEnv, HOUR } from './helpers/env.js';
import { createLogger } from '../src/lib/logger.js';

let env;
before(async () => { env = await createEnv(); });
after(async () => { await env.close(); });
const C = '/api/v1/community/messages';
const post = (u, text, extra = {}) => env.api('POST', C, { token: u.token, body: { text, ...extra } });
const msgCount = async () => (await env.db.collection('communityRooms/global/messages').get()).size;

test('suspended user cannot post to community (and nothing is written)', async () => {
  const u = await env.signup('s1', { established: true });
  await env.db.doc('users/s1').update({ accountStatus: 'suspended' });
  const before = await msgCount();
  const r = await post(u, 'hello there');
  assert.equal(r.status, 403);
  assert.equal(r.body.error.code, 'account_restricted');
  assert.equal(await msgCount(), before);
});

test('muted user cannot post but can still read the room; mute expiry restores posting', async () => {
  const u = await env.signup('m1', { established: true });
  await env.db.doc('users/m1').update({ accountStatus: 'muted' });
  await env.db.doc('users/m1/private/profile').update({ mutedUntil: Timestamp.fromMillis(env.clock.ms + HOUR) });
  const r = await post(u, 'hi all');
  assert.equal(r.status, 403);
  assert.equal(r.body.error.code, 'account_restricted');
  assert.equal(r.body.error.details.accountStatus, 'muted');
  const room = await env.api('GET', '/api/v1/community', { token: u.token });
  assert.equal(room.status, 200);
  assert.equal(room.body.data.viewer.canPost, false);
  assert.equal(room.body.data.viewer.muted, true);
  env.clock.ms += 2 * HOUR;
  assert.equal((await post(u, 'back again')).status, 201);
  env.clock.ms -= 2 * HOUR;
});

test('empty, whitespace-only, control-char-only and oversized messages are rejected', async () => {
  const u = await env.signup('v1', { established: true });
  for (const text of ['', '   \n\t ', '​​', 'x'.repeat(501), 'ä'.repeat(501)]) {
    const r = await post(u, text);
    assert.equal(r.status, 400, `text length ${text.length}`);
    assert.equal(r.body.error.code, 'validation_failed');
  }
  assert.equal((await env.api('POST', C, { token: u.token, body: {} })).status, 400);
  assert.equal((await env.api('POST', C, { token: u.token, body: { text: 42 } })).status, 400);
  assert.equal((await env.api('POST', C, { token: u.token, body: { text: 'ok', extra: 1 } })).status, 400);
  const ok = await post(u, `  ${'y'.repeat(500)}  `);
  assert.equal(ok.status, 201, 'exactly 500 chars after trim is allowed');
  assert.equal(ok.body.data.text.length, 500);
  // rejected validation errors are not rate-limit violations
  const rl = (await env.db.doc('userRateLimits/v1').get()).data();
  assert.equal(rl.violations, 0);
  assert.equal(rl.count, 1);
});

test('message is stored trimmed with sender snapshot', async () => {
  const u = await env.signup('t1', { name: 'Trim Me', established: true });
  const r = await post(u, '   hello   world \n');
  assert.equal(r.status, 201);
  assert.equal(r.body.data.text, 'hello   world');
  assert.equal(r.body.data.senderId, 't1');
  assert.equal(r.body.data.senderName, 'Trim Me');
  assert.equal(r.body.data.moderationStatus, 'visible');
});

test('duplicate text within 30s is rejected, allowed after the window', async () => {
  const u = await env.signup('d1', { established: true });
  assert.equal((await post(u, 'Same thing')).status, 201);
  env.clock.ms += 10_000;
  const dup = await post(u, '  same   THING ');
  assert.equal(dup.status, 429);
  assert.equal(dup.body.error.code, 'rate_limited');
  assert.equal(dup.body.error.details.reason, 'duplicate_message');
  assert.equal((await post(u, 'different thing')).status, 201);
  env.clock.ms += 31_000;
  assert.equal((await post(u, 'different thing')).status, 201);
});

test('new account limit 5 / 10 min, resets after the window; established limit 20', async () => {
  const n = await env.signup('r1');
  for (let i = 0; i < 5; i++) assert.equal((await post(n, `msg ${i}`)).status, 201);
  const over = await post(n, 'msg 6');
  assert.equal(over.status, 429);
  assert.equal(over.body.error.details.reason, 'rate_limit');
  assert.ok(over.headers.get('retry-after'));
  env.clock.ms += 10 * 60_000 + 1000;
  assert.equal((await post(n, 'after window')).status, 201);

  const e = await env.signup('r2', { established: true });
  for (let i = 0; i < 20; i++) assert.equal((await post(e, `est ${i}`)).status, 201, `msg ${i}`);
  assert.equal((await post(e, 'est 21')).status, 429);
});

test('rate limit holds under concurrent requests (new: 5, established: 20)', async () => {
  const n = await env.signup('c1');
  const before = await msgCount();
  const rs = await Promise.all(Array.from({ length: 15 }, (_, i) => post(n, `parallel ${i}`)));
  assert.equal(rs.filter((r) => r.status === 201).length, 5);
  assert.equal(rs.filter((r) => r.status === 429).length, 10);
  assert.equal((await msgCount()) - before, 5);

  const e = await env.signup('c2', { established: true });
  const before2 = await msgCount();
  const rs2 = await Promise.all(Array.from({ length: 30 }, (_, i) => post(e, `parallel est ${i}`)));
  assert.equal(rs2.filter((r) => r.status === 201).length, 20);
  assert.equal((await msgCount()) - before2, 20);
  assert.equal((await env.db.doc('userRateLimits/c2').get()).data().count, 20);
});

test('links are blocked for new accounts only', async () => {
  const n = await env.signup('k1');
  // each rejected link is a violation; stay below the cooldown threshold (3) per user
  for (const t of ['check https://spam.example/x', 'visit www.spam.example']) {
    const r = await post(n, t);
    assert.equal(r.status, 400, t);
    assert.equal(r.body.error.code, 'validation_failed');
  }
  const n2 = await env.signup('k3');
  for (const t of ['go to spam.com now', 'wa.me/12345']) assert.equal((await post(n2, t)).status, 400, t);
  assert.equal((await post(n, 'no links here, just 3.5 stars')).status, 201);
  const e = await env.signup('k2', { established: true });
  assert.equal((await post(e, 'check https://example.com')).status, 201);
});

test('escalating cooldown after repeated violations', async () => {
  const n = await env.signup('x1');
  for (let i = 0; i < 5; i++) await post(n, `fill ${i}`);
  // three violations -> first cooldown (10 min)
  const v = [];
  for (let i = 0; i < 3; i++) v.push(await post(n, `over ${i}`));
  assert.deepEqual(v.map((r) => r.status), [429, 429, 429]);
  assert.equal(v[2].body.error.details.cooldownMinutes, 10);
  const during = await post(n, 'during cooldown');
  assert.equal(during.body.error.details.reason, 'cooldown');
  assert.equal((await env.db.doc('userRateLimits/x1').get()).data().violations, 3, 'rejections during cooldown do not escalate');
  assert.equal((await env.db.doc('users/x1/private/profile').get()).data().violationCount, 3);
  // wait out cooldown + window; second round of 3 violations doubles the cooldown
  env.clock.ms += 11 * 60_000;
  for (let i = 0; i < 5; i++) assert.equal((await post(n, `again ${i}`)).status, 201);
  const w = [];
  for (let i = 0; i < 3; i++) w.push(await post(n, `over again ${i}`));
  assert.equal(w[2].body.error.details.cooldownMinutes, 20);
  const room = await env.api('GET', '/api/v1/community', { token: n.token });
  assert.equal(room.body.data.viewer.canPost, false);
  assert.ok(room.body.data.viewer.cooldownUntil);
});

test('clientMessageId makes retries idempotent and does not consume quota', async () => {
  const n = await env.signup('i1');
  const a = await post(n, 'first', { clientMessageId: 'client-msg-0001' });
  assert.equal(a.status, 201);
  const b = await post(n, 'first', { clientMessageId: 'client-msg-0001' });
  assert.equal(b.status, 200);
  assert.equal(b.body.data.id, a.body.data.id);
  assert.equal((await env.db.doc('userRateLimits/i1').get()).data().count, 1);
  assert.equal((await post(n, 'x', { clientMessageId: 'bad id!' })).status, 400);
});

test('GET /community returns room + viewer restrictions', async () => {
  const n = await env.signup('g1');
  const r = await env.api('GET', '/api/v1/community', { token: n.token });
  assert.equal(r.status, 200);
  assert.equal(r.body.data.room.name, 'Mingle Community');
  assert.equal(r.body.data.viewer.isNewAccount, true);
  assert.equal(r.body.data.viewer.limits.messagesPerWindow, 5);
  assert.equal(r.body.data.viewer.limits.linksAllowed, false);
  assert.equal(r.body.data.viewer.canPost, true);
});

test('limits are env-configurable', async () => {
  const e = await createEnv({ env: { NEW_ACCOUNT_MSG_LIMIT: '2', MESSAGE_MAX_LENGTH: '10', NEW_ACCOUNT_BLOCK_LINKS: 'false' } });
  try {
    const u = await e.signup('cfg');
    assert.equal((await e.api('POST', C, { token: u.token, body: { text: 'a'.repeat(11) } })).status, 400);
    assert.equal((await e.api('POST', C, { token: u.token, body: { text: 'see a.com' } })).status, 201);
    assert.equal((await e.api('POST', C, { token: u.token, body: { text: 'two' } })).status, 201);
    assert.equal((await e.api('POST', C, { token: u.token, body: { text: 'three' } })).status, 429);
  } finally { await e.close(); }
});

// ---------------------------------------------------------------- activity chat
const A = '/api/v1/activities';
test('activity chat: only approved members can read or post', async () => {
  const host = await env.signup('ch', { established: true });
  const member = await env.signup('cm', { established: true });
  const pending = await env.signup('cp', { established: true });
  const stranger = await env.signup('cs', { established: true });
  const leaver = await env.signup('cl', { established: true });
  const removed = await env.signup('cr', { established: true });
  const act = await env.createActivity(host, { approvalRequired: true });
  await env.api('POST', `${A}/${act.id}/join`, { token: member.token });
  await env.api('POST', `${A}/${act.id}/approve/cm`, { token: host.token });
  await env.api('POST', `${A}/${act.id}/join`, { token: pending.token });
  for (const u of [leaver, removed]) {
    await env.api('POST', `${A}/${act.id}/join`, { token: u.token });
    await env.api('POST', `${A}/${act.id}/approve/${u.uid}`, { token: host.token });
  }
  await env.api('POST', `${A}/${act.id}/leave`, { token: leaver.token });
  await env.api('POST', `${A}/${act.id}/remove/cr`, { token: host.token });

  for (const u of [pending, stranger, leaver, removed]) {
    const g = await env.api('GET', `${A}/${act.id}/messages`, { token: u.token });
    assert.equal(g.status, 403, `${u.uid} GET`);
    assert.equal(g.body.error.code, 'forbidden');
    const p = await env.api('POST', `${A}/${act.id}/messages`, { token: u.token, body: { text: 'let me in' } });
    assert.equal(p.status, 403, `${u.uid} POST`);
  }
  const mine = await env.api('POST', `${A}/${act.id}/messages`, { token: member.token, body: { text: 'hello team' } });
  assert.equal(mine.status, 201);
  await env.api('POST', `${A}/${act.id}/messages`, { token: host.token, body: { text: 'welcome' } });
  const list = await env.api('GET', `${A}/${act.id}/messages`, { token: member.token });
  assert.equal(list.status, 200);
  assert.deepEqual(list.body.data.map((m) => m.text), ['welcome', 'hello team']);
  assert.equal((await env.api('GET', `${A}/nope/messages`, { token: member.token })).status, 404);

  // hidden messages are not returned
  await env.db.doc(`activities/${act.id}/messages/${mine.body.data.id}`).update({ moderationStatus: 'hidden' });
  const after = await env.api('GET', `${A}/${act.id}/messages`, { token: member.token });
  assert.deepEqual(after.body.data.map((m) => m.text), ['welcome']);

  // blocked senders are filtered for the blocker only
  await env.api('POST', '/api/v1/users/ch/block', { token: member.token });
  assert.equal((await env.api('GET', `${A}/${act.id}/messages`, { token: member.token })).body.data.length, 0);
  assert.equal((await env.api('GET', `${A}/${act.id}/messages`, { token: host.token })).body.data.length, 1);

  // pagination
  for (let i = 0; i < 4; i++) await env.api('POST', `${A}/${act.id}/messages`, { token: host.token, body: { text: `page ${i}` } });
  const p1 = await env.api('GET', `${A}/${act.id}/messages?limit=2`, { token: host.token });
  assert.equal(p1.body.data.length, 2);
  const p2 = await env.api('GET', `${A}/${act.id}/messages?limit=2&cursor=${p1.body.nextCursor}`, { token: host.token });
  assert.ok(!p2.body.data.some((m) => p1.body.data.some((x) => x.id === m.id)));

  // cancelled -> read-only
  await env.api('POST', `${A}/${act.id}/cancel`, { token: host.token });
  assert.equal((await env.api('POST', `${A}/${act.id}/messages`, { token: host.token, body: { text: 'too late' } })).status, 409);
  assert.equal((await env.api('GET', `${A}/${act.id}/messages`, { token: host.token })).status, 200);
  env.clock.ms += 31 * 24 * HOUR;
  assert.equal((await env.api('GET', `${A}/${act.id}/messages`, { token: host.token })).status, 403, 'archived after 30 days');
  env.clock.ms -= 31 * 24 * HOUR;
});

test('activity chat shares the anti-spam limits', async () => {
  const host = await env.signup('sh');
  const act = await env.createActivity(host);
  const rs = await Promise.all(Array.from({ length: 9 }, (_, i) => env.api('POST', `${A}/${act.id}/messages`, { token: host.token, body: { text: `m${i}` } })));
  assert.equal(rs.filter((r) => r.status === 201).length, 5);
});

test('logger redacts auth headers and message text', () => {
  let out = '';
  const log = createLogger('info', new Writable({ write(chunk, _e, cb) { out += chunk; cb(); } }));
  log.info({ req: { headers: { authorization: 'Bearer SECRET_TOKEN' } }, text: 'private words', body: { text: 'private words' }, uid: 'u1' }, 'x');
  assert.ok(!out.includes('SECRET_TOKEN'));
  assert.ok(!out.includes('private words'));
  assert.ok(out.includes('u1'));
});

test('kill switch: communityRooms/global.isActive=false closes posting (cached up to 30s)', async () => {
  const e = await createEnv();
  try {
    const u = await e.signup('ks', { established: true });
    assert.equal((await e.api('POST', C, { token: u.token, body: { text: 'open' } })).status, 201);
    await e.db.doc('communityRooms/global').set({ isActive: false }, { merge: true });
    e.clock.ms += 31_000;
    const r = await e.api('POST', C, { token: u.token, body: { text: 'closed' } });
    assert.equal(r.status, 409);
    assert.equal(r.body.error.details.reason, 'room_closed');
  } finally { await e.close(); }
});
