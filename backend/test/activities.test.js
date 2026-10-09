import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createEnv, HOUR } from './helpers/env.js';

let env;
before(async () => { env = await createEnv(); });
after(async () => { await env.close(); });
const A = '/api/v1/activities';

test('create: valid payload creates host member doc and participantCount=1', async () => {
  const host = await env.signup('h1');
  const act = await env.createActivity(host);
  assert.equal(act.participantCount, 1);
  assert.equal(act.hostId, 'h1');
  assert.equal(act.status, 'scheduled');
  assert.equal(act.geohash.length, 9);
  const m = await env.db.doc(`activities/${act.id}/members/h1`).get();
  assert.equal(m.data().role, 'host');
  assert.equal(m.data().status, 'approved');
  const me = await env.db.doc('users/h1').get();
  assert.equal(me.data().stats.hosted, 1);
});

test('create: invalid payloads rejected', async () => {
  const host = await env.signup('h2');
  const bad = async (over, expectPath) => {
    const r = await env.api('POST', A, { token: host.token, body: env.activityBody(over) });
    assert.equal(r.status, 400, JSON.stringify(over));
    assert.equal(r.body.error.code, 'validation_failed');
    if (expectPath) assert.ok(r.body.error.details.some((d) => d.path === expectPath), JSON.stringify(r.body.error.details));
  };
  await bad({ startAt: new Date(env.clock.ms - HOUR).toISOString() }, 'startAt');           // past
  await bad({ endAt: new Date(env.clock.ms + 23 * HOUR).toISOString() }, 'endAt');          // before start
  await bad({ endAt: new Date(env.clock.ms + 24 * HOUR).toISOString() }, 'endAt');          // equals start
  await bad({ capacity: 1 }, 'capacity');
  await bad({ capacity: 51 }, 'capacity');
  await bad({ capacity: 2.5 }, 'capacity');
  await bad({ title: 'ab' }, 'title');
  await bad({ latitude: 95 }, 'latitude');
  await bad({ city: 'delhi' }, 'city');
  await bad({ coverImageUrl: 'http://insecure.example/x.png' }, 'coverImageUrl');
  await bad({ hostId: 'someone-else' });                                                    // unknown/server field
  await bad({ participantCount: 40 });
  const missing = await env.api('POST', A, { token: host.token, body: { title: 'Only a title' } });
  assert.equal(missing.status, 400);
  const noProfile = await env.api('POST', A, { token: env.auth.issue('noprofile'), body: env.activityBody() });
  assert.equal(noProfile.status, 403);
});

test('host limit on upcoming activities', async () => {
  const e2 = await createEnv({ env: { MAX_ACTIVE_HOSTED_ACTIVITIES: '2' } });
  try {
    const h = await e2.signup('hl');
    await e2.createActivity(h); await e2.createActivity(h);
    const r = await e2.api('POST', A, { token: h.token, body: e2.activityBody() });
    assert.equal(r.status, 409);
  } finally { await e2.close(); }
});

test('join: auto-approve, duplicate join conflicts, count stays consistent', async () => {
  const host = await env.signup('h3'); const u = await env.signup('u3');
  const act = await env.createActivity(host);
  const j1 = await env.api('POST', `${A}/${act.id}/join`, { token: u.token });
  assert.equal(j1.status, 200);
  assert.equal(j1.body.data.status, 'approved');
  const j2 = await env.api('POST', `${A}/${act.id}/join`, { token: u.token });
  assert.equal(j2.status, 409);
  assert.equal(j2.body.error.code, 'conflict');
  const hostJoin = await env.api('POST', `${A}/${act.id}/join`, { token: host.token });
  assert.equal(hostJoin.status, 409);
  const got = await env.api('GET', `${A}/${act.id}`, { token: u.token });
  assert.equal(got.body.data.participantCount, 2);
  assert.deepEqual(got.body.data.viewer, { membershipStatus: 'approved', isHost: false });
});

test('join: concurrent duplicate joins by the same user count once', async () => {
  const host = await env.signup('h4'); const u = await env.signup('u4');
  const act = await env.createActivity(host);
  const rs = await Promise.all(Array.from({ length: 8 }, () => env.api('POST', `${A}/${act.id}/join`, { token: u.token })));
  assert.equal(rs.filter((r) => r.status === 200).length, 1);
  assert.equal(rs.filter((r) => r.status === 409).length, 7);
  assert.equal((await env.db.doc(`activities/${act.id}`).get()).data().participantCount, 2);
});

test('capacity enforced sequentially', async () => {
  const host = await env.signup('h5');
  const act = await env.createActivity(host, { capacity: 2 });
  const a = await env.signup('c5a'); const b = await env.signup('c5b');
  assert.equal((await env.api('POST', `${A}/${act.id}/join`, { token: a.token })).status, 200);
  const full = await env.api('POST', `${A}/${act.id}/join`, { token: b.token });
  assert.equal(full.status, 409);
  assert.equal(full.body.error.details.reason, 'full');
});

test('capacity enforced under concurrent joins (optimistic-concurrency fake)', async () => {
  const host = await env.signup('h6');
  const act = await env.createActivity(host, { capacity: 5 });
  const users = await Promise.all(Array.from({ length: 25 }, (_, i) => env.signup(`cj${i}`)));
  const before = env.db.stats.txConflicts;
  const rs = await Promise.all(users.map((u) => env.api('POST', `${A}/${act.id}/join`, { token: u.token })));
  const ok = rs.filter((r) => r.status === 200).length;
  const full = rs.filter((r) => r.status === 409).length;
  assert.equal(ok, 4, 'capacity 5 incl. host leaves exactly 4 seats');
  assert.equal(full, 21);
  const doc = (await env.db.doc(`activities/${act.id}`).get()).data();
  assert.equal(doc.participantCount, 5);
  const approved = await env.db.collection(`activities/${act.id}/members`).where('status', '==', 'approved').get();
  assert.equal(approved.size, 5, 'member docs and counter agree');
  assert.ok(env.db.stats.txConflicts > before, 'transactions really raced and were retried');
});

test('approval flow: requested -> approve/reject, only host may decide', async () => {
  const host = await env.signup('h7'); const u = await env.signup('u7'); const v = await env.signup('v7'); const evil = await env.signup('e7');
  const act = await env.createActivity(host, { approvalRequired: true });
  const j = await env.api('POST', `${A}/${act.id}/join`, { token: u.token });
  assert.equal(j.body.data.status, 'requested');
  await env.api('POST', `${A}/${act.id}/join`, { token: v.token });
  assert.equal((await env.db.doc(`activities/${act.id}`).get()).data().participantCount, 1, 'requests do not consume seats');

  // unauthorized approval
  const asUser = await env.api('POST', `${A}/${act.id}/approve/u7`, { token: evil.token });
  assert.equal(asUser.status, 403);
  const selfApprove = await env.api('POST', `${A}/${act.id}/approve/u7`, { token: u.token });
  assert.equal(selfApprove.status, 403);
  assert.equal((await env.db.doc(`activities/${act.id}/members/u7`).get()).data().status, 'requested');

  assert.equal((await env.api('POST', `${A}/${act.id}/approve/u7`, { token: host.token })).status, 200);
  assert.equal((await env.api('POST', `${A}/${act.id}/approve/u7`, { token: host.token })).status, 409, 'cannot approve twice');
  assert.equal((await env.api('POST', `${A}/${act.id}/reject/v7`, { token: host.token })).status, 200);
  assert.equal((await env.api('POST', `${A}/${act.id}/join`, { token: v.token })).status, 409, 'rejected users cannot re-request');
  assert.equal((await env.db.doc(`activities/${act.id}`).get()).data().participantCount, 2);
  assert.equal((await env.api('POST', `${A}/${act.id}/approve/nobody`, { token: host.token })).status, 404);
});

test('approval respects capacity under concurrent approvals', async () => {
  const host = await env.signup('h8');
  const act = await env.createActivity(host, { approvalRequired: true, capacity: 3 });
  const us = await Promise.all(Array.from({ length: 6 }, (_, i) => env.signup(`ap${i}`)));
  await Promise.all(us.map((u) => env.api('POST', `${A}/${act.id}/join`, { token: u.token })));
  const rs = await Promise.all(us.map((u) => env.api('POST', `${A}/${act.id}/approve/${u.uid}`, { token: host.token })));
  assert.equal(rs.filter((r) => r.status === 200).length, 2);
  assert.equal((await env.db.doc(`activities/${act.id}`).get()).data().participantCount, 3);
});

test('leave and remove keep participantCount consistent; removed users cannot rejoin', async () => {
  const host = await env.signup('h9'); const a = await env.signup('l9a'); const b = await env.signup('l9b');
  const act = await env.createActivity(host);
  await env.api('POST', `${A}/${act.id}/join`, { token: a.token });
  await env.api('POST', `${A}/${act.id}/join`, { token: b.token });
  assert.equal((await env.api('POST', `${A}/${act.id}/leave`, { token: a.token })).status, 200);
  assert.equal((await env.api('POST', `${A}/${act.id}/leave`, { token: a.token })).status, 409);
  assert.equal((await env.api('POST', `${A}/${act.id}/leave`, { token: host.token })).status, 409, 'host cannot leave');
  assert.equal((await env.api('POST', `${A}/${act.id}/remove/l9b`, { token: a.token })).status, 403);
  assert.equal((await env.api('POST', `${A}/${act.id}/remove/l9b`, { token: host.token })).status, 200);
  assert.equal((await env.db.doc(`activities/${act.id}`).get()).data().participantCount, 1);
  assert.equal((await env.api('POST', `${A}/${act.id}/join`, { token: b.token })).status, 403);
  assert.equal((await env.api('POST', `${A}/${act.id}/join`, { token: a.token })).status, 200, 'left users may rejoin');
  assert.equal((await env.db.doc(`activities/${act.id}`).get()).data().participantCount, 2);
});

test('cancel: host only, notifies participants, blocks further joins', async () => {
  const host = await env.signup('h10'); const u = await env.signup('u10'); const w = await env.signup('w10');
  const act = await env.createActivity(host);
  await env.api('POST', `${A}/${act.id}/join`, { token: u.token });
  assert.equal((await env.api('POST', `${A}/${act.id}/cancel`, { token: u.token })).status, 403);
  assert.equal((await env.api('POST', `${A}/${act.id}/cancel`, { token: host.token })).status, 200);
  assert.equal((await env.api('POST', `${A}/${act.id}/join`, { token: w.token })).status, 409);
  const n = await env.db.collection('notifications').where('userId', '==', 'u10').get();
  assert.ok(n.docs.some((d) => d.data().type === 'activity_cancelled'));
});

test('notifications: join request, approve, reject dispatch via FCM and respect prefs', async () => {
  const host = await env.signup('h11'); const u = await env.signup('u11');
  const tok = (c) => `fcm-${c}-`.padEnd(40, 'z');
  await env.api('POST', '/api/v1/users/me/device-tokens', { token: host.token, body: { token: tok('host'), platform: 'ios' } });
  await env.api('POST', '/api/v1/users/me/device-tokens', { token: u.token, body: { token: tok('user'), platform: 'android' } });
  const act = await env.createActivity(host, { approvalRequired: true });
  env.messaging.sent.length = 0;
  await env.api('POST', `${A}/${act.id}/join`, { token: u.token });
  assert.equal(env.messaging.sent.length, 1);
  assert.deepEqual(env.messaging.sent[0].tokens, [tok('host')]);
  assert.equal(env.messaging.sent[0].data.type, 'join_request');
  await env.api('POST', `${A}/${act.id}/approve/u11`, { token: host.token });
  assert.equal(env.messaging.sent.at(-1).data.type, 'join_approved');
  assert.deepEqual(env.messaging.sent.at(-1).tokens, [tok('user')]);
  // opt-out of approvals => in-app doc suppressed too, no push
  await env.api('PUT', '/api/v1/users/me/notification-prefs', { token: u.token, body: { approvals: false } });
  const v = await env.signup('v11');
  await env.api('POST', `${A}/${act.id}/join`, { token: v.token });
  const before = env.messaging.sent.length;
  const w = await env.signup('w11');
  await env.api('POST', `${A}/${act.id}/join`, { token: w.token });
  await env.api('POST', `${A}/${act.id}/reject/w11`, { token: host.token });
  assert.ok(env.messaging.sent.length > before);
  // FCM outage must not fail the API call
  env.messaging.sendEachForMulticast = async () => { throw new Error('fcm down'); };
  const x = await env.signup('x11');
  assert.equal((await env.api('POST', `${A}/${act.id}/join`, { token: x.token })).status, 200);
});

test('GET /:id and members: private activities hidden, requests visible to host only', async () => {
  const host = await env.signup('h12'); const u = await env.signup('u12'); const o = await env.signup('o12');
  const pub = await env.createActivity(host, { approvalRequired: true });
  await env.api('POST', `${A}/${pub.id}/join`, { token: u.token });
  const hostView = await env.api('GET', `${A}/${pub.id}/members`, { token: host.token });
  assert.equal(hostView.body.data.length, 2);
  const otherView = await env.api('GET', `${A}/${pub.id}/members`, { token: o.token });
  assert.equal(otherView.body.data.length, 1);
  assert.ok(!JSON.stringify(otherView.body).includes('u12'));

  const priv = await env.createActivity(host, { visibility: 'private' });
  assert.equal((await env.api('GET', `${A}/${priv.id}`, { token: o.token })).status, 404);
  const j = await env.api('POST', `${A}/${priv.id}/join`, { token: o.token });
  assert.equal(j.body.data.status, 'requested', 'private activities always need approval');
  assert.equal((await env.api('GET', `${A}/${priv.id}`, { token: o.token })).status, 200);
  const list = await env.api('GET', A, { token: u.token });
  assert.ok(!list.body.data.some((a) => a.id === priv.id));
});

test('PATCH: host only, capacity cannot drop below participants, time rules re-validated', async () => {
  const host = await env.signup('h13'); const u = await env.signup('u13');
  const act = await env.createActivity(host, { capacity: 5 });
  await env.api('POST', `${A}/${act.id}/join`, { token: u.token });
  assert.equal((await env.api('PATCH', `${A}/${act.id}`, { token: u.token, body: { title: 'Hijack' } })).status, 403);
  assert.equal((await env.api('PATCH', `${A}/${act.id}`, { token: host.token, body: { capacity: 1 } })).status, 400);
  assert.equal((await env.api('PATCH', `${A}/${act.id}`, { token: host.token, body: { capacity: 2 } })).status, 200);
  assert.equal((await env.api('PATCH', `${A}/${act.id}`, { token: host.token, body: { capacity: 2 + 0.5 } })).status, 400);
  assert.equal((await env.api('PATCH', `${A}/${act.id}`, { token: host.token, body: { capacity: 3 } })).status, 200);
  assert.equal((await env.api('PATCH', `${A}/${act.id}`, { token: host.token, body: { startAt: new Date(env.clock.ms - HOUR).toISOString() } })).status, 400);
  assert.equal((await env.api('PATCH', `${A}/${act.id}`, { token: host.token, body: { hostId: 'x' } })).status, 400);
  const moved = await env.api('PATCH', `${A}/${act.id}`, { token: host.token, body: { latitude: 18.52, longitude: 73.85 } });
  assert.equal(moved.status, 200);
  assert.notEqual(moved.body.data.geohash, act.geohash);
  const n = await env.db.collection('notifications').where('userId', '==', 'u13').get();
  assert.ok(n.docs.some((d) => d.data().type === 'activity_updated'));
});

test('list: filters, pagination cursor, free/minSpots/q', async () => {
  const e = await createEnv();
  try {
    const host = await e.signup('lh');
    const mk = (i, over = {}) => e.createActivity(host, {
      title: `Event ${i}`, startAt: new Date(e.clock.ms + (i + 1) * HOUR).toISOString(), endAt: new Date(e.clock.ms + (i + 2) * HOUR).toISOString(), ...over,
    });
    await e.db.doc('users/lh').update({ stats: { hosted: 0, attended: 0 } });
    const e2 = await createEnv({ env: { MAX_ACTIVE_HOSTED_ACTIVITIES: '100' } });
    await e2.close();
    // seed directly to dodge the per-host cap
    for (let i = 0; i < 7; i++) {
      const a = await mk(i % 5 === 0 ? 0 : i, { category: i % 2 ? 'food' : 'fitness', city: i < 4 ? 'mumbai' : 'pune', costType: i === 2 ? 'paid' : 'free', capacity: i === 3 ? 2 : 10 });
      assert.ok(a.id);
    }
    const reader = await e.signup('lr');
    const page1 = await e.api('GET', `${A}?limit=3`, { token: reader.token });
    assert.equal(page1.body.data.length, 3);
    assert.ok(page1.body.nextCursor);
    const page2 = await e.api('GET', `${A}?limit=3&cursor=${page1.body.nextCursor}`, { token: reader.token });
    const page3 = await e.api('GET', `${A}?limit=3&cursor=${page2.body.nextCursor}`, { token: reader.token });
    const ids = [...page1.body.data, ...page2.body.data, ...page3.body.data].map((a) => a.id);
    assert.equal(ids.length, 7);
    assert.equal(new Set(ids).size, 7);
    assert.equal(page3.body.nextCursor, null);
    const starts = [...page1.body.data, ...page2.body.data, ...page3.body.data].map((a) => a.startAt);
    assert.deepEqual(starts, [...starts].sort());
    const pune = await e.api('GET', `${A}?city=pune`, { token: reader.token });
    assert.ok(pune.body.data.length > 0 && pune.body.data.every((a) => a.city === 'pune'));
    const food = await e.api('GET', `${A}?category=food&city=mumbai`, { token: reader.token });
    assert.ok(food.body.data.every((a) => a.category === 'food' && a.city === 'mumbai'));
    const free = await e.api('GET', `${A}?free=true`, { token: reader.token });
    assert.ok(free.body.data.every((a) => a.costType === 'free'));
    const spots = await e.api('GET', `${A}?minSpots=5`, { token: reader.token });
    assert.ok(spots.body.data.every((a) => a.capacity - a.participantCount >= 5));
    const q = await e.api('GET', `${A}?q=event%203`, { token: reader.token });
    assert.equal(q.body.data.length, 1);
    assert.equal((await e.api('GET', `${A}?limit=500`, { token: reader.token })).status, 400);
    assert.equal((await e.api('GET', `${A}?cursor=%%%bad`, { token: reader.token })).status, 400);
    assert.equal((await e.api('GET', `${A}?sort=proximity`, { token: reader.token })).status, 400);
  } finally { await e.close(); }
});

test('nearby: geohash cover + haversine post-filter, distance sort, map markers', async () => {
  const e = await createEnv({ env: { MAX_ACTIVE_HOSTED_ACTIVITIES: '100' } });
  try {
    const host = await e.signup('gh');
    const spots = {
      near: [19.0760, 72.8777],      // Mumbai centre (query origin)
      bandra: [19.0596, 72.8295],    // ~5.4 km
      thane: [19.2183, 72.9781],     // ~20 km
      pune: [18.5204, 73.8567],      // ~120 km
    };
    const made = {};
    for (const [k, [la, ln]] of Object.entries(spots)) made[k] = await e.createActivity(host, { title: `At ${k}`, latitude: la, longitude: ln, city: k === 'pune' ? 'pune' : 'mumbai' });
    const r = await e.api('GET', `${A}?lat=19.076&lng=72.8777&radiusKm=10`, { token: host.token });
    assert.equal(r.status, 200);
    assert.deepEqual(r.body.data.map((a) => a.id), [made.near.id, made.bandra.id]);
    assert.ok(r.body.data[0].distanceKm < 0.1);
    assert.ok(r.body.data[1].distanceKm > 4 && r.body.data[1].distanceKm < 7);
    const wide = await e.api('GET', `${A}?lat=19.076&lng=72.8777&radiusKm=30&sort=proximity`, { token: host.token });
    assert.deepEqual(wide.body.data.map((a) => a.id), [made.near.id, made.bandra.id, made.thane.id]);
    // pagination over the merged ordering
    const p1 = await e.api('GET', `${A}?lat=19.076&lng=72.8777&radiusKm=30&limit=2`, { token: host.token });
    assert.equal(p1.body.data.length, 2);
    const p2 = await e.api('GET', `${A}?lat=19.076&lng=72.8777&radiusKm=30&limit=2&cursor=${p1.body.nextCursor}`, { token: host.token });
    assert.deepEqual([...p1.body.data, ...p2.body.data].map((a) => a.id), wide.body.data.map((a) => a.id));
    assert.equal(p2.body.nextCursor, null);
    const none = await e.api('GET', `${A}?lat=28.6&lng=77.2&radiusKm=10`, { token: host.token });
    assert.equal(none.body.data.length, 0);
    const map = await e.api('GET', `${A}/map?lat=19.076&lng=72.8777&radiusKm=10`, { token: host.token });
    assert.equal(map.status, 200);
    assert.equal(map.body.data.length, 2);
    assert.deepEqual(Object.keys(map.body.data[0]).sort(), ['category', 'city', 'costType', 'distanceKm', 'id', 'latitude', 'longitude', 'spotsLeft', 'startAt', 'title']);
    assert.equal((await e.api('GET', `${A}/map?radiusKm=10`, { token: host.token })).status, 400);
  } finally { await e.close(); }
});

test('scheduled jobs: protected by secret header; reminders are idempotent; completion', async () => {
  const e = await createEnv();
  try {
    const host = await e.signup('jh'); const u = await e.signup('ju');
    const act = await e.createActivity(host, {
      startAt: new Date(e.clock.ms + 30 * 60_000).toISOString(), endAt: new Date(e.clock.ms + 90 * 60_000).toISOString(),
    });
    await e.api('POST', `${A}/${act.id}/join`, { token: u.token });
    assert.equal((await e.api('POST', '/api/v1/internal/jobs/reminders')).status, 401);
    assert.equal((await e.api('POST', '/api/v1/internal/jobs/reminders', { headers: { 'x-cron-secret': 'wrong' } })).status, 401);
    assert.equal((await e.api('POST', '/api/v1/internal/jobs/reminders', { token: u.token })).status, 401, 'a user token is not enough');
    const h = { 'x-cron-secret': e.config.cronSecret };
    const r1 = await e.api('POST', '/api/v1/internal/jobs/reminders', { headers: h });
    assert.equal(r1.body.data.activitiesReminded, 1);
    const r2 = await e.api('POST', '/api/v1/internal/jobs/reminders', { headers: h });
    assert.equal(r2.body.data.activitiesReminded, 0);
    const n = await e.db.collection('notifications').where('type', '==', 'reminder').get();
    assert.equal(n.size, 2);
    e.clock.ms += 3 * HOUR;
    const c = await e.api('POST', '/api/v1/internal/jobs/complete-ended', { headers: h });
    assert.equal(c.body.data.completed, 1);
    assert.equal((await e.db.doc(`activities/${act.id}`).get()).data().status, 'completed');
    const disabled = await createEnv({ env: { CRON_SECRET: '' } });
    assert.equal((await disabled.api('POST', '/api/v1/internal/jobs/reminders', { headers: { 'x-cron-secret': '' } })).status, 404);
    await disabled.close();
  } finally { await e.close(); }
});
