# UX audit

**Method and limits.** Heuristic review from reading the code, the route table, and running the widget suite (206 tests at baseline). No emulator or device was available in this session (`flutter devices` listed none), so there are **no screenshots and no real-device observations**. Persona walkthroughs below are *simulated*, not user research. Nothing here is based on analytics, because none is wired up beyond the Firebase dependencies.

Labels: **[V]** verified in code/tests, **[H]** reasonable hypothesis, **[R]** needs real user research.

## Information architecture (verified)
Bottom bar is Map / Chat / Profile (3 tabs). Create is the map's + button, notifications are the map's bell, the global community chat is pinned at the top of Chat, Discover is the list toggle on the map. This is a deliberate simplification already made in the repo, so no tabs were added. **[V]** Whether "Discover" being a toggle rather than a tab hurts findability is **[R]**.

## Scores (1–10, simulated heuristic judgement)
| Area | Score | Reasoning |
|---|---|---|
| Visual hierarchy | 7 | Tokens and theme are centralised and consistent; detail screen buried the join rules below the fold. |
| Ease of understanding | 7 | Clear core promise; "what happens when I join" was implicit. |
| Steps to task | 8 | Map → card → Join is short. Joined users had to scroll to find the chat. |
| Cognitive load | 7 | Map header has several controls (pill, bell, toggle, +); acceptable. |
| Navigation clarity | 8 | Three predictable tabs. |
| Accessibility | 7 | 48dp targets and Semantics on nav and host card; contrast of faint text not measured. **[R]** screen-reader pass. |
| Emotional appeal | 7 | Warm palette, welcoming copy. |
| Trust and safety | 7 | Report, block, safety notes, public-place reminder exist; host profile link present. |
| Social motivation | 6 | No first-timer reassurance before joining. |
| Performance | 7 | Viewport-scoped map loading, pagination in Discover. Not measured. |
| Empty states | 6 → 8 | Filtered-to-nothing showed "Be the first to host", which is wrong. Fixed. |
| Error recovery | 7 | ErrorState with retry exists. |
| Mobile usability | 7 | Small-phone layout tests exist for auth only. |
| Retention potential | 6 | Real reasons to return (plans, chat) exist; reminders and FCM are not built yet (TASKS.md). |
| Engineering complexity | 8 | Provider + go_router, small controllers, fakes for tests. |

## Findings
| # | Sev | Finding | Status |
|---|---|---|---|
| 1 | P1 | Plan detail had no plain-language "what to expect" (group size, approval, cost, chat). A hesitant newcomer must infer it. **[V]** | Fixed: "What to expect" card built only from real fields. |
| 2 | P1 | After joining, the next step (group chat) was a button far down the page; the bottom bar said "Joined · tap to leave". **[V]** | Fixed: "Open group chat" is the primary action when joined/hosting. |
| 3 | P1 | Explore list: active filters yielding zero results showed "No plans here yet / be the first to host". **[V]** | Fixed: "No plans match your filters" with Clear filters. |
| 4 | P1 | "Requested" state didn't say what happens next. **[V]** | Fixed: "You'll see the host's reply under the bell on the map." Backend verified: approve/reject write an in-app notification (respecting prefs). |
| 5 | P2 | Host avatar sat beside "N going", reading as an attendee. Capacity shown as bare "2 / 6". **[V]** | Fixed: "2 going · 4 spots left" / "· full". |
| 6 | P2 | No way to open the venue in a maps app or share a plan. **[V]** | Fixed: Get directions, Share plan. |
| 7 | P1 | Backend sends in-app notifications and has a reminder job, but the app never registers a device token (no `FirebaseMessaging` use), so **no push is delivered**; post-meetup feedback is not built. Needs a real Firebase/APNs setup. **[V]** | Open |
| 8 | P1 | Privacy policy and Terms are placeholders. **[V]** | Open, launch blocker |
| 9 | P2 | Dark-theme, small-phone and large-text layouts untested outside auth. **[H]** | Open |
| 10 | P1 | Cold-start supply: a city with few plans looks empty. Needs seeded real events by the team, never fake ones. **[H]** | Open (ops, not code) |

## Persona walkthroughs (simulated)
- **Newcomer / hesitant:** #1, #2, #5 addressed. Still missing: a low-pressure "good first plan" signal. Only add it if derived from real data (small group, free, approval-free); not implemented.
- **Busy professional:** filters (category, free, date, radius) exist. Time-of-day filter absent. **[H]**
- **Organizer:** create, edit, cancel, manage members all exist. Messaging all participants about a change is not a separate feature; group chat is the channel.
- **Returning user:** Chats and Profile show history; no "plans this weekend" summary. **[H]**
- **Safety-conscious:** report plan/user, block list, safety notes, venue-only map (no live location) verified.

## Live emulator pass (2026-10-11)
**Environment.** Android emulator `NomadTest` (API 36.1, 1080x2400, 420 dpi), debug APK built with `USE_EMULATOR=true`. **No backend was reachable**: the Firebase emulators need JDK 21 (machine has 17), and I deliberately did not create accounts in the real Firebase project. So only the signed-out screens were exercised: intro (3 pages), welcome, email sign-in. Sign-up, onboarding, Explore, detail, chat, create, profile, settings were **not** run on a device in this pass.

**Observed (verified on device)**
| # | Sev | Observation | Principle | Action |
|---|---|---|---|---|
| L1 | P1 | Intro said "global community of travelers", "Meet Locals", "join rooms", "not just a traveler anymore". The product is local small-group plans in Mumbai/Pune, with one community chat and no rooms. | Expectation match: copy that promises something else erodes trust at first contact | Rewrote: "Find Your People / Make a Plan / Go Together" with concrete, true descriptions. Verified on device. |
| L2 | P1 | Welcome tagline "New places. New people. Same sky." says nothing about what the app does. | First-impression clarity | Now "Find your people. Make a plan. Go together." Verified on device. |
| L3 | P2 | Sign-in screen: clear hierarchy, labelled fields, Google and email both visible. "Forgot password?" is low-salience grey (acceptable for a secondary action). | Salience | No change. |
| L4 | P2 | Backing out of sign-in with filled fields triggered Android's "Save password?" sheet for a password never submitted. | Autofill context committed on dispose | Not fixed. Candidate: `TextInput.finishAutofillContext(shouldSave: false)` on back. Needs a repeat to confirm cause. **[H]** |

**Hypotheses, not evidence:** the new first-run copy improves understanding of the app and onboarding completion. Measure with onboarding completion and a 5-second comprehension test. Not measured.

**Could not test:** soft-keyboard overlap (emulator used a hardware keyboard, adb typing was unreliable), error states for failed sign-in, permission prompts, anything after authentication.

## Live emulator pass 2: signed-in journeys (2026-10-11)
**Environment.** Android emulator (API 36.1, 1080x2400). Local Firebase Auth/Firestore/Storage emulators (JDK 21 installed via Homebrew) plus the real backend code on a separate port, all under project `demo-nomadmingle`. Two local test accounts (host "Ravi", joiner "Maya"). Nothing touched the real Firebase project. Screenshots were inspected during the session; they are not stored in the repo.

**Environment pitfall (not an app bug).** `android/app/google-services.json` belongs to the real project `nomad-a1150`, so on Android the native default app wins over `USE_EMULATOR`'s demo options (`duplicate-app` is swallowed in `main.dart`). Firestore listeners then query the emulator under the wrong project name and every chat read fails with `PERMISSION_DENIED` ("You no longer have access to this chat"). For the test I temporarily pointed the file at the demo project, rebuilt, and restored the original (git shows it unchanged). Anyone running emulator mode on Android will hit this; a proper fix is a named secondary Firebase app or a dev-only google-services file.

| # | Sev | Observation (verified on device) | Action |
|---|---|---|---|
| S1 | P0 | Sign-up (email) and onboarding (Google) were different flows and field sets: email asked name, email, password, DOB, city and 3+ interests on one page; Google used a 6-step wizard with different rules (1+ interest). Fields also looked different from sign-in (icons, no labels). The empty DOB field was missing from the accessibility tree. | Email sign-up now asks only email + password with the same labeled fields as sign-in; everything else is the shared onboarding. Draft mechanism removed. |
| S2 | P0 | Create-plan **Preview** bottom sheet opened under the floating nav bar: "Keep editing" was fully covered and "Publish plan" half covered. Same defect risk for every sheet opened inside the shell. | All 7 bottom sheets use the root navigator. Verified on device. Regression test added. |
| S3 | P1 | Location permission prompt appeared on every launch right after the map opened, with no explanation, and returned after a single deny. | Map no longer prompts; it centres on the user only if permission was already granted. The locate button asks, in context. |
| S4 | P1 | Empty map said "Try moving the map" with no way forward (no plans exist city-wide in a new city). | Banner now says "No plans in this area yet" with a **Host one** action (or **Clear filters** when filters are on). |
| S5 | P1 | Map plan card: Join button with no cost, spots, or approval rule shown. | Card shows "N going · M spots left" and "Free · Open to join" (real fields). |
| S6 | P1 | "You're in!" toast covered the card's next-step button (Join Chat) for several seconds. "Your plan is live on the map!" stayed on screen indefinitely (action snackbars persist by default) across screens. | Join toast removed (the card itself shows the result); action snackbars no longer persist. |
| S7 | P1 | Settings switch labelled "Push Notifications", but the app registers no device token, so nothing is pushed; the switch really gates all notifications. | Renamed "Allow notifications" with a subtitle. |
| S8 | P2 | Create screen: header "Create a Meetup" vs button "Create Plan"; "Safety notes" field with a "meeting point, what to bring" hint; no hint on cancellation policy; location showed raw coordinates. | Header "Create a Plan"; field "Meeting point and notes"; hints added; "Pin dropped on the map. Tap to change." |
| S9 | P2 | Host saw a red "Report plan" icon on their own plan card. | Hidden for hosts (matches detail screen). |

**Worked well (verified):** map renders with real tiles; marker tap opens the card; plan creation end to end (date/time pickers default to tomorrow and block past dates); publishing focuses the new pin; join updates attendee list and count; leave asks for confirmation and reverts; group chat and community chat send and show delivery ticks; community chat and group chat each carry a short guidelines notice; profile, public profile (age range, not exact age), notification preferences, blocked users, guidelines, location screens all load; block asks for confirmation and states it is reversible; sign out confirms.

**Open observations (not changed)**
- Eight screens (credentials, verify email, name+birthday, gender, city, interests, photo, bio; gender and bio are skippable) before a new user sees any plan. Photo is deliberately required (existing decision and test); the trade-off between trust and drop-off needs real data. **[H]**
- City step is a full screen for a 2-option dropdown; interests step has a search box for 12 chips. **[H]**
- Gender is collected (optional) although it is "never shown"; question whether it is needed at all. **[H]**
- Profile shows a "67% complete" ring and "0 Joined"; both can read as pressure to a brand-new member. **[H]**
- Stranger's profile leads with a large "Add Friend"; report/block sit behind "...". In a non-dating product the primary action there may be wrong. **[H]**
- The joined/hosting bottom bar uses two large buttons and takes roughly a third of the screen. **[H]**
- Terminology mixes "plan" and "meetup" (Profile, Settings still say Meetups). **[V]**
- Time picker's selected AM/PM chip is blue, off-theme. **[V]**
- Not exercised on device: Discover/list view, filters screen, edit profile, delete account, forgot password, notification bell list, reporting submit, host member management, a second user requesting to join an approval plan, offline/network-error states, TalkBack, large-text.

## Behavioural redesign pass (2026-10-11, emulator-verified)
Screens were inspected on the emulator before and after each change; screenshots live only in the session (scratchpad), not in the repo. "Before" evidence is from the earlier passes above.

### What was wrong with birthday and age (user-reported, verified)
| Weakness | Principle | Change | Validate |
|---|---|---|---|
| The birthday was collected, then never reflected anywhere: no age on the user's own profile, no read-only row in Edit Profile, no hint it can't be changed. A user who mis-scrolls the wheel is locked in without warning. | Feedback; error prevention; privacy transparency | Picker sheet now titled, warns "can't change it later", shows a live line "You're 21 · others see 18-24" (client mirrors the server's buckets, unit-tested), confirm disabled when under 18. Own profile shows "City · Country · 18-24". Edit Profile has a read-only age-range card explaining why it can't be edited. | Birthday correction support tickets; completion rate of the step |
Verified on device: wheel updates the live line, tile shows date + age badge, own profile shows the range, edit profile shows the card.

### Redesign decisions
| Area | Observed problem (device) | Principle | Change | Metric / task |
|---|---|---|---|---|
| Photo | Mandatory photo blocked a first-time user from ever seeing a plan | Value before commitment; autonomy | Photo is skippable in onboarding. Joining or hosting asks for one ("Add a photo first"), then continues the action. Verified from both the plan card and the detail page. | Onboarding completion; join conversion for users who skipped |
| Pickers | Seven pickers in four styles: Material calendar dialog, analog clock, dropdown menu, wheel sheet | Consistency; recognition over recall | One family in `picker_sheets.dart`: `PickerField` + option sheet (category with coloured icons, duration, searchable country with flags) + date wheel sheet (birthday, plan date and time in 5-min steps with live validation). Old dropdown and dialog code deleted. | Create-plan completion time; field error rate |
| Returning to a plan | After joining, nothing reminded the user they have a plan | Prospective memory | **Tried and reverted:** a pill on top of the map showing the next plan. Feedback: a person can attend several plans, one pill can't represent them, and it covers the map. Upcoming plans stay in Profile (several, soonest first) and Chat (one thread each). A multi-plan entry point elsewhere is still open. | Plan-detail revisits; no-shows (if measurable) |
| After joining | Chat was one of two equal full-width buttons | Next-step clarity | Detail: "You're going" card (when, where, directions) at the top; bottom bar is Open group chat + small Leave/Manage. | Group-chat open rate after join |
| Discovery cards | List/marker cards had no host, no venue; distance came from the map centre but read as "from you" | Information scent; honesty | Marker feed now carries venue, host and approval rule (backend + API doc + test updated); cards show host and venue; distance only appears when measured from the member. | Detail-opens per join |
| Profile | "67% complete" ring and badge scored a brand-new member | Avoid social-comparison pressure | Removed. Plain avatar; empty "Upcoming" offers "Find a plan". | Profile-edit rate (should not drop) |
| Onboarding | City was a full screen with a dropdown for two options; interests had a search box for 12 chips | Cognitive load | Two tap tiles; search removed. | Time per step |
| Standalone photo screen | Showed onboarding progress (83%) mid-join | Context | Progress bar and Skip hidden when opened from a join/host prompt. | n/a |

### Scenarios exercised on device this pass
New member with no plans (map, list, empty states); denied location (map, travelers sheet: honest message, still browsable); failed network (detail screen: "No internet connection" + Try again, recovered once the backend returned); comparing plans via the list; join (map stays clear); host create flow with all new pickers; returning to the plan from Profile; chat and back to map; edit profile; second user (Noah) end to end through skip-photo and the join gate.

### Honest limits
- Google sign-in, the Discover filter screen and delete account were still not driven on device (Google sign-in needs the user's own Google account and a real project).
- Only one plan existed, so "comparing two activities" is only checked structurally (list cards carry enough to compare); a densely populated feed is untested.
- The photo gate and pickers are hypotheses until measured; no analytics exist yet.
- Distance is hidden when location is off, so the list shows no distance for most new members.
