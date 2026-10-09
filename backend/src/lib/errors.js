export class AppError extends Error {
  constructor(status, code, message, details) {
    super(message);
    this.status = status;
    this.code = code;
    this.details = details;
  }
}
export const unauthenticated = (m = 'Missing or invalid credentials') => new AppError(401, 'unauthenticated', m);
export const forbidden = (m = 'You are not allowed to do this', d) => new AppError(403, 'forbidden', m, d);
export const restricted = (m = 'Your account is restricted', d) => new AppError(403, 'account_restricted', m, d);
export const notFound = (m = 'Not found') => new AppError(404, 'not_found', m);
export const invalid = (m = 'Invalid request', d) => new AppError(400, 'validation_failed', m, d);
export const conflict = (m = 'Conflict', d) => new AppError(409, 'conflict', m, d);
export const rateLimited = (m = 'Too many requests', d) => new AppError(429, 'rate_limited', m, d);
