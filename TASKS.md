# TASKS

_Last updated: 2026-10-10. Only items marked ✅ were actually run/verified; see Test results._

## Completed
- ✅ Phase 0: environment inspection, repo scaffold, README, ARCHITECTURE, DATA_MODEL, API docs
- ✅ Phase 1 (Flutter foundation): design tokens + light/dark theme, reusable components (ActivityCard, ActivityMarker, UserAvatar, InterestChip, PrimaryButton, SecondaryButton, FormField, EmptyState, ErrorState, LoadingSkeleton, CommunityMessageBubble, ChatInput, ReportActionSheet, JoinActivityButton), Provider + go_router, API client, config via dart-define
- ✅ Phase 2 (auth + profile, client side): Google + email/password, verification gate, password reset, 3-step onboarding with server-validated 18+ DOB, profile view/edit, sign-out, account-deletion call, session redirects
- ✅ Explore screen: map/list toggle, city selector, category/free filter chips, markers, recenter, tile-failure fallback to list

- ✅ Phase 3: Express API (all endpoints in docs/API.md), Firestore/Storage rules, indexes, SECURITY + COST_CONTROL docs
- ✅ Phase 4 client: activity details + join/leave/cancel, host participant management, create flow (map picker, preview, cover upload), Discover (pagination, debounced search, filters), optional foreground location

## In progress
- Phase 5 (community chat) is next

## Remaining
- Phase 4 leftovers: viewport-debounced map loading, profile hosted/joined/past lists, no widget tests yet for detail/create/discover screens
- Phase 5: Mingle Community (Explore app-bar icon + unread badge, full-screen route, listener window + pagination, report/block UI)
- Phase 6: activity chat, FCM (channels, permission, preferences UI), reminders
- Phase 7: blocked-users screen, report flows, React admin dashboard
- Phase 8: offline/poor-network QA, Android release signing, iOS release doc, launch checklist
- Profile photo upload + compression (Storage), account deletion re-auth UX
- Crashlytics / App Check / Analytics activation (needs real Firebase project + platform config)
- Profile screen sections: hosted/joined/past activities (needs Phase 4)

## Known issues / limitations
- Tabs Discover, Create, Chats and several routes show an honest "coming soon" screen until their phase lands.
- Privacy policy and Terms are placeholders and **must** be written/reviewed before launch.
- Firebase emulator needs JDK 21+ (machine has 17).
- Backend gaps: App Check not wired, no chat archival job, `q` search is substring-only, rate limiter for IP/user is per-instance (chat limiter is Firestore-backed).
- Cannot run iOS or macOS builds here (Xcode/CocoaPods not installed). Android release signing not configured.
- Public OSM tile server is dev-only; production tile provider not chosen.

## Manual setup required (by the founder)
- Create Firebase project; enable Auth (Google, Email/Password), Firestore, Storage, FCM; run `flutterfire configure`; add SHA-1/SHA-256 for Android Google Sign-In; iOS URL scheme.
- Create backend service-account (stored only in hosting env vars); host API (Render config provided by backend).
- Pick production map tile provider; add keys via dart-define.
- Bootstrap first admin (see docs/SECURITY.md once written).

## Test results
| Suite | Command | Result |
|---|---|---|
| Flutter static analysis | `flutter analyze` | ✅ no issues |
| Flutter tests | `flutter test` | ✅ 68 passed |
| Flutter web build | `flutter build web --dart-define=USE_EMULATOR=true` | ✅ built |
| Android debug build | `flutter build apk --debug` | ✅ built |
| Backend unit/integration (in-memory Firestore fake) | `cd backend && npm test` | ✅ 67 passed (re-run by me) |
| Backend lint | `npm run lint` | ✅ clean (re-run by me) |
| Firestore/Storage rules (emulator) | `cd firebase && npm test` | 24 passed per subagent; NOT re-run by me. Needs JDK 21+ |
| Admin SDK vs emulators smoke | `cd backend && npm run test:emulator` | 1 passed per subagent; NOT re-run by me |

Note: the fake-Firestore tests prove application logic under transaction semantics, not real Firestore locking or index requirements. Nothing has been run against a real Firebase project.
