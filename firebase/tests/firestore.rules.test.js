import { test, before, after } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, addDoc, collection, collectionGroup, getDocs, query, where, orderBy, serverTimestamp,
} from 'firebase/firestore';
import { makeEnv, seed } from './helpers.js';

let env;
before(async () => { env = await makeEnv(); });
after(async () => { await env.cleanup(); });
// Every test starts from the same data. Tests in a file run sequentially.
const fresh = async () => { await env.clearFirestore(); await seed(env); };
const db = (uid) => (uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore());

test('unauthenticated clients can read nothing', async () => {
  await fresh();
  const anon = db(null);
  for (const p of ['users/alice', 'activities/pub', 'communityRooms/global', 'communityRooms/global/messages/visible', 'activities/pub/messages/visible', 'notifications/n1']) {
    await assertFails(getDoc(doc(anon, p)));
  }
});

// ---------------------------------------------------------------- profiles
test('profiles: any signed-in user can get a public profile; list/enumeration is denied', async () => {
  await fresh();
  await assertSucceeds(getDoc(doc(db('bob'), 'users/alice')));
  await assertSucceeds(getDoc(doc(db('bob'), 'users/bob')));
  await assertFails(getDocs(collection(db('bob'), 'users')));
});

test('profiles: nobody can write profiles directly, including their own', async () => {
  await fresh();
  await assertFails(setDoc(doc(db('bob'), 'users/bob'), { displayName: 'Bob' }));
  await assertFails(updateDoc(doc(db('bob'), 'users/bob'), { displayName: 'Hacked' }));
  await assertFails(setDoc(doc(db('newuser'), 'users/newuser'), { displayName: 'New', accountStatus: 'active' }));
  await assertFails(deleteDoc(doc(db('bob'), 'users/bob')));
  await assertFails(updateDoc(doc(db('bob'), 'users/alice'), { displayName: 'Not yours' }));
});

test('profiles: cannot self-write accountStatus (unsuspend/unmute) or role', async () => {
  await fresh();
  await assertFails(updateDoc(doc(db('carol'), 'users/carol'), { accountStatus: 'active' }));
  await assertFails(updateDoc(doc(db('mike'), 'users/mike'), { accountStatus: 'active' }));
  await assertFails(updateDoc(doc(db('bob'), 'users/bob/private/profile'), { role: 'admin' }));
  await assertFails(setDoc(doc(db('bob'), 'users/bob/private/profile'), { role: 'admin' }, { merge: true }));
  await assertFails(updateDoc(doc(db('bob'), 'users/bob'), { role: 'admin' }));
});

test('private profile: owner read only', async () => {
  await fresh();
  await assertSucceeds(getDoc(doc(db('bob'), 'users/bob/private/profile')));
  await assertFails(getDoc(doc(db('alice'), 'users/bob/private/profile')), 'even admins cannot read via client');
  await assertFails(getDoc(doc(db(null), 'users/bob/private/profile')));
});

// ---------------------------------------------------------------- direct writes
test('clients cannot write activities, members, messages, reports, moderation, rate limits, tokens, notifications', async () => {
  await fresh();
  const bob = db('bob');
  const alice = db('alice');
  await assertFails(setDoc(doc(bob, 'activities/new'), { title: 'x', hostId: 'bob' }));
  await assertFails(addDoc(collection(bob, 'activities'), { title: 'x', hostId: 'bob' }));
  await assertFails(updateDoc(doc(alice, 'activities/pub'), { participantCount: 50 }));   // even the host
  await assertFails(updateDoc(doc(alice, 'activities/pub'), { status: 'cancelled' }));
  await assertFails(deleteDoc(doc(alice, 'activities/pub')));
  await assertFails(setDoc(doc(bob, 'activities/pub/members/bob'), { userId: 'bob', status: 'approved', role: 'host' }));
  await assertFails(updateDoc(doc(bob, 'activities/pub/members/dave'), { status: 'approved' }));
  await assertFails(updateDoc(doc(alice, 'activities/pub/members/dave'), { status: 'approved' }));  // host approvals go via API
  await assertFails(addDoc(collection(bob, 'activities/pub/messages'), { senderId: 'bob', text: 'hi', moderationStatus: 'visible', createdAt: serverTimestamp() }));
  await assertFails(addDoc(collection(bob, 'communityRooms/global/messages'), { senderId: 'bob', text: 'hi', moderationStatus: 'visible', createdAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(bob, 'communityRooms/global/messages/visible'), { moderationStatus: 'visible', text: 'edited' }));
  await assertFails(updateDoc(doc(bob, 'communityRooms/global/messages/hidden'), { moderationStatus: 'visible' }));
  await assertFails(deleteDoc(doc(bob, 'communityRooms/global/messages/visible')));
  await assertFails(setDoc(doc(bob, 'communityRooms/global'), { name: 'Pwned' }));
  await assertFails(addDoc(collection(bob, 'reports'), { reporterId: 'bob' }));
  await assertFails(addDoc(collection(alice, 'moderationActions'), { actorId: 'alice', action: 'suspend' }));
  await assertFails(deleteDoc(doc(alice, 'moderationActions/a1')));
  await assertFails(setDoc(doc(bob, 'userRateLimits/bob'), { count: 0, violations: 0 }));
  await assertFails(deleteDoc(doc(bob, 'userRateLimits/bob')));
  await assertFails(setDoc(doc(bob, 'deviceTokens/x'), { uid: 'bob', token: 't' }));
  await assertFails(updateDoc(doc(bob, 'notifications/n1'), { read: true }));
  await assertFails(addDoc(collection(bob, 'notifications'), { userId: 'bob' }));
  await assertFails(setDoc(doc(bob, 'somethingElse/doc'), { a: 1 }));
  await assertFails(getDoc(doc(bob, 'somethingElse/doc')));
});

// ---------------------------------------------------------------- activities + chat
test('activities: public readable by active users; private only by host/members; suspended denied', async () => {
  await fresh();
  await assertSucceeds(getDoc(doc(db('bob'), 'activities/pub')));
  await assertSucceeds(getDoc(doc(db('gina'), 'activities/pub')));
  await assertFails(getDoc(doc(db('gina'), 'activities/priv')));
  await assertSucceeds(getDoc(doc(db('bob'), 'activities/priv')));
  await assertSucceeds(getDoc(doc(db('alice'), 'activities/priv')));
  await assertSucceeds(getDoc(doc(db('dave'), 'activities/priv')), 'requesters can see the activity they asked to join');
  await assertFails(getDoc(doc(db('carol'), 'activities/pub')));
  await assertFails(getDoc(doc(db('zed'), 'activities/pub')));
  await assertSucceeds(getDocs(query(collection(db('gina'), 'activities'), where('visibility', '==', 'public'), where('status', '==', 'scheduled'))));
  await assertFails(getDocs(collection(db('gina'), 'activities')), 'unfiltered list could include private docs');
});

test('members: own doc, host sees all, others only approved on public activities; "my activities" group query', async () => {
  await fresh();
  await assertSucceeds(getDoc(doc(db('dave'), 'activities/pub/members/dave')));
  await assertFails(getDoc(doc(db('gina'), 'activities/pub/members/dave')), 'requests hidden from strangers');
  await assertSucceeds(getDoc(doc(db('alice'), 'activities/pub/members/dave')));
  await assertSucceeds(getDoc(doc(db('gina'), 'activities/pub/members/bob')), 'approved attendees visible on public activity');
  await assertFails(getDoc(doc(db('gina'), 'activities/priv/members/bob')));
  await assertSucceeds(getDocs(query(collectionGroup(db('bob'), 'members'), where('userId', '==', 'bob'), where('status', 'in', ['approved', 'requested']))));
  await assertFails(getDocs(query(collectionGroup(db('bob'), 'members'), where('userId', '==', 'alice'))));
  await assertFails(getDocs(collectionGroup(db('bob'), 'members')));
});

test('activity chat: approved members can read visible messages; requested/left/removed/strangers/suspended cannot', async () => {
  await fresh();
  const path = 'activities/pub/messages/visible';
  await assertSucceeds(getDoc(doc(db('bob'), path)));
  await assertSucceeds(getDoc(doc(db('alice'), path)));
  for (const uid of ['dave', 'erin', 'frank', 'gina', 'mike']) {
    await assertFails(getDoc(doc(db(uid), path)));
  }
  await assertFails(getDoc(doc(db('carol'), path)), 'suspended member loses access even though status is approved');
  await assertFails(getDoc(doc(db(null), path)));
  await assertSucceeds(getDocs(query(collection(db('bob'), 'activities/pub/messages'), where('moderationStatus', '==', 'visible'), orderBy('createdAt', 'desc'))));
  await assertFails(getDocs(query(collection(db('dave'), 'activities/pub/messages'), where('moderationStatus', '==', 'visible'), orderBy('createdAt', 'desc'))));
  await assertFails(getDocs(query(collection(db('erin'), 'activities/pub/messages'), where('moderationStatus', '==', 'visible'))));
});

test('activity chat: hidden messages unreadable even by members and host; unfiltered queries denied', async () => {
  await fresh();
  await assertFails(getDoc(doc(db('bob'), 'activities/pub/messages/hidden')));
  await assertFails(getDoc(doc(db('alice'), 'activities/pub/messages/hidden')));
  await assertFails(getDocs(collection(db('bob'), 'activities/pub/messages')));
});

test('activity chat: cancelled chats stay readable 30 days for approved members, then close', async () => {
  await fresh();
  await assertSucceeds(getDoc(doc(db('bob'), 'activities/recent/messages/visible')));
  await assertFails(getDoc(doc(db('bob'), 'activities/old/messages/visible')));
  await assertFails(getDoc(doc(db('erin'), 'activities/recent/messages/visible')));
});

// ---------------------------------------------------------------- community
test('community: active (and muted) users can read visible messages; suspended/deleted/anon cannot', async () => {
  await fresh();
  for (const uid of ['bob', 'mike', 'gina']) {
    await assertSucceeds(getDoc(doc(db(uid), 'communityRooms/global')));
    await assertSucceeds(getDoc(doc(db(uid), 'communityRooms/global/messages/visible')));
    await assertSucceeds(getDocs(query(collection(db(uid), 'communityRooms/global/messages'), where('moderationStatus', '==', 'visible'), orderBy('createdAt', 'desc'))));
  }
  for (const uid of ['carol', 'zed', 'ghostwithnoprofile', null]) {
    await assertFails(getDoc(doc(db(uid), 'communityRooms/global/messages/visible')));
    await assertFails(getDoc(doc(db(uid), 'communityRooms/global')));
  }
});

test('community: hidden and removed messages are unreadable; unfiltered list denied', async () => {
  await fresh();
  await assertFails(getDoc(doc(db('bob'), 'communityRooms/global/messages/hidden')));
  await assertFails(getDoc(doc(db('bob'), 'communityRooms/global/messages/removed')));
  await assertFails(getDoc(doc(db('alice'), 'communityRooms/global/messages/hidden')), 'admins use the API, not client reads');
  await assertFails(getDocs(collection(db('bob'), 'communityRooms/global/messages')));
  await assertFails(getDocs(query(collection(db('bob'), 'communityRooms/global/messages'), where('moderationStatus', 'in', ['visible', 'hidden']))));
});

// ---------------------------------------------------------------- private data
test('reports, moderationActions, userRateLimits, deviceTokens are unreadable by everyone (incl. reporter/admin)', async () => {
  await fresh();
  for (const uid of ['bob', 'alice', 'dave']) {
    await assertFails(getDoc(doc(db(uid), 'reports/r1')));
    await assertFails(getDocs(collection(db(uid), 'reports')));
    await assertFails(getDoc(doc(db(uid), 'moderationActions/a1')));
    await assertFails(getDocs(collection(db(uid), 'moderationActions')));
    await assertFails(getDoc(doc(db(uid), 'userRateLimits/bob')));
    await assertFails(getDoc(doc(db(uid), 'deviceTokens/h1')));
  }
});

test('friendships: no client access (backend only)', async () => {
  await assertFails(getDoc(doc(db('bob'), 'friendships/bob_dave')));
  await assertFails(setDoc(doc(db('bob'), 'friendships/bob_dave'), { users: ['bob', 'dave'], status: 'accepted' }));
});

test('userBlocks: owner-only read, no client writes', async () => {
  await fresh();
  await assertSucceeds(getDoc(doc(db('bob'), 'userBlocks/bob/blocked/dave')));
  await assertSucceeds(getDocs(collection(db('bob'), 'userBlocks/bob/blocked')));
  await assertFails(getDoc(doc(db('dave'), 'userBlocks/bob/blocked/dave')), 'the blocked user cannot see they are blocked');
  await assertFails(getDocs(collection(db('dave'), 'userBlocks/bob/blocked')));
  await assertFails(getDoc(doc(db('alice'), 'userBlocks/bob/blocked/dave')));
  await assertFails(setDoc(doc(db('bob'), 'userBlocks/bob/blocked/gina'), { blockedAt: serverTimestamp() }));
  await assertFails(deleteDoc(doc(db('bob'), 'userBlocks/bob/blocked/dave')));
  await assertFails(setDoc(doc(db('dave'), 'userBlocks/bob/blocked/dave2'), { blockedAt: serverTimestamp() }));
});

test('notifications: owner reads own; others and unfiltered queries denied', async () => {
  await fresh();
  await assertSucceeds(getDoc(doc(db('bob'), 'notifications/n1')));
  await assertFails(getDoc(doc(db('bob'), 'notifications/n2')));
  await assertSucceeds(getDocs(query(collection(db('bob'), 'notifications'), where('userId', '==', 'bob'), orderBy('createdAt', 'desc'))));
  await assertFails(getDocs(query(collection(db('bob'), 'notifications'), where('userId', '==', 'alice'))));
  await assertFails(getDocs(collection(db('bob'), 'notifications')));
});
