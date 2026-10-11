# Redesign changelog

This pass targeted the join journey (discovery → detail → joined), the highest-impact gaps found in [UX_AUDIT.md](UX_AUDIT.md). The existing visual identity already matched the intended palette, so tokens were left alone. Earlier branding work is in `UI_BRANDING_CHANGELOG.md`.

## Changes
| File | Change | Why |
|---|---|---|
| `activities/presentation/activity_detail_screen.dart` | New **What to expect** card (group size/duration, approval rule, cost, chat) from real fields | Hesitant newcomers couldn't tell what joining means |
| same | "N going · M spots left" / "· full"; removed host avatar beside count and the bare capacity bar | Host avatar read as an attendee; fraction was less clear |
| same | Bottom bar: **Open group chat** primary when joined/hosting; "You'll see the host's reply under the bell on the map" when requested | Clear next step after joining |
| same | **Get directions** (opens maps via url_launcher) and **Share plan** (share_plus, uses existing invite URL) | Getting there; word-of-mouth |
| `explore/presentation/explore_screen.dart`, `explore_controller.dart` | Filtered-empty state with **Clear filters**; `clearFilters()`; better no-plans copy | The old empty state blamed the city, not the filters |
| `test/features/activity_detail_test.dart` | 7 new tests | Cover the above |

## Not done (deliberately)
No new tabs, no schema/backend changes, no new packages, no gamification. Reminders/FCM, analytics events, feedback after meetups, and time-of-day filters remain open (see audit).

## Caveats
- Share text links to the generic invite URL; there are no per-plan deep links.
- The "requested" notice points to the in-app bell: the backend writes a notification on approve/reject, but push delivery is not wired in the app (no device-token registration).
- No on-device visual check or before/after screenshots were possible.

## Emulator pass
| File | Change | Why |
|---|---|---|
| `onboarding/presentation/intro_screen.dart` | Intro copy rewritten to match the product (local group plans, host and expectations visible, group chat) | Old copy described a global traveler community with "rooms" |
| `auth/presentation/welcome_screen.dart` | Tagline now the product promise | Old tagline was poetic but uninformative |
| `test/features/auth_flow_test.dart`, `app_flow_test.dart` | Updated strings | Follow copy |

## Emulator pass 2
| Area | Change |
|---|---|
| Sign-up | Email sign-up is email + password only, same labeled fields as sign-in. Profile questions come from the shared onboarding for every method. `SignupDraft` and its session logic deleted; tests rewritten. |
| Bottom sheets | All 7 `showModalBottomSheet` calls use the root navigator so they sit above the floating nav bar (Create preview, travelers, report, photo source, chat actions, birthday). New regression test. |
| Location | Explore no longer prompts on open (`LocationService.currentIfPermitted`); the locate button asks. |
| Empty map | Banner offers Host one / Clear filters. Explore list empty state distinguishes filters from empty city. |
| Plan card | Adds going/spots left and cost/approval summary; no join toast over the CTA; Report hidden for host. |
| Snackbars | Action snackbars no longer persist. |
| Settings | "Push Notifications" renamed "Allow notifications" with a subtitle. |
| Create plan | "Create a Plan", "Meeting point and notes", hints, no raw coordinates. |

## Behavioural redesign pass
| Area | Change |
|---|---|
| Birthday / age | Wheel sheet with warning, live "You're N · others see X", disabled confirm under 18; own profile shows age range; read-only age card in Edit Profile. `Validators.ageRange` mirrors the server (tested). |
| Photo | Skippable in onboarding; `ensureProfilePhoto` gate on Join (plan card and detail) and Create. Uses a plain navigator route so the result survives session refreshes (regression test). |
| Pickers | New `core/widgets/picker_sheets.dart`. Birthday, plan date/time, category, duration and country all use it. Deleted `AppDropdownField`, `DobFormField`, `InterestPicker`, `_DobSheet`. |
| Explore | List cards show host + venue; distance only when measured from the member; empty states for filters / empty city. |
| Detail | "You're going" card; Open group chat + Leave/Manage bar. |
| Profile | Completion ring removed; "Find a plan" action in empty Upcoming. |
| Onboarding | City as tiles; interest search removed; photo copy says it can wait. |
| Backend | `GET /activities/map` markers add `venueName`, `hostDisplayName`, `hostPhotoUrl`, `approvalRequired` (test and API.md updated). |

## Brand: logo, splash, app name
| Area | Change |
|---|---|
| Logo | `assets/images/brand_logo.png` (supplied) used on the splash and welcome page via `core/widgets/brand_mark.dart`. The welcome page is now light (the logo is dark on a light backdrop); the dusk photo scene stays on the intro only. |
| Animation | Splash: logo fades in, rises and settles (1.1 s, skipped under reduced motion). The splash is held 1.8 s in `main.dart` (`splashMinDuration`, zero in tests) so it can play. Welcome: the same logo at the same screen position (`BrandMark.restAlignment`), so the hand-over keeps it still; buttons then fade and slide in. |
| Native launch | Android launch screen is plain brand background with no icon (`values*/styles.xml`, `brand_colors.xml`, `splash_icon_empty.xml`), so the default Flutter logo no longer flashes before the app starts. |
| App name | "Nomad Mingle" in the Android label, iOS `CFBundleName`, and web title/manifest (iOS display name already was). |
| Icon pipeline | `app/tool/generate_icons.sh master.png` builds all Android, iOS and web icon sizes with `sips` (no new package). Tested against a dummy master in a temp folder; **the real icon is not applied yet** (see below). |

Caveats: the supplied logo PNG is 298x192, so it looks soft on a phone; an SVG or a 3x PNG would fix that. The PNG has faint noise in its backdrop, hidden by feathering its edges. The first ~2 s of a debug launch is blank brand background while the engine starts; release builds start faster (not measured).

## Welcome background
`features/auth/presentation/welcome_backdrop.dart` replaces the flat background. Everything is drawn in code (no assets): sand → soft mint ground that eases in below the logo; faint topographic contours in two corners that breathe slowly; five plan pins (our category colours) that pop in one after another, then bob over a ripple; a dotted route that draws itself between three pins, with a small amber traveller dot looping along it. The Google and Email buttons, legal caption and logo position are unchanged. Reduced motion shows the finished picture with no ticking; it is excluded from semantics. Inspiration is the idea of a living, illustrated welcome; the visual language (map, pins, route) is ours and ties to "find your people, make a plan, go together". Migomap itself was not viewed in this session, so nothing was copied from it.
Caveats: contours are deliberately faint (may need a nudge on bright outdoor screens); the pins are decorative and do not represent real plans.

### Welcome background: real map
The welcome page now shows the real city (Mumbai) using the same `BasemapLayer` as Explore, non-interactive, drifting slowly under a slight zoom (a transform, so tiles are not reloaded while it moves). Sand veils clear the area around the logo and fade the map out under the sign-in block; the plan pins, dotted route and traveller dot are drawn on top. If the map cannot load, the painted ground with topographic contours takes over; reduced motion keeps the map still. The logo image's edge feather was widened so its own backdrop blends into the map.
Caveats: the signed-out welcome now requests map tiles (needs a connection, small data use per cold start); the default tile source is Esri's light-gray canvas, whose terms should be checked before launch (already noted in `map_config.dart`).

### Welcome map: real places, activities and people
Pins are now anchored to real Mumbai places by latitude/longitude (Juhu, Andheri East, Worli, Parel, Wadala), projected with the same camera as the map (`_kMapCenter`, `_kMapZoom`) and drawn inside the map's drift transform, so they stay glued to their spots. Each pin carries its activity icon and category colour (coffee, music, hiking, sports, photography); a small group of people is gathered under each, arriving just after the pin lands; the route runs Worli → Parel → Wadala and a person (not a dot) walks it. All of it is illustrative: the places are real, the plans and people are not, and nothing implies live activity.
Caveats: positions are tuned for a 412x890 phone; other aspect ratios move pins slightly relative to the logo and buttons (the washes keep them readable). A transparent logo is expected later: then the logo's feathering and the clearing around it can be simplified.

### Welcome people: photos slot and more human avatars
- `assets/images/welcome/` accepts `person_1.jpg`..`person_6.jpg` (optional; see its README for licensing and consent rules). `WelcomePeople.load` reads what exists and skips the rest; photos are cropped to circles and used in place of the avatars.
- Without photos, avatars are illustrated people: pastel backdrop, five skin tones, five hair colours, four hair styles (short, long, bun, cropped), five clothing colours, chosen per person so a group never repeats. Slightly larger (18 px) so they read as people.
- No photos were added: none are available, and unconsented stock faces would be fabricated social proof.

### Logo from the supplied SVG
`logo.svg` is a Canva-style export: two embedded PNGs (a colour image and a greyscale mask) rather than vector paths, and flutter_svg does not support SVG masks, so it cannot be drawn directly. `app/tool/svg_logo_to_png.py logo.svg assets/images/brand_logo.png` combines them into a transparent PNG (1100 px wide, 288 KB; full-size 1804x872 source kept at `assets/branding/logo_source.svg`). The tagline is no longer part of the image: `BrandMark` sets "Find your people. Make a plan. Go together." as real text under the logo (crisp at any size, translatable, and it follows the logo in with a short fade). With the transparent logo, the old edge feathering is gone and the clearing around it on the map is smaller and softer.
