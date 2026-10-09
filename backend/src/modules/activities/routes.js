import { Router } from 'express';
import { parse, send, wrap } from '../../lib/http.js';
import { createActivitySchema, patchActivitySchema, listQuerySchema, mapQuerySchema, idParam, idUidParam, messagesQuerySchema } from './schemas.js';

export function activitiesRouter({ activities, chat }) {
  const r = Router();

  r.get('/', wrap(async (req, res) => {
    const { items, nextCursor } = await activities.listActivities(req.user, parse(listQuerySchema, req.query));
    send(res, items, { nextCursor });
  }));
  r.get('/map', wrap(async (req, res) => send(res, await activities.mapMarkers(parse(mapQuerySchema, req.query)))));
  r.post('/', wrap(async (req, res) => send(res, await activities.createActivity(req.user, parse(createActivitySchema, req.body)), {}, 201)));

  r.get('/:id', wrap(async (req, res) => send(res, await activities.getActivity(req.user, parse(idParam, req.params).id))));
  r.patch('/:id', wrap(async (req, res) =>
    send(res, await activities.updateActivity(req.user, parse(idParam, req.params).id, parse(patchActivitySchema, req.body)))));

  r.post('/:id/join', wrap(async (req, res) => send(res, await activities.joinActivity(req.user, parse(idParam, req.params).id))));
  r.post('/:id/leave', wrap(async (req, res) =>
    send(res, await activities.leaveActivity({ activityId: parse(idParam, req.params).id, uid: req.user.uid }))));
  r.post('/:id/cancel', wrap(async (req, res) =>
    send(res, await activities.cancelActivity({ activityId: parse(idParam, req.params).id, actor: req.user }))));
  r.post('/:id/approve/:uid', wrap(async (req, res) => {
    const p = parse(idUidParam, req.params);
    send(res, await activities.approve(req.user, p.id, p.uid));
  }));
  r.post('/:id/reject/:uid', wrap(async (req, res) => {
    const p = parse(idUidParam, req.params);
    send(res, await activities.reject(req.user, p.id, p.uid));
  }));
  r.post('/:id/remove/:uid', wrap(async (req, res) => {
    const p = parse(idUidParam, req.params);
    send(res, await activities.removeMember(req.user, p.id, p.uid));
  }));
  r.get('/:id/members', wrap(async (req, res) => send(res, await activities.listMembers(req.user, parse(idParam, req.params).id))));

  r.get('/:id/messages', wrap(async (req, res) => {
    const q = parse(messagesQuerySchema, req.query);
    const { items, nextCursor } = await chat.listActivityMessages(req.user, parse(idParam, req.params).id, q);
    send(res, items, { nextCursor });
  }));
  r.post('/:id/messages', wrap(async (req, res) => {
    const out = await chat.postActivityMessage(req.user, parse(idParam, req.params).id, chat.parseMessageBody(req.body));
    send(res, out.message, {}, out.duplicate ? 200 : 201);
  }));
  return r;
}
