# Nomad Mingle public website

A lightweight, static showcase plus public Privacy Policy and Delete Account pages. It uses the app's bundled Nomad Mingle logo assets, Inter font files and brand palette. There are no runtime dependencies or tracking scripts.

## Local build

From this directory:

```sh
npm run build
python3 -m http.server 8000 --directory dist
```

Open `http://localhost:8000`. The public pages are available at `/privacy-policy` and `/delete-account` (Vercel clean URLs are enabled).

## Deploy to Vercel

Import this repository and set **Root Directory** to `website`. Vercel will run `npm run build` and publish `dist/`. Alternatively, use the Vercel CLI from this directory.

The public URLs will be:

- `https://<your-domain>/`
- `https://<your-domain>/privacy-policy`
- `https://<your-domain>/delete-account`

## Required legal launch work

The legal pages are a careful product-specific draft, not legal advice. Before publishing, replace every bracketed operator/contact placeholder, confirm jurisdiction and service-provider details, and adopt and implement a definite retention schedule for de-identified chat content and moderation records. The current backend does not set an automatic expiry for those records; the Delete Account page says so rather than promising a period the service does not currently enforce.
