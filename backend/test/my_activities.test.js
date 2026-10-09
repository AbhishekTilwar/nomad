import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createEnv, HOUR } from './helpers/env.js';

let env;
before(async () => { env = await createEnv(); });
after(async () => { await env.close(); });
const ME = '/api/v1/users/me/activities';
const A = '/api/v1/activities';
const iso = (h) => new Date(env.clock.ms + h * HOUR).toISOString();

test('requires auth and a profile; validates query', async () => {
  assert.equal((await env.api('GET', ME)).status, 401);
  assert.equal((await env.api('GET', ME, { token: env.auth.issue('noprof') })).status, 403);
  const u = await env.signup('ma0');
  assert.equal((await env.api('GET', `${ME}?role=bogus`, { token: u.token })).status, 400);
  assert.equal((await env.api('GET', `${ME}?limit=0`, { token: u.token })).status, 400);
  assert.equal((await env.api('GET', `${ME}?cursor=!!!`, { token: u.token })).status, 400);
});

test('hosted / joined / past split, ordering, viewer, lastMessage', async () => {
  const host = await env.signup('ma-h'); const u = await env.signup('ma-u'); const other = await env.signup('ma-o');
  const a1 = await env.createActivity(host, { startAt: iso(48), endAt: iso(49), title: 'Later one' });
  const a2 = await env.createActivity(host, { startAt: iso(24), endAt: iso(25), title: 'Sooner one' });
  const a3 = await env.createActivity(other, { title: 'Not mine' });
  const a4 = await env.createActivity(other, { title: 'Joined one', startAt: iso(30), endAt: iso(31) });
  const a5 = await env.createActivity(other, { title: 'Requested only', approvalRequired: true });
  await env.api('POST', `${A}/${a4.id}/join`, { token: u.token });
  await env.api('POST', `${A}/${a5.id}/join`, { token: host.token });
  const pm = await env.api('POST', `${A}/${a2.id}/messages`, { token: host.token, body: { text: 'see you', clientMessageId: 'client-msg-1' } });
  assert.equal(pm.status, 201, JSON.stringify(pm.body));

  const hosted = await env.api('GET', `${ME}?role=hosted`, { token: host.token });
  assert.equal(hosted.status, 200);
  assert.deepEqual(hosted.body.data.map((x) => x.id), [a2.id, a1.id]);
  assert.equal(hosted.body.data[0].viewer.isHost, true);
  assert.equal(hosted.body.data[0].lastMessage.text, 'see you');
  assert.equal(hosted.body.data[0].lastMessage.senderName, 'User ma-h');
  assert.equal(hosted.body.data[1].lastMessage, undefined);
  assert.equal(hosted.body.data[0].reminderSentAt, undefined);
  assert.deepEqual(hosted.body.data[0].participants.map((p) => p.uid), ['ma-h']);
  assert.equal(hosted.body.data[0].participants[0].displayName, 'User ma-h');
  assert.equal(hosted.body.nextCursor, null);

  const joined = await env.api('GET', `${ME}?role=joined`, { token: u.token });
  assert.deepEqual(joined.body.data.map((x) => x.id), [a4.id]);
  assert.equal(joined.body.data[0].viewer.isHost, false);
  // default role is joined; requested-only memberships are excluded; hosts' hosted not in joined
  const hostJoined = await env.api('GET', ME, { token: host.token });
  assert.deepEqual(hostJoined.body.data, []);
  assert.ok(!hosted.body.data.some((x) => x.id === a3.id));

  // cancel a1 -> moves to past for the host and not in hosted
  await env.api('POST', `${A}/${a1.id}/cancel`, { token: host.token });
  const h2 = await env.api('GET', `${ME}?role=hosted`, { token: host.token });
  assert.deepEqual(h2.body.data.map((x) => x.id), [a2.id]);
  const past = await env.api('GET', `${ME}?role=past`, { token: host.token });
  assert.deepEqual(past.body.data.map((x) => x.id), [a1.id]);

  // time passes -> everything ended
  env.clock.ms += 100 * HOUR;
  const past2 = await env.api('GET', `${ME}?role=past`, { token: u.token });
  assert.deepEqual(past2.body.data.map((x) => x.id), [a4.id]);
});

test('pagination with cursor', async () => {
  const h = await env.signup('ma-page');
  const ids = [];
  for (let i = 0; i < 3; i++) ids.push((await env.createActivity(h, { startAt: iso(60 + i), endAt: iso(61 + i), title: `Page ${i}` })).id);
  const p1 = await env.api('GET', `${ME}?role=hosted&limit=2`, { token: h.token });
  assert.deepEqual(p1.body.data.map((x) => x.id), ids.slice(0, 2));
  assert.ok(p1.body.nextCursor);
  const p2 = await env.api('GET', `${ME}?role=hosted&limit=2&cursor=${p1.body.nextCursor}`, { token: h.token });
  assert.deepEqual(p2.body.data.map((x) => x.id), ids.slice(2));
  assert.equal(p2.body.nextCursor, null);
});
