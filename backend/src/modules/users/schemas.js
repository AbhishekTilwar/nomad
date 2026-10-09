import { z } from 'zod';

export const CITIES = ['mumbai', 'pune', 'other'];
const isoDate = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, 'dateOfBirth must be an ISO date (YYYY-MM-DD)')
  .refine((s) => {
    const d = new Date(`${s}T00:00:00Z`);
    return !Number.isNaN(d.getTime()) && d.toISOString().startsWith(s);
  }, 'Invalid date');
const httpsUrl = z.string().trim().max(1000).refine((u) => {
  try {
    return new URL(u).protocol === 'https:';
  } catch {
    return false;
  }
}, 'Must be an https URL');
const tag = z.string().trim().toLowerCase().min(1).max(30);

const fields = {
  displayName: z.string().trim().min(2).max(40),
  bio: z.string().trim().max(300),
  city: z.enum(CITIES),
  interests: z.array(tag).max(15),
  preferredActivityTypes: z.array(tag).max(15),
  dateOfBirth: isoDate,
  photoUrl: httpsUrl.nullable(),
};

/** PUT: create (displayName, city, dateOfBirth required) or complete/replace editable fields. */
export const putProfileSchema = z
  .object({
    displayName: fields.displayName,
    city: fields.city,
    bio: fields.bio.optional(),
    interests: fields.interests.optional(),
    preferredActivityTypes: fields.preferredActivityTypes.optional(),
    dateOfBirth: fields.dateOfBirth.optional(),
    photoUrl: fields.photoUrl.optional(),
  })
  .strict();

export const patchProfileSchema = z
  .object({
    displayName: fields.displayName.optional(),
    city: fields.city.optional(),
    bio: fields.bio.optional(),
    interests: fields.interests.optional(),
    preferredActivityTypes: fields.preferredActivityTypes.optional(),
    dateOfBirth: fields.dateOfBirth.optional(),
    photoUrl: fields.photoUrl.optional(),
  })
  .strict()
  .refine((o) => Object.keys(o).length > 0, 'At least one field is required');

export const uidParam = z.object({ uid: z.string().min(1).max(128) });
