import { randomUUID } from 'node:crypto';
import rateLimit, { ipKeyGenerator } from 'express-rate-limit';
import { AppError } from '../lib/errors.js';

export function requestContext(logger) {
  return (req, res, next) => {
    req.id = req.get('x-request-id')?.slice(0, 64) || randomUUID();
    res.set('x-request-id', req.id);
    req.log = logger.child({ reqId: req.id });
    const start = process.hrtime.bigint();
    res.on('finish', () => {
      req.log.info(
        {
          method: req.method,
          path: req.baseUrl + (req.route?.path ?? req.path),
          status: res.statusCode,
          ms: Number((process.hrtime.bigint() - start) / 1_000_000n),
          uid: req.user?.uid,
        },
        'request',
      );
    });
    next();
  };
}

export function requestTimeout(ms) {
  return (req, res, next) => {
    const timer = setTimeout(() => {
      if (!res.headersSent) {
        res.status(503).json({ error: { code: 'internal', message: 'Request timed out' } });
      }
    }, ms);
    const clear = () => clearTimeout(timer);
    res.on('finish', clear);
    res.on('close', clear);
    next();
  };
}

const limited = (_req, _res, next) => next(new AppError(429, 'rate_limited', 'Too many requests'));

export const ipLimiter = (perMin) =>
  rateLimit({
    windowMs: 60_000,
    limit: perMin,
    standardHeaders: true,
    legacyHeaders: false,
    keyGenerator: (req) => ipKeyGenerator(req.ip ?? '0.0.0.0'),
    handler: limited,
  });

/** Per-user limiter; must run after authenticate. In-memory: per instance (see README). */
export const userLimiter = (perMin) =>
  rateLimit({
    windowMs: 60_000,
    limit: perMin,
    standardHeaders: true,
    legacyHeaders: false,
    keyGenerator: (req) => req.user?.uid ?? ipKeyGenerator(req.ip ?? '0.0.0.0'),
    handler: limited,
  });
