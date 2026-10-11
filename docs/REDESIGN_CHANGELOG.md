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
