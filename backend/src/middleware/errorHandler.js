import { AppError } from '../lib/errors.js';

export function notFoundHandler(req, _res, next) {
  next(new AppError(404, 'not_found', 'Route not found'));
}

export const errorHandler = (logger) => (err, req, res, _next) => {
  if (res.headersSent) return;
  let status = 500;
  let code = 'internal';
  let message = 'Internal server error';
  let details;
  if (err instanceof AppError) {
    ({ status, code, message, details } = err);
  } else if (err?.type === 'entity.too.large') {
    status = 413; code = 'validation_failed'; message = 'Request body too large';
  } else if (err?.type === 'entity.parse.failed' || err instanceof SyntaxError) {
    status = 400; code = 'validation_failed'; message = 'Malformed JSON body';
  } else if (err?.message === 'CORS_ORIGIN_NOT_ALLOWED') {
    status = 403; code = 'forbidden'; message = 'Origin not allowed';
  } else if (err?.code === 10 || err?.code === 'aborted') {
    // Firestore transaction contention exhausted its retries: ask the client to retry.
    status = 503; code = 'internal'; message = 'Temporarily busy, please retry';
  } else {
    // Log the error class and message only; never request bodies.
    (req.log || logger).error({ err: { name: err?.name, message: err?.message, stack: err?.stack } }, 'unhandled error');
  }
  const retry = details?.retryAfterSeconds;
  if (retry) res.set('Retry-After', String(retry));
  res.status(status).json({ error: { code, message, ...(details !== undefined ? { details } : {}) } });
};
