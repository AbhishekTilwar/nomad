import { Router } from 'express';
import { parse, send, wrap } from '../../lib/http.js';
import { reportSchema } from './schemas.js';

export function safetyRouter({ safety }) {
  const r = Router();
  r.post('/', wrap(async (req, res) => send(res, await safety.createReport(req.user, parse(reportSchema, req.body)), {}, 201)));
  return r;
}
