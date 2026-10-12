import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createEnv } from './helpers/env.js';
import { isGoogleProfilePhoto, ownPhotoUrl, ownPhotoUrls } from '../src/lib/photos.js';

let env;
before(async () => { env = await createEnv(); });
after(async () => { await env.close(); });
const U = '/api/v1/users';
const j = (m, p, u, body) => env.api(m, p, { token: u.token, body });

const GOOGLE = 'https://lh3.googleusercontent.com/a/ACg8ocJ-abc=s96-c';
const OWN = 'https://firebasestorage.googleapis.com/v0/b/x/o/users%2Fme.jpg?alt=media';

test('isGoogleProfilePhoto: Google account pictures only, not our storage', () => {
  assert.equal(isGoogleProfilePhoto(GOOGLE), true);
  assert.equal(isGoogleProfilePhoto('https://lh4.ggpht.com/x'), true);
  assert.equal(isGoogleProfilePhoto('https://googleusercontent.com/x'), true);
  assert.equal(isGoogleProfilePhoto(OWN), false);
  assert.equal(isGoogleProfilePhoto('https://storage.googleapis.com/b/o.jpg'), false);
  assert.equal(isGoogleProfilePhoto('https://evilgoogleusercontent.com/x'), false);
  assert.equal(isGoogleProfilePhoto(null), false);
  assert.equal(isGoogleProfilePhoto('not a url'), false);
  assert.equal(ownPhotoUrl(GOOGLE), null);
  assert.equal(ownPhotoUrl(OWN), OWN);
  assert.deepEqual(ownPhotoUrls([GOOGLE, OWN]), [OWN]);
});

test('sign-up with a Google picture stores no photo (old app builds still send it)', async () => {
  const token = env.auth.issue('g-1');
  const r = await env.api('PUT', `${U}/me`, {
    token, body: { displayName: 'Gita', city: 'pune', dateOfBirth: '1995-05-05', photoUrl: GOOGLE },
  });
  assert.equal(r.status, 201);
  assert.equal(r.body.data.photoUrl, null);
});

test('an uploaded photo is kept; a later Google picture cannot replace it', async () => {
  const u = await env.signup('g-2');
  assert.equal((await j('PATCH', `${U}/me`, u, { photoUrl: OWN })).body.data.photoUrl, OWN);
  const r = await j('PATCH', `${U}/me`, u, { photoUrl: GOOGLE });
  assert.equal(r.status, 200);
  assert.equal(r.body.data.photoUrl, OWN);
});

test('Google pictures are filtered out of the gallery', async () => {
  const u = await env.signup('g-3');
  const r = await j('PATCH', `${U}/me`, u, { photos: [GOOGLE, OWN] });
  assert.equal(r.status, 200);
  assert.deepEqual(r.body.data.photos, [OWN]);
});

test('a Google picture saved before this rule is cleared on the next write', async () => {
  const u = await env.signup('g-4');
  await env.db.doc('users/g-4').update({ photoUrl: GOOGLE });
  const r = await j('PATCH', `${U}/me`, u, { bio: 'hello there' });
  assert.equal(r.status, 200);
  assert.equal(r.body.data.photoUrl, null);
});

test('chat messages never carry a stored Google picture', async () => {
  const u = await env.signup('g-5');
  await env.db.doc('users/g-5').update({ photoUrl: GOOGLE });
  const r = await j('POST', '/api/v1/community/messages', u, { text: 'hello everyone' });
  assert.equal(r.status, 201, JSON.stringify(r.body));
  assert.equal(r.body.data.senderPhotoUrl, null);
});
