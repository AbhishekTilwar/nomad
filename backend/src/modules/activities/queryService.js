import { coverPrefixes, haversineKm, prefixRange } from '../../lib/geo.js';
import { encodeCursor, decodeCursor } from '../../lib/pagination.js';
import { invalid } from '../../lib/errors.js';
import { toMillis, ts } from '../../lib/time.js';

const CELL_CAP = 150; // max docs read per geohash cell per query
const MAX_SCAN_BATCHES = 5;

/**
 * ActivityQueryService: the only place that knows how activities are searched. A dedicated geo
 * service (e.g. Typesense/Algolia/PostGIS) can replace it by implementing queryByDate/queryNearby.
 *
 * Both methods take `{ filters, limit, cursor }` where `filters.matches(doc)` applies the
 * in-memory predicates (visibility, text, free, minSpots) that are not worth an index.
 */
export function createActivityQueryService({ db, now }) {
  const col = () => db.collection('activities');

  /** Date-ordered query on Firestore indexes: status[+city][+category] + startAt. */
  async function queryByDate({ city, category, fromMs, toMs, matches, limit, cursor }) {
    const c = decodeCursor(cursor);
    if (cursor && !c?.id) throw invalid('Invalid cursor');
    let last = null;
    if (c) {
      last = await col().doc(c.id).get();
      if (!last.exists) throw invalid('Invalid cursor');
    }
    let q = col().where('status', '==', 'scheduled');
    if (city) q = q.where('city', '==', city);
    if (category) q = q.where('category', '==', category);
    q = q.where('startAt', '>=', ts(fromMs));
    if (toMs) q = q.where('startAt', '<=', ts(toMs));
    q = q.orderBy('startAt');

    const batch = Math.max(limit * 2, 25);
    const items = [];
    let exhausted = false;
    let lastScanned = last;
    for (let i = 0; i < MAX_SCAN_BATCHES && items.length <= limit; i++) {
      const snap = await (lastScanned ? q.startAfter(lastScanned) : q).limit(batch).get();
      for (const d of snap.docs) {
        lastScanned = d;
        if (matches(d.data())) items.push(d);
        if (items.length > limit) break;
      }
      if (snap.size < batch) { exhausted = true; break; }
    }
    let nextCursor = null;
    if (items.length > limit) {
      items.length = limit;
      nextCursor = encodeCursor({ id: items[limit - 1].id });
    } else if (!exhausted && lastScanned) {
      nextCursor = encodeCursor({ id: lastScanned.id });
    }
    return { docs: items, nextCursor };
  }

  /**
   * Geohash cover query. One range query per prefix, merged, Haversine post-filtered.
   * Cursor is a keyset on the merged ordering, so each page re-reads the cells (documented limitation).
   */
  async function queryNearby({ lat, lng, radiusKm, fromMs, toMs, sort, matches, limit, cursor }) {
    const { prefixes } = coverPrefixes(lat, lng, radiusKm);
    const c = decodeCursor(cursor);
    if (cursor && (c?.k === undefined || !c?.id)) throw invalid('Invalid cursor');

    const snaps = await Promise.all(
      prefixes.map((p) => {
        const [lo, hi] = prefixRange(p);
        let q = col().where('status', '==', 'scheduled').where('geohash', '>=', lo).where('geohash', '<', hi).where('startAt', '>=', ts(fromMs));
        if (toMs) q = q.where('startAt', '<=', ts(toMs));
        return q.orderBy('geohash').orderBy('startAt').limit(CELL_CAP).get();
      }),
    );
    const seen = new Map();
    for (const s of snaps) {
      for (const d of s.docs) {
        if (seen.has(d.id)) continue;
        const a = d.data();
        if (!matches(a)) continue;
        const dist = haversineKm(lat, lng, a.latitude, a.longitude);
        if (dist > radiusKm) continue;
        seen.set(d.id, { doc: d, distanceKm: dist, k: sort === 'proximity' ? dist : toMillis(a.startAt) });
      }
    }
    let rows = [...seen.values()].sort((x, y) => x.k - y.k || (x.doc.id < y.doc.id ? -1 : 1));
    if (c) rows = rows.filter((r) => r.k > c.k || (r.k === c.k && r.doc.id > c.id));
    const page = rows.slice(0, limit);
    const nextCursor = rows.length > limit ? encodeCursor({ k: page[page.length - 1].k, id: page[page.length - 1].doc.id }) : null;
    return { docs: page.map((r) => r.doc), distances: Object.fromEntries(page.map((r) => [r.doc.id, Math.round(r.distanceKm * 100) / 100])), nextCursor };
  }

  return { queryByDate, queryNearby, now };
}
