import { test } from 'node:test';
import assert from 'node:assert/strict';
import { patchProfileSchema } from '../src/modules/users/schemas.js';

const http = { photoUrl: 'http://10.0.2.2:9199/v0/b/demo.appspot.com/o/a.jpg?alt=media' };
const https = { photoUrl: 'https://firebasestorage.googleapis.com/v0/b/x/o/a.jpg?alt=media' };

function withEnv(env, fn) {
  const prev = { host: process.env.FIREBASE_STORAGE_EMULATOR_HOST, node: process.env.NODE_ENV };
  for (const [k, v] of Object.entries(env)) {
    if (v === undefined) delete process.env[k]; else process.env[k] = v;
  }
  try { fn(); } finally {
    for (const [k, v] of [['FIREBASE_STORAGE_EMULATOR_HOST', prev.host], ['NODE_ENV', prev.node]]) {
      if (v === undefined) delete process.env[k]; else process.env[k] = v;
    }
  }
}

test('https photo URLs are always accepted', () => {
  withEnv({ FIREBASE_STORAGE_EMULATOR_HOST: undefined, NODE_ENV: 'production' }, () => {
    assert.equal(patchProfileSchema.safeParse(https).success, true);
  });
});

test('http photo URLs are rejected without the Storage emulator', () => {
  withEnv({ FIREBASE_STORAGE_EMULATOR_HOST: undefined, NODE_ENV: 'development' }, () => {
    assert.equal(patchProfileSchema.safeParse(http).success, false);
  });
});

test('http photo URLs are accepted only with the Storage emulator outside production', () => {
  withEnv({ FIREBASE_STORAGE_EMULATOR_HOST: '127.0.0.1:9199', NODE_ENV: 'development' }, () => {
    assert.equal(patchProfileSchema.safeParse(http).success, true);
  });
  withEnv({ FIREBASE_STORAGE_EMULATOR_HOST: '127.0.0.1:9199', NODE_ENV: 'production' }, () => {
    assert.equal(patchProfileSchema.safeParse(http).success, false);
  });
});

test('other schemes are never accepted', () => {
  withEnv({ FIREBASE_STORAGE_EMULATOR_HOST: '127.0.0.1:9199', NODE_ENV: 'development' }, () => {
    assert.equal(patchProfileSchema.safeParse({ photoUrl: 'javascript:alert(1)' }).success, false);
    assert.equal(patchProfileSchema.safeParse({ photoUrl: 'ftp://x/y.jpg' }).success, false);
  });
});
