# Design system

Source of truth: [app/lib/core/theme/app_tokens.dart](../app/lib/core/theme/app_tokens.dart) and `app_theme.dart`. Widgets must use tokens, not literals.

## Colour
| Token | Value | Use |
|---|---|---|
| primary | #0F4C45 | Primary actions, selected state |
| primaryPressed | #0B332F | Pressed |
| primaryLight / tint | #DCEFEA | Soft fills, safety card |
| secondary | #E99A32 | Warm accent |
| sand | #FAF9F6 | Background |
| surface | #FFFFFF | Cards |
| ink / inkMuted | #172B2A / #64716F | Text |
| outline | #E2E7E3 | Borders |
| success / warning / danger / info | #23845B / #B96D12 / #C83F42 / #326CCB | Status |

Dark theme uses brighter primary (#5FB3A5) on #0F1A19 / #172625. Category colours live in `AppColors.categoryColors`; use them only for markers and category chips.

## Type
Inter via the theme's TextTheme (headline for titles, titleSmall for section labels, bodyMedium for content, bodySmall for metadata). Don't hard-code sizes except in tags (12).

## Spacing, radius, elevation, motion
Spacing 4/8/12/16/24/32/40, page gutter 20. Radius: field 12, button 14, card 16, sheet 24, pill 999. Shadows: `card`, `raised` only. Motion: 150/250 ms; no decorative animation.

## Components
`PrimaryButton`, `SecondaryButton`, `JoinActivityButton` (state → label, backend decides eligibility), `ActivityCard`, `ActivityMarker`, `UserAvatar`, `InterestChip`, `FormField`, `EmptyState`, `ErrorState`, `LoadingSkeleton`, `FloatingNavBar`, `ReportActionSheet`.

## Rules
- Minimum touch target 48 dp; add `Semantics` to custom tappables.
- Every list has loading, empty, and error states. Empty states must match the cause (no data vs. filtered out) and offer the way out.
- Copy is factual and warm. Never invent counts or urgency.
- Icons: Material outlined family.
- Open question: contrast of `inkFaint` on `sand` has not been measured.

## Pickers (one family)
Every choice opens the same rounded bottom sheet from `core/widgets/picker_sheets.dart`: `PickerField` (label above, filled tile, chevron) → `showOptionSheet` (single choice; optional icon or flag, optional search for long lists) or `showDateWheelSheet` (title, helper, wheel, live summary or error, labelled action disabled while invalid). Do not add dropdown menus, Material date/time dialogs, or unlabeled check buttons. Sheets must open on the root navigator so they sit above the floating nav bar.
