import { Timestamp } from 'firebase-admin/firestore';

/** Recursively convert Firestore Timestamps to ISO strings so JSON output is stable. */
export function toJson(value) {
  if (value instanceof Timestamp) return value.toDate().toISOString();
  if (Array.isArray(value)) return value.map(toJson);
  if (value && typeof value === 'object') {
    const out = {};
    for (const [k, v] of Object.entries(value)) out[k] = toJson(v);
    return out;
  }
  return value;
}

export const docToJson = (snap) => ({ id: snap.id, ...toJson(snap.data()) });
