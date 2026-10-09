import { z } from 'zod';
import { CITIES } from '../users/schemas.js';

const isoDateTime = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/, 'Must be an ISO 8601 date-time')
  .refine((s) => !Number.isNaN(Date.parse(s)), 'Invalid date-time');
const httpsUrl = z.string().trim().max(1000).refine((u) => {
  try { return new URL(u).protocol === 'https:'; } catch { return false; }
}, 'Must be an https URL');
const category = z.string().trim().toLowerCase().regex(/^[a-z0-9_-]{2,30}$/, 'Invalid category');
const lat = z.number().min(-90).max(90);
const lng = z.number().min(-180).max(180);

const base = {
  title: z.string().trim().min(3).max(100),
  description: z.string().trim().max(2000),
  category,
  city: z.enum(CITIES),
  venueName: z.string().trim().min(2).max(120),
  latitude: lat,
  longitude: lng,
  startAt: isoDateTime,
  endAt: isoDateTime,
  capacity: z.number().int().min(2).max(50),
  costType: z.enum(['free', 'paid']),
  costDescription: z.string().trim().max(300),
  coverImageUrl: httpsUrl.nullable(),
  approvalRequired: z.boolean(),
  visibility: z.enum(['public', 'private']),
  safetyNotes: z.string().trim().max(500),
  cancellationPolicy: z.string().trim().max(500),
};

export const createActivitySchema = z
  .object({
    title: base.title,
    description: base.description.default(''),
    category: base.category,
    city: base.city,
    venueName: base.venueName,
    latitude: base.latitude,
    longitude: base.longitude,
    startAt: base.startAt,
    endAt: base.endAt,
    capacity: base.capacity,
    costType: base.costType.default('free'),
    costDescription: base.costDescription.default(''),
    coverImageUrl: base.coverImageUrl.default(null),
    approvalRequired: base.approvalRequired.default(false),
    visibility: base.visibility.default('public'),
    safetyNotes: base.safetyNotes.default(''),
    cancellationPolicy: base.cancellationPolicy.default(''),
  })
  .strict();

export const patchActivitySchema = z
  .object(Object.fromEntries(Object.entries(base).map(([k, v]) => [k, v.optional()])))
  .strict()
  .refine((o) => Object.keys(o).length > 0, 'At least one field is required')
  .refine((o) => (o.latitude === undefined) === (o.longitude === undefined), 'latitude and longitude must be updated together');

const bool = z.enum(['true', 'false']).transform((v) => v === 'true');
const num = z.coerce.number();

export const listQuerySchema = z
  .object({
    city: z.enum(CITIES).optional(),
    category: category.optional(),
    q: z.string().trim().min(1).max(80).optional(),
    from: isoDateTime.optional(),
    to: isoDateTime.optional(),
    free: bool.optional(),
    minSpots: z.coerce.number().int().min(1).max(50).optional(),
    sort: z.enum(['date', 'proximity', 'relevance']).optional(),
    lat: num.min(-90).max(90).optional(),
    lng: num.min(-180).max(180).optional(),
    radiusKm: num.min(0.1).max(100).optional(),
    limit: z.coerce.number().int().min(1).max(50).default(20),
    cursor: z.string().max(500).optional(),
  })
  .refine((o) => (o.lat === undefined) === (o.lng === undefined), 'lat and lng must be provided together')
  .refine((o) => o.sort !== 'proximity' || o.lat !== undefined, 'sort=proximity requires lat and lng');

export const mapQuerySchema = z.object({
  lat: num.min(-90).max(90),
  lng: num.min(-180).max(180),
  radiusKm: num.min(0.1).max(100).default(10),
  category: category.optional(),
  limit: z.coerce.number().int().min(1).max(200).default(100),
});

export const idParam = z.object({ id: z.string().min(1).max(128) });
export const idUidParam = z.object({ id: z.string().min(1).max(128), uid: z.string().min(1).max(128) });
export const messagesQuerySchema = z.object({
  limit: z.coerce.number().int().min(1).max(100).default(50),
  cursor: z.string().max(500).optional(),
});

export const myActivitiesQuerySchema = z.object({
  role: z.enum(['hosted', 'joined', 'past']).default('joined'),
  limit: z.coerce.number().int().min(1).max(50).default(20),
  cursor: z.string().max(500).optional(),
});
