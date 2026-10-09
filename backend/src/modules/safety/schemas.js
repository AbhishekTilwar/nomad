import { z } from 'zod';

export const reportSchema = z.object({
  targetType: z.enum(['message', 'user', 'activity']),
  targetId: z.string().trim().min(1).max(200),
  reason: z.enum(['spam', 'harassment', 'unsafe', 'inappropriate', 'other']),
  details: z.string().trim().max(1000).optional(),
  context: z.object({
    roomType: z.enum(['community', 'activity']).optional(),
    activityId: z.string().trim().min(1).max(128).optional(),
    messageId: z.string().trim().min(1).max(200).optional(),
  }).optional(),
});
