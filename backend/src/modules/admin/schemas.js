import { z } from 'zod';

const reason = z.string().trim().min(3).max(300);
export const reportsQuery = z.object({
  status: z.enum(['open', 'actioned', 'dismissed']).default('open'),
  limit: z.coerce.number().int().min(1).max(50).default(25),
  cursor: z.string().max(300).optional(),
});
export const reportIdParam = z.object({ id: z.string().min(1).max(100) });
export const dismissBody = z.object({ reason }).strict();
export const messageParams = z.object({ room: z.string().min(1).max(128), id: z.string().min(1).max(200), action: z.enum(['hide', 'remove']) });
export const messageBody = z.object({ reason, reportId: z.string().min(1).max(100).optional() }).strict();
export const userParam = z.object({ uid: z.string().min(1).max(128) });
export const suspendBody = z.object({ reason, reportId: z.string().min(1).max(100).optional() }).strict();
export const muteBody = z.object({ reason, durationHours: z.number().int().min(1).max(720).default(24), reportId: z.string().min(1).max(100).optional() }).strict();
export const reinstateBody = z.object({ reason }).strict();
export const cancelBody = z.object({ reason }).strict();
