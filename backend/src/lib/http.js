import { invalid } from './errors.js';

export const wrap = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

/** Parse `source` of the request with a zod schema; throws validation_failed with field details. */
export function parse(schema, data) {
  const r = schema.safeParse(data ?? {});
  if (!r.success) {
    throw invalid(
      'Validation failed',
      r.error.issues.map((i) => ({ path: i.path.join('.'), message: i.message })),
    );
  }
  return r.data;
}

export const send = (res, data, extra = {}, status = 200) => res.status(status).json({ data, ...extra });
