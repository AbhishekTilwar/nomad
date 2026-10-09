import { z } from 'zod';

export const notificationPrefsSchema = z
  .object({
    joinRequests: z.boolean(),
    approvals: z.boolean(),
    activityUpdates: z.boolean(),
    reminders: z.boolean(),
    moderation: z.boolean(),
  })
  .partial()
  .strict();

export const deviceTokenSchema = z.object({
  token: z.string().trim().min(20).max(4096),
  platform: z.enum(['android', 'ios', 'web']),
});
