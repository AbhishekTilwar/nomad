import { Router } from 'express';
import { parse, send, wrap } from '../../lib/http.js';
import { cancelBody, dismissBody, messageBody, messageParams, muteBody, reinstateBody, reportIdParam, reportsQuery, suspendBody, userParam } from './schemas.js';
import { idParam } from '../activities/schemas.js';

/** Mounted behind authenticate + requireStaff. */
export function adminRouter({ admin }) {
  const r = Router();
  r.get('/reports', wrap(async (req, res) => {
    const { items, nextCursor } = await admin.listReports(parse(reportsQuery, req.query));
    send(res, items, { nextCursor });
  }));
  r.post('/reports/:id/dismiss', wrap(async (req, res) =>
    send(res, await admin.dismissReport(req.staff, parse(reportIdParam, req.params).id, parse(dismissBody, req.body).reason))));
  r.post('/messages/:room/:id/:action', wrap(async (req, res) => {
    const p = parse(messageParams, req.params);
    send(res, await admin.moderateMessage(req.staff, p.room, p.id, p.action, parse(messageBody, req.body)));
  }));
  r.post('/users/:uid/suspend', wrap(async (req, res) =>
    send(res, await admin.changeUser(req.staff, parse(userParam, req.params).uid, 'suspend', parse(suspendBody, req.body)))));
  r.post('/users/:uid/mute', wrap(async (req, res) =>
    send(res, await admin.changeUser(req.staff, parse(userParam, req.params).uid, 'mute', parse(muteBody, req.body)))));
  r.post('/users/:uid/reinstate', wrap(async (req, res) =>
    send(res, await admin.changeUser(req.staff, parse(userParam, req.params).uid, 'reinstate', parse(reinstateBody, req.body)))));
  r.post('/activities/:id/cancel', wrap(async (req, res) =>
    send(res, await admin.cancelActivity(req.staff, parse(idParam, req.params).id, parse(cancelBody, req.body).reason))));
  r.get('/metrics', wrap(async (_req, res) => send(res, await admin.metrics())));
  return r;
}
