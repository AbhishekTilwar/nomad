import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import { authenticate, requireProfile } from './middleware/auth.js';
import { requireStaff } from './middleware/roles.js';
import { errorHandler, notFoundHandler } from './middleware/errorHandler.js';
import { ipLimiter, requestContext, requestTimeout, userLimiter } from './middleware/common.js';
import { wrap } from './lib/http.js';
import { createNotificationService } from './modules/notifications/service.js';
import { internalJobsRouter } from './modules/notifications/routes.js';
import { createActivitiesService } from './modules/activities/service.js';
import { createUsersService } from './modules/users/service.js';
import { createFriendsService } from './modules/users/friends.js';
import { createChatService } from './modules/community/chat.js';
import { createSafetyService } from './modules/safety/service.js';
import { createAdminService } from './modules/admin/service.js';
import { usersRouter } from './modules/users/routes.js';
import { activitiesRouter } from './modules/activities/routes.js';
import { communityRouter } from './modules/community/routes.js';
import { safetyRouter } from './modules/safety/routes.js';
import { adminRouter } from './modules/admin/routes.js';

/**
 * Composition root. All I/O dependencies (db, auth, messaging, fv, now) are injected so tests can
 * pass in-memory fakes. `fv` = { serverTimestamp(), delete() } wrappers around FieldValue.
 */
export function createApp(deps) {
  const { db, config, logger } = deps;
  const now = deps.now ?? (() => Date.now());
  const base = { ...deps, now };

  const notifications = createNotificationService(base);
  const activities = createActivitiesService({ ...base, notifications });
  const users = createUsersService({ ...base, activities });
  const friends = createFriendsService({ ...base, notifications });
  const chat = createChatService({ ...base, users });
  const safety = createSafetyService(base);
  const admin = createAdminService({ ...base, notifications, activities });

  const app = express();
  app.disable('x-powered-by');
  if (config.trustProxy) app.set('trust proxy', config.trustProxy);

  app.use(requestContext(logger));
  app.use(helmet());
  app.use(cors({
    origin(origin, cb) {
      // Native mobile apps send no Origin header; browsers must be on the allow-list.
      if (!origin || config.allowedOrigins.includes(origin)) return cb(null, true);
      return cb(new Error('CORS_ORIGIN_NOT_ALLOWED'));
    },
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
    allowedHeaders: ['Authorization', 'Content-Type', 'X-Request-Id'],
    maxAge: 600,
  }));
  app.use(requestTimeout(config.requestTimeoutMs));
  app.use(ipLimiter(config.ipRateLimitPerMin));
  app.use(express.json({ limit: config.bodyLimit }));

  app.get('/health', (_req, res) => res.json({ status: 'ok' }));
  app.get('/ready', wrap(async (_req, res) => {
    try {
      await Promise.race([
        db.doc('_health/ping').get(),
        new Promise((_, rej) => setTimeout(() => rej(new Error('timeout')), 3000)),
      ]);
      res.json({ status: 'ready' });
    } catch {
      res.status(503).json({ error: { code: 'internal', message: 'Dependency not ready' } });
    }
  }));

  const v1 = express.Router();
  v1.use('/internal/jobs', internalJobsRouter({ config, notifications }));
  v1.use(authenticate(base));
  v1.use(userLimiter(config.userRateLimitPerMin));
  v1.use('/users', usersRouter({ users, activities, friends }));
  v1.use('/activities', requireProfile, activitiesRouter({ activities, chat }));
  v1.use('/community', requireProfile, communityRouter({ chat, safety }));
  v1.use('/reports', requireProfile, safetyRouter({ safety }));
  v1.use('/admin', requireStaff(base), adminRouter({ admin }));
  app.use('/api/v1', v1);

  app.use(notFoundHandler);
  app.use(errorHandler(logger));
  app.locals.services = { users, friends, activities, chat, safety, admin, notifications };
  return app;
}
