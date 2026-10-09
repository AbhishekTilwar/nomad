import { createHash } from 'node:crypto';

export const sha256 = (s) => createHash('sha256').update(s).digest('hex');

/** Trim, normalise unicode, strip control + zero-width chars (keeps \n). */
export function cleanText(s) {
  return String(s)
    .normalize('NFKC')
    // eslint-disable-next-line no-control-regex
    .replace(/[\u0000-\u0008\u000B-\u001F\u007F\u200B-\u200F\u2028-\u202F\u2060\uFEFF]/g, '')
    .trim();
}

const LINK_RE =
  /(https?:\/\/|www\.|t\.me\/|wa\.me\/|bit\.ly\/)|\b[a-z0-9-]{2,}\.(com|net|org|in|io|co|me|ly|app|xyz|info|biz|link|gg|ru|cn|tk|top|site|online|shop)\b/i;

export const containsLink = (s) => LINK_RE.test(s);

/** Normalised form used for duplicate detection. */
export const dupKey = (s) => sha256(s.toLowerCase().replace(/\s+/g, ' ').trim());
