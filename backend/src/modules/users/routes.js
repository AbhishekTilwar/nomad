import { Router } from 'express';
import { parse, send, wrap } from '../../lib/http.js';
import { requireProfile } from '../../middleware/auth.js';
import { notificationPrefsSchema, deviceTokenSchema } from '../notifications/schemas.js';
import { myActivitiesQuerySchema } from '../activities/schemas.js';
import { putProfileSchema, patchProfileSchema, uidParam } from './schemas.js';

export function usersRouter({ users, activities }) {
  const r = Router();

  r.get('/me', wrap(async (req, res) => send(res, await users.getMe(req.user.uid))));
  r.put('/me', wrap(async (req, res) => {
    const body = parse(putProfileSchema, req.body);
    const out = await users.upsertProfile(req.user, body, { partial: false });
    const { created, ...data } = out;
    send(res, data, {}, created ? 201 : 200);
  }));
  r.patch('/me', wrap(async (req, res) => {
    const body = parse(patchProfileSchema, req.body);
    const { created: _c, ...data } = await users.upsertProfile(req.user, body, { partial: true });
    send(res, data);
  }));
  r.delete('/me', wrap(async (req, res) => send(res, await users.deleteAccount(req.user))));

  r.get('/me/blocks', requireProfile, wrap(async (req, res) => send(res, await users.listBlocks(req.user.uid))));
  r.get('/me/activities', requireProfile, wrap(async (req, res) => {
    const { items, nextCursor } = await activities.listMyActivities(req.user, parse(myActivitiesQuerySchema, req.query));
    send(res, items, { nextCursor });
  }));
  r.put('/me/notification-prefs', requireProfile, wrap(async (req, res) =>
    send(res, await users.setPrefs(req.user.uid, parse(notificationPrefsSchema, req.body)))));
  r.post('/me/device-tokens', requireProfile, wrap(async (req, res) =>
    send(res, await users.addDeviceToken(req.user.uid, parse(deviceTokenSchema, req.body)), {}, 201)));
  r.delete('/me/device-tokens/:token', requireProfile, wrap(async (req, res) =>
    send(res, await users.removeDeviceToken(req.user.uid, req.params.token))));

  r.get('/:uid', requireProfile, wrap(async (req, res) => send(res, await users.getPublic(parse(uidParam, req.params).uid))));
  r.post('/:uid/block', requireProfile, wrap(async (req, res) =>
    send(res, await users.block(req.user.uid, parse(uidParam, req.params).uid), {}, 201)));
  r.delete('/:uid/block', requireProfile, wrap(async (req, res) =>
    send(res, await users.unblock(req.user.uid, parse(uidParam, req.params).uid))));
  return r;
}
