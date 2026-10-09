import { Timestamp } from 'firebase-admin/firestore';

export const ts = (ms) => Timestamp.fromMillis(ms);
export const toMillis = (v) => {
  if (v == null) return null;
  if (typeof v === 'number') return v;
  if (v instanceof Date) return v.getTime();
  if (typeof v.toMillis === 'function') return v.toMillis();
  return null;
};
export { Timestamp };
