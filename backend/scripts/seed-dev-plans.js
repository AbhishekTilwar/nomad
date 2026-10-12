// Local-only: seeds sample plans into the Firestore EMULATOR so the map has
// something to show. Refuses to run against anything else.
//   FIRESTORE_EMULATOR_HOST=127.0.0.1:8081 node scripts/seed-dev-plans.js
import { initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp, FieldValue } from 'firebase-admin/firestore';
import { encodeGeohash } from '../src/lib/geo.js';

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  console.error('Refusing to seed: FIRESTORE_EMULATOR_HOST is not set (emulator only).');
  process.exit(1);
}

initializeApp({ projectId: 'demo-nomadmingle' });
const db = getFirestore();

const HOUR = 3600_000;
const now = Date.now();
const photo = (n) => `https://i.pravatar.cc/200?img=${n}`;

const hosts = [
  ['Aarav', 12], ['Meera', 47], ['Kabir', 33], ['Isha', 5], ['Rohan', 60],
  ['Zoya', 25], ['Vikram', 68], ['Nina', 44], ['Dev', 15], ['Sana', 9],
];

// [title, category, city, venue, lat, lng, startsInHours, capacity, joined, paid, approval]
const plans = [
  // Mumbai: dense cluster around Bandra / Khar
  ['Sunrise chai at Carter Road', 'food', 'mumbai', 'Carter Road Promenade', 19.0690, 72.8228, 1.2, 8, 3, false, false],
  ['Bandra street art walk', 'art', 'mumbai', 'Chapel Road', 19.0596, 72.8295, 5, 10, 6, false, false],
  ['Board games night', 'games', 'mumbai', 'Bandra Kitchen', 19.0544, 72.8402, 28, 8, 8, false, false],
  ['Linking Road thrift hunt', 'outings', 'mumbai', 'Linking Road', 19.0653, 72.8347, 8, 12, 4, false, false],
  ['Open mic at Khar', 'music', 'mumbai', 'Social, Khar', 19.0728, 72.8365, 30, 20, 9, true, false],
  ['Photo walk: Bandra fort', 'photography', 'mumbai', 'Bandra Fort', 19.0449, 72.8186, 50, 10, 2, false, true],
  // Mumbai: South Bombay
  ['Gateway sunset sketching', 'art', 'mumbai', 'Gateway of India', 18.9220, 72.8347, 6, 12, 5, false, false],
  ['Marine Drive evening run', 'sports', 'mumbai', 'Marine Drive', 18.9440, 72.8231, 3, 15, 7, false, false],
  ['Irani cafe breakfast crawl', 'food', 'mumbai', 'Kyani & Co', 18.9490, 72.8290, 26, 8, 4, false, false],
  ['Kala Ghoda networking mixer', 'networking', 'mumbai', 'Kala Ghoda', 18.9285, 72.8317, 52, 25, 11, true, true],
  // Mumbai: spread out
  ['Sanjay Gandhi NP hike', 'hiking', 'mumbai', 'SGNP Gate 1', 19.2147, 72.9106, 55, 20, 12, false, false],
  ['Juhu beach volleyball', 'sports', 'mumbai', 'Juhu Beach', 19.0948, 72.8266, 2, 12, 10, false, false],
  ['Powai lake picnic', 'outings', 'mumbai', 'Powai Lake', 19.1275, 72.9050, 31, 14, 3, false, false],
  ['Worli film club', 'movies', 'mumbai', 'Worli Sea Face', 19.0216, 72.8157, 29, 12, 12, false, false],
  ['Weekend Alibaug trip crew', 'travel', 'mumbai', 'Gateway Jetty', 18.9217, 72.8340, 100, 16, 5, true, true],
  // Pune: dense cluster around Koregaon Park / Kalyani Nagar
  ['Koregaon Park coffee crawl', 'food', 'pune', 'German Bakery', 18.5362, 73.8940, 1.5, 8, 2, false, false],
  ['Osho garden sunset walk', 'explore', 'pune', 'Osho Teerth Park', 18.5392, 73.8977, 4, 10, 4, false, false],
  ['Kalyani Nagar jam session', 'music', 'pune', 'High Spirits', 18.5463, 73.9035, 27, 15, 7, false, false],
  ['Board game cafe meetup', 'games', 'pune', 'Dice & Dine', 18.5310, 73.8890, 7, 8, 5, false, false],
  ['Photo walk: Shaniwar Wada', 'photography', 'pune', 'Shaniwar Wada', 18.5195, 73.8553, 32, 10, 3, false, false],
  ['Sinhagad sunrise trek', 'hiking', 'pune', 'Sinhagad Base', 18.3664, 73.7557, 49, 25, 14, false, false],
  ['Baner badminton doubles', 'sports', 'pune', 'Baner Sports Club', 18.5590, 73.7868, 3, 8, 8, false, false],
  ['FC Road street food tour', 'food', 'pune', 'FC Road', 18.5236, 73.8412, 9, 10, 6, false, false],
  ['Aundh startup chai', 'networking', 'pune', 'Aundh', 18.5580, 73.8075, 53, 20, 4, false, false],
  ['Mulshi weekend getaway', 'travel', 'pune', 'Mulshi Dam', 18.5198, 73.5167, 98, 12, 6, true, true],
];

const batch = db.batch();
hosts.forEach(([name, img], i) => {
  batch.set(db.doc(`users/seed-host-${i}`), { displayName: name, photoUrl: photo(img), stats: { hosted: 0, attended: 0 } }, { merge: true });
});

plans.forEach(([title, category, city, venueName, latitude, longitude, inH, capacity, joined, paid, approval], i) => {
  const hostIdx = i % hosts.length;
  const [hostName, img] = hosts[hostIdx];
  const startMs = now + inH * HOUR;
  const ref = db.doc(`activities/seed-plan-${i}`);
  batch.set(ref, {
    title, description: `${title}. Small group, all welcome.`, category,
    hostId: `seed-host-${hostIdx}`, hostDisplayName: hostName, hostPhotoUrl: photo(img),
    city, venueName, latitude, longitude, geohash: encodeGeohash(latitude, longitude, 9),
    startAt: Timestamp.fromMillis(startMs), endAt: Timestamp.fromMillis(startMs + 2 * HOUR),
    capacity, participantCount: joined,
    costType: paid ? 'paid' : 'free', costDescription: paid ? '₹300 per person' : '',
    coverImageUrl: null, approvalRequired: approval, visibility: 'public',
    safetyNotes: 'Public place, meet at the entrance.', cancellationPolicy: '',
    status: 'scheduled', createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
  });
  batch.set(db.doc(`activities/seed-plan-${i}/members/seed-host-${hostIdx}`), {
    userId: `seed-host-${hostIdx}`, role: 'host', status: 'approved', displayName: hostName, photoUrl: photo(img),
    requestedAt: null, approvedAt: FieldValue.serverTimestamp(), joinedAt: FieldValue.serverTimestamp(), leftAt: null,
  });
});

await batch.commit();
console.log(`Seeded ${plans.length} plans (ids seed-plan-*) into the emulator.`);
