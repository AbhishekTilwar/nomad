import { test } from 'node:test';
import assert from 'node:assert/strict';
import { encodeGeohash, decodeGeohash, decodeBbox, neighbors, haversineKm, coverPrefixes, precisionForRadius, prefixRange } from '../src/lib/geo.js';

test('encodeGeohash matches known reference values', () => {
  assert.equal(encodeGeohash(57.64911, 10.40744, 11), 'u4pruydqqvj');
  assert.equal(encodeGeohash(42.605, -5.603, 5), 'ezs42');
  assert.equal(encodeGeohash(0, 0, 4), 's000');
});

test('Mumbai geohash is in the expected cell and decode round-trips', () => {
  const h = encodeGeohash(19.076, 72.8777, 9);
  assert.ok(h.startsWith('te7u'), h);
  const { lat, lng } = decodeGeohash(h);
  assert.ok(Math.abs(lat - 19.076) < 0.0001 && Math.abs(lng - 72.8777) < 0.0001);
});

test('encode rejects invalid coordinates', () => {
  assert.throws(() => encodeGeohash(91, 0), RangeError);
  assert.throws(() => encodeGeohash(0, 181), RangeError);
  assert.throws(() => encodeGeohash(NaN, 0), RangeError);
});

test('haversine: known distances', () => {
  assert.equal(haversineKm(10, 20, 10, 20), 0);
  // Mumbai (19.0760,72.8777) -> Pune (18.5204,73.8567) ~ 120 km
  const d = haversineKm(19.076, 72.8777, 18.5204, 73.8567);
  assert.ok(d > 115 && d < 125, `got ${d}`);
  // London -> Paris ~ 343 km
  const lp = haversineKm(51.5074, -0.1278, 48.8566, 2.3522);
  assert.ok(Math.abs(lp - 343.5) < 2, `got ${lp}`);
  // symmetric, antimeridian
  assert.ok(Math.abs(haversineKm(0, 179.9, 0, -179.9) - haversineKm(0, -179.9, 0, 179.9)) < 1e-9);
  assert.ok(haversineKm(0, 179.9, 0, -179.9) < 25);
});

test('neighbors returns 8 distinct cells of same precision that tile around the centre', () => {
  const h = encodeGeohash(19.076, 72.8777, 6);
  const n = neighbors(h);
  assert.equal(n.length, 8);
  assert.equal(new Set(n).size, 8);
  assert.ok(!n.includes(h));
  n.forEach((x) => assert.equal(x.length, 6));
  // every neighbour cell touches the centre cell's bbox
  const b = decodeBbox(h);
  for (const x of n) {
    const nb = decodeBbox(x);
    const touchLat = nb.maxLat >= b.minLat - 1e-9 && nb.minLat <= b.maxLat + 1e-9;
    const touchLng = nb.maxLng >= b.minLng - 1e-9 && nb.minLng <= b.maxLng + 1e-9;
    assert.ok(touchLat && touchLng);
  }
});

test('neighbors handle antimeridian wrap and poles', () => {
  const east = encodeGeohash(0, 179.999, 4);
  assert.ok(neighbors(east).some((x) => decodeGeohash(x).lng < 0), 'wraps to negative longitudes');
  const pole = encodeGeohash(89.99, 10, 4);
  assert.equal(neighbors(pole).length, 5, 'no cells north of the pole');
});

test('precisionForRadius picks coarser cells for larger radii', () => {
  assert.equal(precisionForRadius(100), 3);
  assert.equal(precisionForRadius(10), 4);
  assert.equal(precisionForRadius(3), 5);
  assert.equal(precisionForRadius(0.5), 6);
  assert.equal(precisionForRadius(1000), 1);
  assert.ok(precisionForRadius(10, 70) > 3, 'ok');
  assert.ok(precisionForRadius(10, 70) <= precisionForRadius(10, 0), 'high latitudes need coarser cells');
});

test('cover prefixes include every point inside the radius (randomised property check)', () => {
  for (const [lat, lng] of [[19.076, 72.8777], [55.7, 12.5], [-33.9, 151.2]]) coverCheck(lat, lng);
});

function coverCheck(lat, lng) {
  for (const radius of [0.5, 2, 5, 12, 40, 100]) {
    const { precision, prefixes } = coverPrefixes(lat, lng, radius);
    for (let i = 0; i < 300; i++) {
      const bearing = Math.random() * 2 * Math.PI;
      const dist = Math.random() * radius * 0.999;
      const dLat = (dist / 111.32) * Math.cos(bearing);
      const dLng = (dist / (111.32 * Math.cos((lat * Math.PI) / 180))) * Math.sin(bearing);
      const p = [lat + dLat, lng + dLng];
      if (haversineKm(lat, lng, p[0], p[1]) > radius) continue;
      const h = encodeGeohash(p[0], p[1], precision);
      assert.ok(prefixes.includes(h), `lat ${lat} radius ${radius}: point at ${dist.toFixed(2)}km not covered`);
    }
  }
}

test('prefixRange brackets all longer hashes with that prefix', () => {
  const [lo, hi] = prefixRange('te7u');
  const full = encodeGeohash(19.076, 72.8777, 9);
  assert.ok(full >= lo && full < hi);
  assert.ok(!('te7v' >= lo && 'te7v' < hi));
});
