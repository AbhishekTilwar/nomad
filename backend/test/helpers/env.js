import http from 'node:http';
import { Timestamp } from 'firebase-admin/firestore';
import { createApp } from '../../src/app.js';
import { loadConfig } from '../../src/config/env.js';
import { createLogger } from '../../src/lib/logger.js';
import { FakeFirestore } from './fakeFirestore.js';

export const T0 = Date.UTC(2026, 9, 10, 12, 0, 0); // fixed "now"
export const HOUR = 3600_000;

class FakeAuth {
  constructor() { this.tokens = new Map(); this.revoked = new Set(); this.deleted = new Set(); }
  issue(uid, claims = {}) {
    const token = `tok-${uid}-${this.tokens.size}`;
    this.tokens.set(token, { uid, ...claims });
    return token;
  }
  async verifyIdToken(token) {
    const c = this.tokens.get(token);
    if (!c || this.deleted.has(c.uid)) throw Object.assign(new Error('bad token'), { code: 'auth/argument-error' });
    return { ...c };
  }
  async revokeRefreshTokens(uid) { this.revoked.add(uid); }
  async deleteUser(uid) { this.deleted.add(uid); }
}

class FakeMessaging {
  constructor() { this.sent = []; }
  async sendEachForMulticast(msg) {
    this.sent.push(msg);
    return { successCount: msg.tokens.length, failureCount: 0, responses: msg.tokens.map(() => ({ success: true })) };
  }
}

export async function createEnv({ env = {}, startMs = T0 } = {}) {
  const clock = { ms: startMs };
  const now = () => clock.ms;
  const db = new FakeFirestore({ now });
  const auth = new FakeAuth();
  const messaging = new FakeMessaging();
  const config = loadConfig({
    NODE_ENV: 'test', FIREBASE_PROJECT_ID: 'demo-nomadmingle', LOG_LEVEL: 'silent',
    IP_RATE_LIMIT_PER_MIN: '1000000', USER_RATE_LIMIT_PER_MIN: '1000000',
    ALLOWED_ORIGINS: 'https://app.example.test', CRON_SECRET: 'test-cron-secret-0123456789',
    ...env,
  });
  const app = createApp({ db, auth, messaging, fv: db.fv, now, logger: createLogger('silent'), config });
  const server = http.createServer(app);
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  const base = `http://127.0.0.1:${server.address().port}`;

  async function api(method, path, { token, body, headers = {} } = {}) {
    const res = await fetch(base + path, {
      method,
      headers: { ...(body !== undefined ? { 'content-type': 'application/json' } : {}), ...(token ? { authorization: `Bearer ${token}` } : {}), ...headers },
      body: body !== undefined ? (typeof body === 'string' ? body : JSON.stringify(body)) : undefined,
    });
    const text = await res.text();
    let json = null;
    try { json = JSON.parse(text); } catch { /* non-json */ }
    return { status: res.status, body: json, headers: res.headers };
  }

  /** Create a user through the real API. Returns { uid, token }. */
  async function signup(uid, { name = `User ${uid}`, dob = '1995-05-05', city = 'mumbai', claims = {}, established = false } = {}) {
    const token = auth.issue(uid, claims);
    const r = await api('PUT', '/api/v1/users/me', { token, body: { displayName: name, city, dateOfBirth: dob } });
    if (r.status !== 201) throw new Error(`signup failed ${r.status} ${JSON.stringify(r.body)}`);
    if (established) await db.doc(`users/${uid}`).update({ createdAt: Timestamp.fromMillis(clock.ms - 30 * 24 * HOUR) });
    return { uid, token };
  }

  const activityBody = (over = {}) => ({
    title: 'Sunrise run at Marine Drive', description: 'Easy 5k', category: 'fitness', city: 'mumbai',
    venueName: 'Marine Drive', latitude: 18.943, longitude: 72.823,
    startAt: new Date(clock.ms + 24 * HOUR).toISOString(), endAt: new Date(clock.ms + 26 * HOUR).toISOString(),
    capacity: 5, ...over,
  });

  async function createActivity(host, over = {}) {
    const r = await api('POST', '/api/v1/activities', { token: host.token, body: activityBody(over) });
    if (r.status !== 201) throw new Error(`createActivity failed ${r.status} ${JSON.stringify(r.body)}`);
    return r.body.data;
  }

  const close = () => new Promise((r) => server.close(r));
  return { api, signup, createActivity, activityBody, db, auth, messaging, clock, config, close, app };
}
