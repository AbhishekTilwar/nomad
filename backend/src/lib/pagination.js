import { z } from 'zod';

export const limitParam = (def = 20, max = 50) =>
  z.coerce.number().int().min(1).max(max).default(def);

export const encodeCursor = (obj) => Buffer.from(JSON.stringify(obj)).toString('base64url');
export function decodeCursor(c) {
  if (!c) return null;
  try {
    return JSON.parse(Buffer.from(c, 'base64url').toString('utf8'));
  } catch {
    return undefined; // caller turns into validation error
  }
}
