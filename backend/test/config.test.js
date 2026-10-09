import { test } from 'node:test';
import assert from 'node:assert/strict';
import { loadConfig } from '../src/config/env.js';

test('env validation: requires FIREBASE_PROJECT_ID, rejects bad values and wildcard origins', () => {
  assert.throws(() => loadConfig({}), /FIREBASE_PROJECT_ID/);
  assert.throws(() => loadConfig({ FIREBASE_PROJECT_ID: 'p', PORT: 'abc' }), /PORT/);
  assert.throws(() => loadConfig({ FIREBASE_PROJECT_ID: 'p', ALLOWED_ORIGINS: '*' }), /explicit origins/);
  assert.throws(() => loadConfig({ FIREBASE_PROJECT_ID: 'p', NEW_ACCOUNT_BLOCK_LINKS: 'yes' }), /NEW_ACCOUNT_BLOCK_LINKS/);
  assert.throws(() => loadConfig({ FIREBASE_PROJECT_ID: 'p', NODE_ENV: 'production', CRON_SECRET: 'short' }), /CRON_SECRET/);
});

test('env validation: defaults match docs/API.md community limits', () => {
  const c = loadConfig({ FIREBASE_PROJECT_ID: 'demo-nomadmingle' });
  assert.deepEqual(
    [c.community.newAccountAgeHours, c.community.newAccountMsgLimit, c.community.establishedMsgLimit, c.community.windowMinutes,
      c.community.maxLength, c.community.duplicateWindowSeconds, c.community.violationCooldownMinutes, c.community.newAccountBlockLinks],
    [72, 5, 20, 10, 500, 30, 10, true],
  );
});

test('error output never echoes secret values', () => {
  try { loadConfig({ FIREBASE_PROJECT_ID: 'p', PORT: 'super-secret-value' }); } catch (e) { assert.ok(!e.message.includes('super-secret-value')); }
});
