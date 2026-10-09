// Integration smoke test against the REAL Firestore + Auth emulators (Admin SDK, real transactions,
// real query planner for the geohash multi-inequality query). Run via `npm run test:emulator`
// from /backend (it wraps firebase emulators:exec in ../firebase; needs JDK 21+).
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import { createApp } from '../src/app.js';
import { loadConfig } from '../src/config/env.js';
import { createLogger } from '../src/lib/logger.js';
import { createFirebaseDeps } from '../src/lib/firebase.js';

const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const PROJECT = 'demo-nomadmingle';
let server; let base;

before(async () => {
  assert.ok(process.env.FIRESTORE_EMULATOR_HOST && authHost, 'run inside firebase emulators:exec');
  const config = loadConfig({ NODE_ENV: 'test', FIREBASE_PROJECT_ID: PROJECT, LOG_LEVEL: 'silent', MAX_ACTIVE_HOSTED_ACTIVITIES: '50' });
  const app = createApp({ ...createFirebaseDeps(config), config, logger: createLogger('silent') });
  server = http.createServer(app);
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  base = `http://127.0.0.1:${server.address().port}`;
});
after(async () => { await new Promise((r) => server.close(r)); });

async function newUser(email) {
  const r = await fetch(`http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake`, {
    method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ email, password: 'password123', returnSecureToken: true }),
  });
  const j = await r.json();
  return { uid: j.localId, token: j.idToken };
}
async function api(method, path, { token, body } = {}) {
  const res = await fetch(base + path, { method, headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) }, body: body ? JSON.stringify(body) : undefined });
  return { status: res.status, body: await res.json().catch(() => null) };
}
const profile = (token, name) => api('PUT', '/api/v1/users/me', { token, body: { displayName: name, city: 'mumbai', dateOfBirth: '1992-02-02' } });

test('real emulator: token verification, profile, activity, nearby query, concurrent joins, chat limiter', async () => {
  assert.equal((await api('GET', '/api/v1/users/me')).status, 401);
  assert.equal((await api('GET', '/api/v1/users/me', { token: 'junk' })).status, 401);

  const host = await newUser('host@example.test');
  assert.equal((await profile(host.token, 'Host')).status, 201);
  const start = Date.now() + 86_400_000;
  const mk = (over) => api('POST', '/api/v1/activities', { token: host.token, body: {
    title: 'Sunrise run', category: 'fitness', city: 'mumbai', venueName: 'Marine Drive', latitude: 18.943, longitude: 72.823,
    startAt: new Date(start).toISOString(), endAt: new Date(start + 7_200_000).toISOString(), capacity: 4, ...over } });
  const a = await mk({});
  assert.equal(a.status, 201, JSON.stringify(a.body));
  const far = await mk({ title: 'Pune hike', city: 'pune', latitude: 18.52, longitude: 73.85 });
  assert.equal(far.status, 201);

  const near = await api('GET', '/api/v1/activities?lat=18.94&lng=72.82&radiusKm=10', { token: host.token });
  assert.equal(near.status, 200, JSON.stringify(near.body));
  assert.deepEqual(near.body.data.map((x) => x.id), [a.body.data.id]);
  const byCity = await api('GET', '/api/v1/activities?city=pune&category=fitness', { token: host.token });
  assert.equal(byCity.status, 200, JSON.stringify(byCity.body));
  const date = await api('GET', '/api/v1/activities?limit=1', { token: host.token });
  assert.equal(date.body.data.length, 1);
  assert.ok(date.body.nextCursor);
  assert.equal((await api('GET', `/api/v1/activities?limit=1&cursor=${date.body.nextCursor}`, { token: host.token })).status, 200);

  const users = await Promise.all(Array.from({ length: 8 }, async (_, i) => {
    const u = await newUser(`u${i}@example.test`);
    await profile(u.token, `User ${i}`);
    return u;
  }));
  const rs = await Promise.all(users.map((u) => api('POST', `/api/v1/activities/${a.body.data.id}/join`, { token: u.token })));
  assert.equal(rs.filter((r) => r.status === 200).length, 3, JSON.stringify(rs.map((r) => r.status)));
  const after = await api('GET', `/api/v1/activities/${a.body.data.id}`, { token: host.token });
  assert.equal(after.body.data.participantCount, 4);

  const chatter = users[0];
  const posts = await Promise.all(Array.from({ length: 10 }, (_, i) => api('POST', '/api/v1/community/messages', { token: chatter.token, body: { text: `hello ${i}` } })));
  assert.equal(posts.filter((p) => p.status === 201).length, 5, JSON.stringify(posts.map((p) => p.status)));

  assert.equal((await api('GET', '/api/v1/admin/metrics', { token: host.token })).status, 403);
});
