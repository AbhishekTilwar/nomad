# UI branding changelog

## Findings (Phase 1)
Flutter app (`app/`). A centralized system already existed: `core/theme/app_tokens.dart`
(colors, spacing, radius, shadows), `core/theme/app_theme.dart` (light and dark ThemeData),
Inter bundled in `assets/fonts` (400/500/600/700), shared widgets in `core/widgets`, and an
existing line-art mountain + script "Nomad Mingle" logo (`BrandLogo`). The work was therefore
a re-skin through the tokens, not a rebuild.

## Design tokens changed (`app_tokens.dart`)
- Palette moved from indigo to the Nomad Mingle brand: Primary `#0F4C45`, Primary pressed
  `#0B332F`, Primary light `#DCEFEA`, Secondary `#E99A32`, Secondary light `#FFF0D8`,
  Background `#FAF9F6`, Surface `#FFFFFF`, Field `#F1F3F0`, Text `#172B2A`/`#64716F`/`#89938F`,
  Border `#E2E7E3`, Success `#23845B`, Warning `#B96D12`, Error `#C83F42`, Info `#326CCB`.
- Dark palette retuned to the same teal family (not an inversion).
- Spacing: added `xxs` (4) and `section` (40). Radius: chip 12, field 12, button 14, card 16,
  sheet 24. Shadows softened and tinted.
- Removed the one-off `navy` color; its 14 uses now use `AppColors.primary`.

## Components standardized
- Theme: filled button (primary, 48px, radius 14), input fields (12px radius, `#F1F3F0` fill,
  primary focus ring), chips (12px rounded rect instead of pill), app bar (no surface tint),
  color-scheme containers (primaryContainer/secondaryContainer).
- `AppChip`: rounded-rect chips.
- Chat wallpaper and settings skyline illustration recolored to the teal palette.
- Auth, onboarding and intro CTAs now use Primary rather than navy.

## Files modified
`core/theme/app_tokens.dart`, `core/theme/app_theme.dart`, `core/widgets/app_chip.dart`,
`core/widgets/chat_background.dart`, `core/widgets/brand_logo.dart`, `features/settings/settings_screens.dart`,
and the navy→primary swaps in auth, onboarding and intro screens, plus comment updates.

## Dependencies added
None.

## Checks run
- `dart format lib`: ran.
- `flutter analyze`: no issues.
- `flutter test`: 191 passed.
- `flutter build apk --debug`: succeeded.

## Known issues / not done
- Not visually inspected on a device or emulator, so spacing, overflow and contrast have not
  been checked by eye. Auth screens are covered by a small-phone overflow test only.
- The logo wordmark keeps the existing handwritten script (existing brand asset, kept as-is).
  No separate compact app-icon asset was added.
- The auth/onboarding scene illustrations (sunset and lake paintings) keep their own
  illustrative colors and were not re-themed.
- The Instagram pill keeps the Instagram brand gradient and Google button keeps Google colors, by design.
- Activity-detail, create-activity and other individual screens were not restyled
  one by one. They inherit changes through the theme and tokens.
- Category marker colors were left unchanged for map legibility.
- Dark mode was refined at palette level only.

## Migomap-style onboarding (post-login)
Reference: Migomap's onboarding after Google login, re-themed with our tokens (teal, amber, Inter, sentence case).
- `OnboardingScreen` is now five steps: name + birthday, gender, city + bio, interests, then the photo screen.
- New shared chrome in `onboarding_widgets.dart`: round back button, slim progress bar, heading with amber icon badge, pinned Continue button that stays disabled until the step is valid.
- Birthday: bottom-sheet wheel picker (CupertinoDatePicker, already in Flutter) with a round confirm button and an age badge; the under-18 message is shown inline.
- Gender: single-select tiles with Skip. New optional `gender` field (`male|female|non_binary`) on `PUT/PATCH /users/me`, stored only in the private profile document. Backend tests: 84 pass.
- Interests: search field, `n/10` counter (max 10), icon chips, Skip.
- Photo: large dashed square tile that opens the existing Take photo / Choose from gallery sheet; shows the chosen photo in the tile. The photo is still required (no Skip).
- Emulator support: `USE_EMULATOR=true` now also points Firestore and Storage at the emulators; a duplicate default Firebase app on Android is tolerated.
- Not copied from Migomap: face detection ("No face found") and the square crop screen. Steps after the photo in Migomap were not seen.
- Checks: `flutter analyze` clean; `flutter test` 192 passed; walked through the flow on the emulator against the local backend.

## Onboarding after the photo, profile, chats and invites (Migomap-inspired)
- **Story step** (`profile_extras_screen.dart`, route `/about-you`, session status `needsProfileExtras`): bio with counter and Instagram handle, skippable. Location is asked once: the city step. The country is filled in automatically from the city (`CityInfo.countryCode`, both launch cities are IN) and can still be changed in Edit Profile; there is no separate "Where's home?" step. Onboarding progress is 6 steps; bio moved out of the city step.
- **Profile:** centered avatar with a completion ring and percentage badge (`UserProfile.completionPercent`), "City · Country" line, Edit profile button, soft cards for About me (tap to add a bio), Photos (empty state "Add your first photo") and Interests. Instagram, stats, upcoming meetups, memories, safety, sign out and delete are unchanged.
- **Chats list:** bigger title, round search and "+" buttons at the top right, All / Unread / Plans filter chips, inline search. The chat conversation view is unchanged. The pinned Mingle Community chat stays.
- **Invite friends** (`/invite`, opened from the "+" in Chats): share on WhatsApp (`https://wa.me/?text=`), invite from contacts (read-only, on-device; each invite opens the SMS composer pre-filled), more ways to share (system share sheet), copy link. Invite link comes from `--dart-define=INVITE_URL=...` (placeholder default `https://nomadmingle.app`).
- **Dependency added:** `flutter_contacts` ^2.1.0. Android: `READ_CONTACTS` (and `WRITE_CONTACTS` explicitly removed). iOS: `NSContactsUsageDescription`.
- **Backend:** photo URLs may be `http://` only when `FIREBASE_STORAGE_EMULATOR_HOST` is set and `NODE_ENV` is not production (local Storage emulator). Optional private `gender` field.
- **Not done / notes:** WhatsApp is not installed on the test emulator, so the link opened in Chrome there. Instagram handle saving was verified by unit test, not on the device. The invite link is a placeholder until a real landing page or store link exists.
- **Checks:** `flutter analyze` clean, `flutter test` 206 passed, backend `npm test` 88 passed, debug build and walkthrough on the Android emulator.
