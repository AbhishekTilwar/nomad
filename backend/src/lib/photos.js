/**
 * A Google account picture (lh3.googleusercontent.com/...) is not a photo the
 * person uploaded to Nomad Mingle. Profiles never store one: the app shows an
 * initials avatar until the person adds their own photo (Firebase Storage URLs
 * are a different host, so they are unaffected).
 */
export function isGoogleProfilePhoto(url) {
  if (typeof url !== 'string' || !url) return false;
  let host;
  try { host = new URL(url).hostname.toLowerCase(); } catch { return false; }
  return host === 'googleusercontent.com' || host.endsWith('.googleusercontent.com') || host.endsWith('.ggpht.com');
}

/** [url] unless it is a Google profile picture (then null). */
export const ownPhotoUrl = (url) => (url && !isGoogleProfilePhoto(url) ? url : null);

/** [urls] without Google profile pictures. */
export const ownPhotoUrls = (urls) => (Array.isArray(urls) ? urls.filter((u) => !isGoogleProfilePhoto(u)) : urls);
