import { z } from 'zod';

const bool = (def) => z.enum(['true', 'false']).default(def).transform((v) => v === 'true');
const int = (def, min = 0, max = Number.MAX_SAFE_INTEGER) =>
  z.coerce.number().int().min(min).max(max).default(def);

const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: int(8080, 1, 65535),
  LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent']).default('info'),
  FIREBASE_PROJECT_ID: z.string().min(1),
  FIREBASE_SERVICE_ACCOUNT_JSON: z.string().optional(),
  ALLOWED_ORIGINS: z.string().default(''),
  TRUST_PROXY: int(0, 0, 10),
  BODY_LIMIT: z.string().regex(/^\d+(b|kb|mb)$/i).default('32kb'),
  REQUEST_TIMEOUT_MS: int(15000, 1000, 120000),
  CHECK_REVOKED_TOKENS: bool('true'),
  IP_RATE_LIMIT_PER_MIN: int(300, 1),
  USER_RATE_LIMIT_PER_MIN: int(120, 1),
  CRON_SECRET: z.string().optional().default(''),
  REMINDER_LEAD_MINUTES: int(60, 5, 1440),
  NEW_ACCOUNT_AGE_HOURS: int(72, 0),
  NEW_ACCOUNT_MSG_LIMIT: int(5, 1),
  ESTABLISHED_MSG_LIMIT: int(20, 1),
  RATE_WINDOW_MINUTES: int(10, 1),
  MESSAGE_MAX_LENGTH: int(500, 1, 2000),
  DUPLICATE_WINDOW_SECONDS: int(30, 0),
  VIOLATION_COOLDOWN_MINUTES: int(10, 1),
  VIOLATION_THRESHOLD: int(3, 1),
  VIOLATION_MAX_COOLDOWN_MINUTES: int(1440, 1),
  VIOLATION_DECAY_HOURS: int(24, 1),
  NEW_ACCOUNT_BLOCK_LINKS: bool('true'),
  MAX_ACTIVE_HOSTED_ACTIVITIES: int(10, 1, 100),
});

/** Parse and validate environment. Throws a readable error listing invalid keys (never values). */
export function loadConfig(env = process.env) {
  const parsed = schema.safeParse(env);
  if (!parsed.success) {
    const keys = parsed.error.issues.map((i) => `${i.path.join('.')}: ${i.message}`).join('; ');
    throw new Error(`Invalid environment configuration -> ${keys}`);
  }
  const c = parsed.data;
  const allowedOrigins = c.ALLOWED_ORIGINS.split(',').map((s) => s.trim()).filter(Boolean);
  if (allowedOrigins.includes('*')) throw new Error('ALLOWED_ORIGINS must list explicit origins, not *');
  if (c.NODE_ENV === 'production' && c.CRON_SECRET && c.CRON_SECRET.length < 24) {
    throw new Error('CRON_SECRET must be at least 24 characters');
  }
  return {
    nodeEnv: c.NODE_ENV,
    port: c.PORT,
    logLevel: c.LOG_LEVEL,
    projectId: c.FIREBASE_PROJECT_ID,
    serviceAccountJson: c.FIREBASE_SERVICE_ACCOUNT_JSON,
    allowedOrigins,
    trustProxy: c.TRUST_PROXY,
    bodyLimit: c.BODY_LIMIT,
    requestTimeoutMs: c.REQUEST_TIMEOUT_MS,
    checkRevoked: c.CHECK_REVOKED_TOKENS,
    ipRateLimitPerMin: c.IP_RATE_LIMIT_PER_MIN,
    userRateLimitPerMin: c.USER_RATE_LIMIT_PER_MIN,
    cronSecret: c.CRON_SECRET,
    reminderLeadMinutes: c.REMINDER_LEAD_MINUTES,
    maxActiveHosted: c.MAX_ACTIVE_HOSTED_ACTIVITIES,
    community: {
      newAccountAgeHours: c.NEW_ACCOUNT_AGE_HOURS,
      newAccountMsgLimit: c.NEW_ACCOUNT_MSG_LIMIT,
      establishedMsgLimit: c.ESTABLISHED_MSG_LIMIT,
      windowMinutes: c.RATE_WINDOW_MINUTES,
      maxLength: c.MESSAGE_MAX_LENGTH,
      duplicateWindowSeconds: c.DUPLICATE_WINDOW_SECONDS,
      violationCooldownMinutes: c.VIOLATION_COOLDOWN_MINUTES,
      violationThreshold: c.VIOLATION_THRESHOLD,
      violationMaxCooldownMinutes: c.VIOLATION_MAX_COOLDOWN_MINUTES,
      violationDecayHours: c.VIOLATION_DECAY_HOURS,
      newAccountBlockLinks: c.NEW_ACCOUNT_BLOCK_LINKS,
    },
  };
}
