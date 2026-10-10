import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { Timestamp } from 'firebase-admin/firestore';
import { createEnv, HOUR } from './helpers/env.js';

let env;
before(async () => { env = await createEnv(); });
after(async () => { await env.close(); });
const U = '/api/v1/users';
const A = '/api/v1/activities';
const j = (m, p, u, body) => env.api(m, p, { token: u.token, body });

// ------------------------------------------------------------------ profile extras
test('profile extras: countryCode uppercased, instagram @ stripped, nullable, validated, public', async () => {
  const u = await env.signup('s-p1'); const o = await env.signup('s-p2');
  const ok = await j('PATCH', `${U}/me`, u, { countryCode: 'in', instagram: '@nomad.asha_1' });
  assert.equal(ok.status, 200);
  assert.equal(ok.body.data.countryCode, 'IN');
  assert.equal(ok.body.data.instagram, 'nomad.asha_1');
  const pub = await j('GET', `${U}/s-p1`, o);
  assert.equal(pub.body.data.countryCode, 'IN');
  assert.equal(pub.body.data.instagram, 'nomad.asha_1');
  for (const bad of [{ countryCode: 'IND' }, { countryCode: '1A' }, { instagram: 'a b' }, { instagram: '@' }, { instagram: 'x'.repeat(31) }]) {
    assert.equal((await j('PATCH', `${U}/me`, u, bad)).status, 400, JSON.stringify(bad));
  }
  const cleared = await j('PATCH', `${U}/me`, u, { countryCode: null, instagram: null });
  assert.equal(cleared.body.data.countryCode, null);
  assert.equal(cleared.body.data.instagram, null);
  const put = await j('PUT', `${U}/me`, u, { displayName: 'Asha', city: 'pune', countryCode: 'us' });
  assert.equal(put.body.data.countryCode, 'US');
});

// ------------------------------------------------------------------ travelers
test('location: validates, stores approx only, removes on discoverable=false, survives profile edit', async () => {
  const u = await env.signup('s-l1');
  assert.equal((await env.api('PUT', `${U}/me/location`, { body: {} })).status, 401);
  assert.equal((await env.api('PUT', `${U}/me/location`, { token: env.auth.issue('s-noprof'), body: { lat: 1, lng: 1, discoverable: true } })).status, 403);
  for (const bad of [{ lat: 91, lng: 0, discoverable: true }, { lat: 0, lng: 181, discoverable: true }, { lat: 0, lng: 0 }, { lat: 0, lng: 0, discoverable: true, x: 1 }]) {
    assert.equal((await j('PUT', `${U}/me/location`, u, bad)).status, 400, JSON.stringify(bad));
  }
  const r = await j('PUT', `${U}/me/location`, u, { lat: 19.07612, lng: 72.87771, discoverable: true });
  assert.equal(r.status, 200);
  const doc = (await env.db.doc('users/s-l1').get()).data();
  assert.equal(doc.discoverable, true);
  assert.equal(doc.approxLat, 19.08);
  assert.equal(doc.approxLng, 72.88);
  assert.ok(doc.locationUpdatedAt);
  assert.ok(!JSON.stringify(doc).includes('19.07612'));
  const me = await j('GET', `${U}/me`, u);
  assert.ok(!('approxLat' in me.body.data) && !JSON.stringify(me.body).includes('72.88'));
  const pub = await j('GET', `${U}/s-l1`, await env.signup('s-l1b'));
  assert.ok(!JSON.stringify(pub.body).includes('approx'));

  await j('PATCH', `${U}/me`, u, { bio: 'hi' });
  assert.equal((await env.db.doc('users/s-l1').get()).data().approxLat, 19.08);

  await j('PUT', `${U}/me/location`, u, { lat: 19.07, lng: 72.87, discoverable: false });
  const off = (await env.db.doc('users/s-l1').get()).data();
  assert.equal(off.discoverable, false);
  assert.ok(!('approxLat' in off) && !('approxLng' in off) && !('locationUpdatedAt' in off));
});

test('travelers: filters, distance sort, rounding, blocks both ways, staleness, radius, pagination', async () => {
  const me = await env.signup('s-t0');
  const mk = async (uid, lat, lng, extra = {}) => {
    const u = await env.signup(uid);
    await j('PATCH', `${U}/me`, u, { countryCode: 'fr' });
    await j('PUT', `${U}/me/location`, u, { lat, lng, discoverable: true });
    if (Object.keys(extra).length) await env.db.doc(`users/${uid}`).update(extra);
    return u;
  };
  await j('PUT', `${U}/me/location`, me, { lat: 19.0, lng: 72.8, discoverable: true });
  await mk('s-t1', 19.01, 72.81);
  await mk('s-t2', 19.1, 72.9);
  await mk('s-far', 28.6, 77.2); // Delhi
  await mk('s-susp', 19.02, 72.82, { accountStatus: 'suspended' });
  await mk('s-stale', 19.02, 72.82, { locationUpdatedAt: Timestamp.fromMillis(env.clock.ms - 31 * 24 * HOUR) });
  const hidden = await mk('s-hid', 19.03, 72.83);
  await j('PUT', `${U}/me/location`, hidden, { lat: 19.03, lng: 72.83, discoverable: false });
  await mk('s-blk-by-me', 19.02, 72.8);
  await mk('s-blk-me', 19.03, 72.8);
  await j('POST', `${U}/s-blk-by-me/block`, me);
  assert.equal((await j('POST', `${U}/s-t0/block`, { token: env.auth.issue('s-blk-me') })).status, 201);

  const r = await j('GET', `${U}/travelers?lat=19&lng=72.8`, me);
  assert.equal(r.status, 200);
  assert.deepEqual(r.body.data.map((x) => x.uid), ['s-t1', 's-t2']);
  assert.deepEqual(Object.keys(r.body.data[0]).sort(), ['city', 'countryCode', 'displayName', 'distanceKm', 'photoUrl', 'uid']);
  assert.equal(r.body.data[0].countryCode, 'FR');
  assert.equal(r.body.data[0].distanceKm, Math.round(r.body.data[0].distanceKm * 10) / 10);
  assert.ok(r.body.data[0].distanceKm < r.body.data[1].distanceKm);
  assert.equal(r.body.nextCursor, null);
  assert.ok(!JSON.stringify(r.body).includes('approx'));

  const small = await j('GET', `${U}/travelers?lat=19&lng=72.8&radiusKm=1`, me);
  assert.deepEqual(small.body.data.map((x) => x.uid), []);
  const big = await j('GET', `${U}/travelers?lat=19&lng=72.8&radiusKm=100`, me);
  assert.ok(!big.body.data.some((x) => x.uid === 's-far'));

  const p1 = await j('GET', `${U}/travelers?lat=19&lng=72.8&limit=1`, me);
  assert.deepEqual(p1.body.data.map((x) => x.uid), ['s-t1']);
  assert.ok(p1.body.nextCursor);
  const p2 = await j('GET', `${U}/travelers?lat=19&lng=72.8&limit=1&cursor=${p1.body.nextCursor}`, me);
  assert.deepEqual(p2.body.data.map((x) => x.uid), ['s-t2']);
  assert.equal(p2.body.nextCursor, null);
});

test('travelers: validation and auth; route is not shadowed by /:uid', async () => {
  const u = await env.signup('s-tv');
  assert.equal((await env.api('GET', `${U}/travelers?lat=1&lng=1`)).status, 401);
  for (const q of ['', 'lat=1', 'lat=abc&lng=1', 'lat=91&lng=1', 'lat=1&lng=1&radiusKm=101', 'lat=1&lng=1&radiusKm=0', 'lat=1&lng=1&limit=51', 'lat=1&lng=1&cursor=!!!']) {
    assert.equal((await j('GET', `${U}/travelers?${q}`, u)).status, 400, q);
  }
  assert.equal((await j('GET', `${U}/travelers?lat=1&lng=1`, u)).status, 200);
});

test('travelers: users who blocked the caller are excluded', async () => {
  const me = await env.signup('s-tb0'); const b = await env.signup('s-tb1'); const ok = await env.signup('s-tb2');
  for (const u of [me, b, ok]) await j('PUT', `${U}/me/location`, u, { lat: 12.97, lng: 77.59, discoverable: true });
  await j('POST', `${U}/s-tb0/block`, b);
  const r = await j('GET', `${U}/travelers?lat=12.97&lng=77.59`, me);
  assert.deepEqual(r.body.data.map((x) => x.uid), ['s-tb2']);
});

// ------------------------------------------------------------------ friends
test('friends: request -> pending views -> accept -> lists -> unfriend, with notifications', async () => {
  const a = await env.signup('s-f1', { name: 'Asha' }); const b = await env.signup('s-f2', { name: 'Ben' });
  await j('PATCH', `${U}/me`, b, { countryCode: 'gb' });
  assert.equal((await j('GET', `${U}/s-f2`, a)).body.data.friendship, 'none');
  const r = await j('POST', `${U}/s-f2/friend-request`, a);
  assert.equal(r.status, 201);
  assert.deepEqual(r.body.data, { friendship: 'request_sent' });
  const f = (await env.db.doc('friendships/s-f1_s-f2').get()).data();
  assert.deepEqual(f.users, ['s-f1', 's-f2']);
  assert.equal(f.requesterId, 's-f1'); assert.equal(f.status, 'pending');
  assert.equal((await j('GET', `${U}/s-f2`, a)).body.data.friendship, 'request_sent');
  assert.equal((await j('GET', `${U}/s-f1`, b)).body.data.friendship, 'request_received');

  const n = await env.db.collection('notifications').where('userId', '==', 's-f2').get();
  assert.equal(n.docs[0].data().type, 'friend_request');
  assert.equal(n.docs[0].data().data.actorId, 's-f1');
  assert.equal(n.docs[0].data().data.actorName, 'Asha');
  assert.equal(n.docs[0].data().data.actorPhotoUrl, null);

  assert.equal((await j('POST', `${U}/s-f2/friend-request`, a)).status, 409, 'duplicate');
  const inc = await j('GET', `${U}/me/friend-requests`, b);
  assert.deepEqual(inc.body.data.map((x) => x.uid), ['s-f1']);
  assert.equal(inc.body.data[0].displayName, 'Asha');
  assert.deepEqual((await j('GET', `${U}/me/friend-requests`, a)).body.data, [], 'outgoing not listed');
  assert.deepEqual((await j('GET', `${U}/me/friends`, b)).body.data, []);

  assert.equal((await j('POST', `${U}/s-f2/friend-request/accept`, a)).status, 403, 'requester cannot accept');
  const acc = await j('POST', `${U}/s-f1/friend-request/accept`, b);
  assert.equal(acc.status, 200);
  assert.deepEqual(acc.body.data, { friendship: 'friends' });
  assert.equal((await j('POST', `${U}/s-f1/friend-request/accept`, b)).status, 409);
  const n2 = await env.db.collection('notifications').where('userId', '==', 's-f1').get();
  assert.equal(n2.docs[0].data().type, 'friend_accepted');
  assert.equal(n2.docs[0].data().data.actorName, 'Ben');
  assert.equal((await j('POST', `${U}/s-f1/friend-request`, b)).status, 409);
  assert.equal((await j('GET', `${U}/s-f1`, b)).body.data.friendship, 'friends');

  const la = await j('GET', `${U}/me/friends`, a);
  assert.deepEqual(la.body.data, [{ uid: 's-f2', displayName: 'Ben', photoUrl: null, countryCode: 'GB' }]);
  assert.equal(la.body.nextCursor, null);
  assert.equal((await j('GET', `${U}/me/friends?limit=0`, a)).status, 400);

  const del = await j('DELETE', `${U}/s-f1/friend`, b);
  assert.deepEqual(del.body.data, { friendship: 'none' });
  assert.deepEqual((await j('GET', `${U}/me/friends`, a)).body.data, []);
  assert.equal((await j('GET', `${U}/s-f2`, a)).body.data.friendship, 'none');
  assert.equal((await j('DELETE', `${U}/s-f1/friend`, b)).status, 200, 'idempotent');
});

test('friends: auto-accept on mutual request, decline, cancel, self/unknown/blocked, no-request accept, pagination', async () => {
  const a = await env.signup('s-g1'); const b = await env.signup('s-g2'); const c = await env.signup('s-g3');
  assert.equal((await j('POST', `${U}/s-g1/friend-request`, a)).status, 400, 'self');
  assert.equal((await j('POST', `${U}/nobody-here/friend-request`, a)).status, 404);
  assert.equal((await j('POST', `${U}/s-g1/friend-request/accept`, b)).status, 404);
  assert.equal((await env.api('POST', `${U}/s-g2/friend-request`)).status, 401);
  assert.equal((await env.api('POST', `${U}/s-g2/friend-request`, { token: env.auth.issue('s-g-np') })).status, 403);

  await j('POST', `${U}/s-g2/friend-request`, a);
  const auto = await j('POST', `${U}/s-g1/friend-request`, b);
  assert.equal(auto.status, 200);
  assert.deepEqual(auto.body.data, { friendship: 'friends' });
  assert.equal((await env.db.doc('friendships/s-g1_s-g2').get()).data().status, 'accepted');
  assert.equal((await env.db.collection('notifications').where('userId', '==', 's-g1').get()).docs[0].data().type, 'friend_accepted');

  // decline & cancel
  await j('POST', `${U}/s-g3/friend-request`, a);
  assert.equal((await j('DELETE', `${U}/s-g1/friend`, c)).status, 200);
  assert.equal((await env.db.doc('friendships/s-g1_s-g3').get()).exists, false);
  await j('POST', `${U}/s-g3/friend-request`, a);
  await j('DELETE', `${U}/s-g3/friend`, a);
  assert.equal((await env.db.doc('friendships/s-g1_s-g3').get()).exists, false);

  // blocked either way -> 403; blocking removes friendship
  await j('POST', `${U}/s-g1/block`, b);
  assert.equal((await env.db.doc('friendships/s-g1_s-g2').get()).exists, false);
  assert.equal((await j('POST', `${U}/s-g2/friend-request`, a)).status, 403);
  assert.equal((await j('POST', `${U}/s-g1/friend-request`, b)).status, 403);

  // pagination
  const hub = await env.signup('s-hub');
  for (const n of ['s-h1', 's-h2', 's-h3']) {
    const u = await env.signup(n);
    await j('POST', `${U}/s-hub/friend-request`, u);
    env.clock.ms += 1000;
    await j('POST', `${U}/${n}/friend-request/accept`, hub);
  }
  const p1 = await j('GET', `${U}/me/friends?limit=2`, hub);
  assert.equal(p1.body.data.length, 2);
  assert.ok(p1.body.nextCursor);
  const p2 = await j('GET', `${U}/me/friends?limit=2&cursor=${p1.body.nextCursor}`, hub);
  assert.equal(p2.body.data.length, 1);
  assert.equal(p2.body.nextCursor, null);
  assert.equal(new Set([...p1.body.data, ...p2.body.data].map((x) => x.uid)).size, 3);
  assert.equal((await j('GET', `${U}/me/friends?cursor=!!!`, hub)).status, 400);
});

test('friends: friends pref off suppresses notification; prefs include friends default', async () => {
  const a = await env.signup('s-n1'); const b = await env.signup('s-n2');
  assert.equal((await j('GET', `${U}/me`, a)).body.data.private.notificationPrefs.friends, true);
  const p = await j('PUT', `${U}/me/notification-prefs`, b, { friends: false });
  assert.equal(p.body.data.friends, false);
  assert.equal((await j('PUT', `${U}/me/notification-prefs`, b, { friends: 'no' })).status, 400);
  await j('POST', `${U}/s-n2/friend-request`, a);
  assert.equal((await env.db.collection('notifications').where('userId', '==', 's-n2').get()).size, 0);
  assert.ok((await env.db.doc('friendships/s-n1_s-n2').get()).exists);
});

test('friends: pending outgoing request cap -> 429', async () => {
  const a = await env.signup('s-cap');
  for (let i = 0; i < 100; i++) {
    await env.db.doc(`friendships/cap_x${i}`).set({ users: ['s-cap', `x${i}`], requesterId: 's-cap', status: 'pending' });
  }
  await env.signup('s-cap-t');
  const r = await j('POST', `${U}/s-cap-t/friend-request`, a);
  assert.equal(r.status, 429);
  assert.equal(r.body.error.code, 'rate_limited');
});

test('account deletion removes friendships', async () => {
  const a = await env.signup('s-d1'); const b = await env.signup('s-d2');
  await j('POST', `${U}/s-d2/friend-request`, a);
  await j('POST', `${U}/s-d1/friend-request/accept`, b);
  assert.equal((await j('DELETE', `${U}/me`, a)).status, 200);
  assert.equal((await env.db.doc('friendships/s-d1_s-d2').get()).exists, false);
  assert.deepEqual((await j('GET', `${U}/me/friends`, b)).body.data, []);
});

// ------------------------------------------------------------------ notification actors
test('join notifications carry actorId/actorName/actorPhotoUrl', async () => {
  const host = await env.signup('s-ah', { name: 'Hosty' }); const u = await env.signup('s-au', { name: 'Joiner' });
  const act = await env.createActivity(host, { approvalRequired: true });
  await j('POST', `${A}/${act.id}/join`, u);
  const req = (await env.db.collection('notifications').where('userId', '==', 's-ah').get()).docs[0].data();
  assert.equal(req.type, 'join_request');
  assert.deepEqual([req.data.actorId, req.data.actorName, req.data.actorPhotoUrl], ['s-au', 'Joiner', null]);
  await j('POST', `${A}/${act.id}/approve/s-au`, host);
  const appr = (await env.db.collection('notifications').where('userId', '==', 's-au').get()).docs[0].data();
  assert.equal(appr.type, 'join_approved');
  assert.deepEqual([appr.data.actorId, appr.data.actorName], ['s-ah', 'Hosty']);
});

// ------------------------------------------------------------------ private attendees
test('private plan: only host entry for non-members/requesters; full list for host and approved members', async () => {
  const host = await env.signup('s-ph'); const m = await env.signup('s-pm'); const r = await env.signup('s-pr');
  const priv = await env.createActivity(host, { visibility: 'private' });
  await j('POST', `${A}/${priv.id}/join`, m);
  await j('POST', `${A}/${priv.id}/join`, r);
  await j('POST', `${A}/${priv.id}/approve/s-pm`, host);

  const asRequester = await j('GET', `${A}/${priv.id}/members`, r);
  assert.equal(asRequester.status, 200);
  assert.deepEqual(asRequester.body.data.map((x) => [x.uid, x.role]), [['s-ph', 'host']]);
  const asMember = await j('GET', `${A}/${priv.id}/members`, m);
  assert.deepEqual(asMember.body.data.map((x) => x.uid).sort(), ['s-ph', 's-pm']);
  const asHost = await j('GET', `${A}/${priv.id}/members`, host);
  assert.equal(asHost.body.data.length, 3);
  const detail = await j('GET', `${A}/${priv.id}`, r);
  assert.equal(detail.body.data.participantCount, 2);
  // unrelated user still cannot see it at all
  assert.equal((await j('GET', `${A}/${priv.id}/members`, await env.signup('s-px'))).status, 404);
});

test('profile photos: up to 6 https urls, public, replaceable', async () => {
  const u = await env.signup('s-ph1'); const o = await env.signup('s-ph2');
  const urls = ['https://x.test/a.jpg', 'https://x.test/b.jpg'];
  const ok = await j('PATCH', `${U}/me`, u, { photos: urls });
  assert.equal(ok.status, 200);
  assert.deepEqual(ok.body.data.photos, urls);
  assert.deepEqual((await j('GET', `${U}/s-ph1`, o)).body.data.photos, urls);
  assert.equal((await j('PATCH', `${U}/me`, u, { photos: Array(7).fill(urls[0]) })).status, 400);
  assert.equal((await j('PATCH', `${U}/me`, u, { photos: ['http://x.test/a.jpg'] })).status, 400);
  // The last image cannot be removed; with an avatar present the gallery may be emptied.
  assert.equal((await j('PATCH', `${U}/me`, u, { photos: [] })).status, 400);
  await j('PATCH', `${U}/me`, u, { photoUrl: 'https://x.test/me.jpg' });
  assert.deepEqual((await j('PATCH', `${U}/me`, u, { photos: [] })).body.data.photos, []);
  assert.deepEqual((await j('PATCH', `${U}/me`, u, { bio: 'hi' })).body.data.photos, []);
});

test('profile photos: cannot remove the last image, can swap avatar for gallery', async () => {
  const u = await env.signup('s-ph3');
  await j('PATCH', `${U}/me`, u, { photoUrl: 'https://x.test/me.jpg' });
  const r1 = await j('PATCH', `${U}/me`, u, { photoUrl: null });
  assert.equal(r1.status, 400);
  assert.equal((await j('PATCH', `${U}/me`, u, { photos: ['https://x.test/g.jpg'] })).status, 200);
  assert.equal((await j('PATCH', `${U}/me`, u, { photoUrl: null })).status, 200);
  assert.equal((await j('PATCH', `${U}/me`, u, { photos: [] })).status, 400);
});
