import { Router } from 'express';
import { timingSafeEqual } from 'node:crypto';
import { wrap, send } from '../../lib/http.js';
import { AppError, notFound } from '../../lib/errors.js';

const safeEqual = (a, b) => {
  const ba = Buffer.from(a);
  const bb = Buffer.from(b);
  return ba.length === bb.length && timingSafeEqual(ba, bb);
};

/**
 * Scheduled-job endpoints. Not Firebase-authenticated; protected by the `x-cron-secret` header
 * (compared in constant time). Disabled (404) when CRON_SECRET is empty.
 */
export function internalJobsRouter({ config, notifications }) {
  const r = Router();
  r.use((req, _res, next) => {
    if (!config.cronSecret) return next(notFound('Route not found'));
    const given = req.get('x-cron-secret') || '';
    if (!safeEqual(given, config.cronSecret)) return next(new AppError(401, 'unauthenticated', 'Invalid job secret'));
    return next();
  });
  r.post('/reminders', wrap(async (_req, res) => send(res, await notifications.sendReminders())));
  r.post('/complete-ended', wrap(async (_req, res) => send(res, await notifications.completeEnded())));
  return r;
}
