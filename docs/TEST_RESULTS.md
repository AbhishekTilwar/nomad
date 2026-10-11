# Test results

Run on 2026-10-11, Flutter 3.41.4, from `app/`.

| Check | Command | Result |
|---|---|---|
| Static analysis (baseline, before changes) | `flutter analyze` | No issues |
| Unit/widget tests (baseline) | `flutter test` | 206 passed |
| Static analysis (after) | `flutter analyze` | No issues |
| Unit/widget tests (after) | `flutter test` | 213 passed (7 new in `activity_detail_test.dart`) |

## Journeys covered by automated tests
Existing suites cover: first run/intro, sign-up validation, route smoke for every screen, profile edit, public profile report/block, settings, chats, invite, explore controller. New tests cover plan detail states (open, approval, requested, joined, full), directions/share entry points, and filter reset.

## Not verified
- App was **not run** on an emulator or device (none available); no screenshots; layout, map rendering, and gestures are only checked via widget tests.
- Share sheet and maps launch call real platform plugins; only their entry points are tested.
- Notification preferences, report/block flows, and network-error states rely on pre-existing tests; not re-exercised end to end against the live backend.
- No usability testing with real users; persona walkthroughs are simulated heuristics.
- Backend tests were not run (backend untouched).

## Emulator session (2026-10-11)
- `flutter analyze`: no issues. `flutter test`: all passed after the copy changes (intro/welcome tests updated to the new strings).
- Android emulator launched; debug APK built and installed; intro → welcome → email sign-in inspected via screenshots; new copy confirmed on device.
- **Blocked:** no backend (JDK 17 vs. emulator suite's JDK 21 requirement; real Firebase project intentionally not used). Authenticated journeys A (after sign-in) and B–J remain unexercised on a device. Keyboard behaviour and error states unverified.

## Emulator session 2: authenticated journeys (2026-10-11)
- Static analysis: no issues. Unit/widget tests: **213 passed**.
- Android emulator + local Firebase emulators + real backend code (see UX_AUDIT "Live emulator pass 2"). Journeys exercised on device: email sign-up, email verification, onboarding (name/birthday, gender skip, city, interests, photo upload through the system picker, bio skip), location permission deny, Explore map, create plan (all fields, map picker, preview, publish), plan detail as host and as joiner, join, leave, plan group chat (send), community chat (send), profile, settings, notification preferences, blocked users, guidelines, location switch, public profile, block confirmation (cancelled), sign out, sign in.
- Backend calls observed in logs: profile create 201, photo patch 200.
- **Not verified on device:** see the list at the end of the UX_AUDIT section. Google sign-in was not used (the emulator's Google account is the user's own).
- **Caveat:** the on-device chat check needed the temporary google-services workaround described in UX_AUDIT. Without it, chat fails in emulator mode on Android.
- The regression test for sheets covering the nav bar was confirmed to fail when the fix is reverted (the failure is a side effect, a tab switch behind the sheet), and to pass with the fix.

## Behavioural redesign pass (2026-10-11)
- `flutter analyze`: no issues. `flutter test`: **227 passed** (new: picker sheets, photo gate incl. continue-after-photo regression, a test that the map shows no per-plan banner, age-range buckets, onboarding skip). `npm test` (backend): **88 passed**.
- Emulator + local Firebase emulators, second and third local accounts. Verified on device: birthday sheet and tile, city tiles, interests, photo skip, join gate from card and detail with photo upload and automatic continue, create-plan pickers (category, date and time, duration), own profile, edit profile age card and country sheet, location denial, offline detail error and recovery.
- The first "Try again" after restarting the backend failed because it raced the server start; a second tap recovered.
- A bug found only on device: the photo prompt used a router route, so the join was silently dropped when the session refreshed. Fixed; the widget test (with `refreshListenable`) now reproduces and guards it.
- Not verified: Google sign-in, Discover filters, delete account, TalkBack/large text, many-plan density, real push.

## Brand pass
`flutter analyze`: no issues. `flutter test`: 227 passed (new: splash holds then hands over; landing asserts the logo image and its semantics label). On device: native launch shows no Flutter logo; splash animation and hand-over captured frame by frame; one logo throughout after aligning both screens (an earlier build showed two logos cross-fading, fixed). Not done: app icon (file not received), iOS build (no Xcode here).

Welcome background: `flutter analyze` clean; `flutter test` 230 passed (new: animates without errors, reduced motion never ticks, fits 360x640). On device: frames captured mid-intro and after the route finished; buttons unchanged.

Welcome map background: `flutter analyze` clean, `flutter test` 230 passed; on device the Mumbai map renders behind the logo with pins, route and unchanged buttons (three builds iterated: logo box visible → feather and clearing widened → clean). Offline fallback is covered by code path (tile-error callback) but was not forced on device.

Welcome pins: analyze clean, tests pass (231). On device: pins on land at the named places, clear of the status bar and sign-in block; people groups and walking figure visible.

Welcome people: 233 tests pass (new: loader returns empty when no photos, loads provided ones and skips missing or broken files). On device: varied illustrated people at all five pins and walking the route. The real-photo rendering path is covered by the loader test only; no photos exist yet to see on device.

New logo + tagline: analyze clean, 233 tests pass (landing test now asserts the logo image and the tagline text). On device: crisp transparent logo on the splash (fades in) and on the welcome map; tagline legible under it. Note: in one capture the basemap fell back to the grey raster style (network timing); not investigated.

Release build (Android): split APKs + universal APK + AAB built (see RELEASE_BUILD.md). The first attempt showed "Firebase isn't configured" because the dart-defines were passed as one unquoted zsh string; rebuilt with an array and verified the real-project launch. Tests: 233 passed before the build.

Release misconfiguration guard: 235 tests pass (new: local-only address detection, guard never triggers in tests). On device: a release built without API_BASE_URL now shows "Server address isn't set" at launch. Connection failures now read "Couldn't reach Nomad Mingle" instead of "No internet connection". Found while verifying: installing a non-split APK over a split one fails with a version-code downgrade error (split builds add 2000 to the version code); uninstall first.
