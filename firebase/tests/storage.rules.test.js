import { test, before, after } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { ref, uploadBytes, getBytes, deleteObject } from 'firebase/storage';
import { makeEnv } from './helpers.js';

let env;
before(async () => { env = await makeEnv(); });
after(async () => { await env.cleanup(); });
const storage = (uid) => (uid ? env.authenticatedContext(uid).storage() : env.unauthenticatedContext().storage());
const png = (n = 1024) => new Uint8Array(n);
const NAME = '3f2b9c1e-7a4d-4e8a-9b1c-2d5e6f708192'; // 36 chars, uuid-like
const MB = 1024 * 1024;

test('owner can upload an avatar image with a non-guessable name', async () => {
  await assertSucceeds(uploadBytes(ref(storage('alice'), `users/alice/avatar/${NAME}.jpg`), png(), { contentType: 'image/jpeg' }));
  await assertSucceeds(uploadBytes(ref(storage('alice'), `users/alice/avatar/${NAME}.png`), png(), { contentType: 'image/png' }));
  await assertSucceeds(uploadBytes(ref(storage('alice'), `users/alice/avatar/${NAME}.webp`), png(), { contentType: 'image/webp' }));
});

test('owner can upload an activity cover under activities/{uid}/covers', async () => {
  await assertSucceeds(uploadBytes(ref(storage('alice'), `activities/alice/covers/${NAME}.jpg`), png(), { contentType: 'image/jpeg' }));
});

test('other users and anonymous cannot write into someone else\'s path', async () => {
  await assertFails(uploadBytes(ref(storage('bob'), `users/alice/avatar/${NAME}.jpg`), png(), { contentType: 'image/jpeg' }));
  await assertFails(uploadBytes(ref(storage(null), `users/alice/avatar/${NAME}.jpg`), png(), { contentType: 'image/jpeg' }));
  await assertFails(uploadBytes(ref(storage('bob'), `activities/alice/covers/${NAME}.jpg`), png(), { contentType: 'image/jpeg' }));
});

test('size limit: exactly 5 MB ok, 5 MB + 1 byte rejected', async () => {
  await assertSucceeds(uploadBytes(ref(storage('alice'), `users/alice/avatar/${NAME}-max.jpg`), png(5 * MB), { contentType: 'image/jpeg' }));
  await assertFails(uploadBytes(ref(storage('alice'), `users/alice/avatar/${NAME}-big.jpg`), png(5 * MB + 1), { contentType: 'image/jpeg' }));
  await assertFails(uploadBytes(ref(storage('alice'), `activities/alice/covers/${NAME}-big.jpg`), png(6 * MB), { contentType: 'image/png' }));
});

test('content type: only raster images (no text, html, pdf, svg)', async () => {
  for (const [ct, ext] of [['text/plain', 'jpg'], ['text/html', 'jpg'], ['application/pdf', 'jpg'], ['application/octet-stream', 'jpg'], ['image/svg+xml', 'png']]) {
    await assertFails(uploadBytes(ref(storage('alice'), `users/alice/avatar/${NAME}-${ct.replace('/', '_')}.${ext}`), png(), { contentType: ct }), ct);
  }
});

test('guessable or malformed names are rejected', async () => {
  for (const name of ['avatar.jpg', 'me.png', '12345.jpg', `${NAME}.exe`, `${NAME}.html`, `${NAME}`, '../x.jpg']) {
    await assertFails(uploadBytes(ref(storage('alice'), `users/alice/avatar/${name}`), png(), { contentType: 'image/jpeg' }), name);
  }
});

test('paths outside the allowed prefixes are denied', async () => {
  await assertFails(uploadBytes(ref(storage('alice'), `uploads/${NAME}.jpg`), png(), { contentType: 'image/jpeg' }));
  await assertFails(uploadBytes(ref(storage('alice'), `users/alice/documents/${NAME}.jpg`), png(), { contentType: 'image/jpeg' }));
  await assertFails(uploadBytes(ref(storage('alice'), `users/alice/${NAME}.jpg`), png(), { contentType: 'image/jpeg' }));
});

test('reads: signed-in users can read; anonymous cannot; delete is owner-only', async () => {
  const path = `users/alice/avatar/${NAME}-read.jpg`;
  await assertSucceeds(uploadBytes(ref(storage('alice'), path), png(), { contentType: 'image/jpeg' }));
  await assertSucceeds(getBytes(ref(storage('bob'), path)));
  await assertFails(getBytes(ref(storage(null), path)));
  await assertFails(deleteObject(ref(storage('bob'), path)));
  await assertFails(deleteObject(ref(storage(null), path)));
  await assertSucceeds(deleteObject(ref(storage('alice'), path)));
});
