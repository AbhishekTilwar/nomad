// Geohash + distance helpers. Pure functions, no I/O.
const BASE32 = '0123456789bcdefghjkmnpqrstuvwxyz';
const EARTH_RADIUS_KM = 6371.0088;

export function encodeGeohash(lat, lng, precision = 9) {
  if (!Number.isFinite(lat) || !Number.isFinite(lng) || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
    throw new RangeError('Invalid coordinates');
  }
  let latR = [-90, 90];
  let lngR = [-180, 180];
  let hash = '';
  let bit = 0;
  let ch = 0;
  let even = true;
  while (hash.length < precision) {
    const r = even ? lngR : latR;
    const v = even ? lng : lat;
    const mid = (r[0] + r[1]) / 2;
    if (v >= mid) {
      ch = (ch << 1) | 1;
      r[0] = mid;
    } else {
      ch <<= 1;
      r[1] = mid;
    }
    even = !even;
    if (++bit === 5) {
      hash += BASE32[ch];
      bit = 0;
      ch = 0;
    }
  }
  return hash;
}

/** Bounding box of a geohash cell. */
export function decodeBbox(hash) {
  let latR = [-90, 90];
  let lngR = [-180, 180];
  let even = true;
  for (const c of hash) {
    const idx = BASE32.indexOf(c);
    if (idx < 0) throw new RangeError('Invalid geohash');
    for (let b = 4; b >= 0; b--) {
      const bitv = (idx >> b) & 1;
      const r = even ? lngR : latR;
      const mid = (r[0] + r[1]) / 2;
      if (bitv) r[0] = mid;
      else r[1] = mid;
      even = !even;
    }
  }
  return { minLat: latR[0], maxLat: latR[1], minLng: lngR[0], maxLng: lngR[1] };
}

export function decodeGeohash(hash) {
  const b = decodeBbox(hash);
  return { lat: (b.minLat + b.maxLat) / 2, lng: (b.minLng + b.maxLng) / 2 };
}

/** The 8 neighbouring cells (fewer near the poles). Longitude wraps. */
export function neighbors(hash) {
  const b = decodeBbox(hash);
  const h = b.maxLat - b.minLat;
  const w = b.maxLng - b.minLng;
  const cLat = (b.minLat + b.maxLat) / 2;
  const cLng = (b.minLng + b.maxLng) / 2;
  const out = new Set();
  for (const dLat of [-1, 0, 1]) {
    for (const dLng of [-1, 0, 1]) {
      if (dLat === 0 && dLng === 0) continue;
      const lat = cLat + dLat * h;
      if (lat < -90 || lat > 90) continue;
      let lng = cLng + dLng * w;
      if (lng > 180) lng -= 360;
      if (lng < -180) lng += 360;
      out.add(encodeGeohash(lat, lng, hash.length));
    }
  }
  out.delete(hash);
  return [...out];
}

export function haversineKm(lat1, lng1, lat2, lng2) {
  const rad = (d) => (d * Math.PI) / 180;
  const dLat = rad(lat2 - lat1);
  const dLng = rad(lng2 - lng1);
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(rad(lat1)) * Math.cos(rad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_RADIUS_KM * Math.asin(Math.min(1, Math.sqrt(a)));
}

// Geohash cell size in km at the equator, indexed by precision: [width, height].
// Width shrinks with cos(latitude), so the usable minimum dimension is min(height, width*cos(lat)).
// A circle of radius <= that minimum is fully covered by the centre cell + its 8 neighbours.
const CELL_KM = [null, [5000, 5000], [1250, 625], [156, 156], [39.1, 19.5], [4.9, 4.9], [1.2, 0.61], [0.153, 0.153], [0.038, 0.019], [0.0048, 0.0048]];

export function precisionForRadius(radiusKm, lat = 0) {
  const cos = Math.max(0.01, Math.cos((Math.abs(lat) * Math.PI) / 180));
  for (let p = 9; p >= 1; p--) {
    const [w, h] = CELL_KM[p];
    if (Math.min(h, w * cos) >= radiusKm) return p;
  }
  return 1;
}

/** Cover for a radius query: list of geohash prefixes (centre + neighbours, deduped). */
export function coverPrefixes(lat, lng, radiusKm) {
  const precision = Math.min(precisionForRadius(radiusKm, lat), 7);
  const centre = encodeGeohash(lat, lng, precision);
  return { precision, prefixes: [...new Set([centre, ...neighbors(centre)])] };
}

/** Firestore range bounds for a prefix: [prefix, prefix + '~'). '~' sorts after every base32 char. */
export const prefixRange = (p) => [p, `${p}~`];
