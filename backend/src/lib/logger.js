import pino from 'pino';

/**
 * Structured logger. Redacts credentials and any field that could carry user message text.
 * Message bodies must never be logged: services log ids and outcomes only.
 */
export function createLogger(level = 'info', destination) {
  return pino({
    level,
    redact: {
      paths: [
        'req.headers.authorization',
        'req.headers.cookie',
        'req.headers["x-cron-secret"]',
        'headers.authorization',
        'authorization',
        'token',
        '*.token',
        'text',
        '*.text',
        'body',
        'req.body',
      ],
      censor: '[redacted]',
    },
  }, destination);
}
