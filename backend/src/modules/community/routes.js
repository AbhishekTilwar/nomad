import { Router } from 'express';
import { z } from 'zod';
import { parse, send, wrap } from '../../lib/http.js';
import { reportSchema } from '../safety/schemas.js';

export function communityRouter({ chat, safety }) {
  const r = Router();
  r.get('/', wrap(async (req, res) => send(res, await chat.communityRoom(req.user))));
  r.post('/messages', wrap(async (req, res) => {
    const out = await chat.postCommunityMessage(req.user, chat.parseMessageBody(req.body));
    send(res, out.message, {}, out.duplicate ? 200 : 201);
  }));
  r.post('/messages/:id/report', wrap(async (req, res) => {
    const { id } = parse(z.object({ id: z.string().min(1).max(200) }), req.params);
    const body = parse(reportSchema.pick({ reason: true, details: true }), req.body);
    send(res, await safety.createReport(req.user, { ...body, targetType: 'message', targetId: id, context: { roomType: 'community' } }), {}, 201);
  }));
  return r;
}
