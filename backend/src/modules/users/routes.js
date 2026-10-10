import { Router } from 'express';
import { parse, send, wrap } from '../../lib/http.js';
import { requireProfile } from '../../middleware/auth.js';
import { notificationPrefsSchema, deviceTokenSchema } from '../notifications/schemas.js';
import { myActivitiesQuerySchema } from '../activities/schemas.js';
import { userLimiter } from '../../middleware/common.js';
import { putProfileSchema, patchProfileSchema, uidParam, locationSchema, travelersQuerySchema, listQuerySchema } from './schemas.js';

// Per-user (per-instance) throttles for the write endpoints that fan out to other users or move location.
const friendWriteLimiter = userLimiter(30);
const locationLimiter = userLimiter(20);

export function usersRouter({ users, activities, friends }) {
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

  r.put('/me/location', requireProfile, locationLimiter, wrap(async (req, res) =>
    send(res, await users.setLocation(req.user.uid, parse(locationSchema, req.body)))));
  r.get('/me/friends', requireProfile, wrap(async (req, res) => {
    const { items, nextCursor } = await friends.listFriends(req.user.uid, parse(listQuerySchema, req.query));
    send(res, items, { nextCursor });
  }));
  r.get('/me/friend-requests', requireProfile, wrap(async (req, res) =>
    send(res, await friends.listRequests(req.user.uid, parse(listQuerySchema, req.query)))));
  // Must be declared before '/:uid'.
  r.get('/travelers', requireProfile, wrap(async (req, res) => {
    const { items, nextCursor, total } = await users.listTravelers(req.user, parse(travelersQuerySchema, req.query));
    send(res, items, { nextCursor, total });
  }));

  r.get('/:uid', requireProfile, wrap(async (req, res) => {
    const { uid } = parse(uidParam, req.params);
    const [pub, friendship] = await Promise.all([users.getPublic(uid), friends.statusWith(req.user.uid, uid)]);
    send(res, { ...pub, friendship });
  }));
  r.post('/:uid/friend-request', requireProfile, friendWriteLimiter, wrap(async (req, res) => {
    const out = await friends.sendRequest(req.user, parse(uidParam, req.params).uid);
    send(res, out, {}, out.friendship === 'friends' ? 200 : 201);
  }));
  r.post('/:uid/friend-request/accept', requireProfile, friendWriteLimiter, wrap(async (req, res) =>
    send(res, await friends.accept(req.user, parse(uidParam, req.params).uid))));
  r.delete('/:uid/friend', requireProfile, wrap(async (req, res) =>
    send(res, await friends.remove(req.user.uid, parse(uidParam, req.params).uid))));
  r.post('/:uid/block', requireProfile, wrap(async (req, res) =>
    send(res, await users.block(req.user.uid, parse(uidParam, req.params).uid), {}, 201)));
  r.delete('/:uid/block', requireProfile, wrap(async (req, res) =>
    send(res, await users.unblock(req.user.uid, parse(uidParam, req.params).uid))));
  return r;
}
