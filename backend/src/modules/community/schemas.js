import { z } from 'zod';
import { invalid } from '../../lib/errors.js';
import { cleanText } from '../../lib/text.js';

export const clientMessageId = z.string().regex(/^[A-Za-z0-9_-]{8,64}$/, 'clientMessageId must be 8-64 chars [A-Za-z0-9_-]');

export function messageBodySchema(maxLength) {
  return z.object({
    // Hard pre-limit so pathological payloads are cheap to reject; the exact limit is checked after cleaning.
    text: z.string().max(maxLength * 8, 'Message too long'),
    clientMessageId: clientMessageId.optional(),
  }).strict();
}

/** Clean + length validation shared by community and activity chat. */
export function cleanMessageText(raw, maxLength) {
  const text = cleanText(raw);
  if (!text) throw invalid('Message cannot be empty', [{ path: 'text', message: 'Message cannot be empty' }]);
  if ([...text].length > maxLength) {
    throw invalid(`Message must be at most ${maxLength} characters`, [{ path: 'text', message: `Maximum ${maxLength} characters` }]);
  }
  return text;
}
