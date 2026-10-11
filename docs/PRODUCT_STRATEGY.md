# Product strategy

**Promise:** Find your people. Make a plan. Go together. Social meetups, not dating.

## Principles
1. Success is people meeting in real life, not time in app.
2. Every number shown is real (attendee counts, spots left). No fake scarcity, social proof, countdowns, or guilt reminders.
3. Reduce the steps between "I'd like to" and "I'm going".
4. Users stay in control: filters, notification preferences, easy leave/withdraw.
5. Collect the minimum personal data and location needed.
6. Keep navigation to Map / Chat / Profile unless a user need proves otherwise.

## Needs addressed in this pass
- *Comfort before attending:* "What to expect" states group size, approval rule, cost, chat access.
- *Continuity after joining:* group chat is the primary action once joined.
- *Autonomy:* clear approval/withdraw wording, filter reset when filters hide everything.
- *Getting there:* directions and share from the plan.

## Behavioural hypotheses (all unvalidated)
| Hypothesis | How to test |
|---|---|
| Stating what to expect raises detail-to-join conversion for first-timers | A/B on the card; compare join rate for users with 0 prior joins |
| Surfacing group chat right after join raises attendance | Compare chat-open rate and (if measurable) check-in |
| Sharing a plan brings in friends who then join | Track share taps vs new sign-ups with a plan link (needs deep links, not built) |
| Event-based reminders (host reply, plan changed, starts soon) improve attendance without raising opt-outs | Needs FCM first; track opt-out rate |

## Metrics to instrument (none exist yet; Firebase Analytics is a dependency but events are not defined)
Onboarding completion; time to first plan opened; detail→join conversion; join success rate; 30-day repeat participation; organizer repeat rate; cancellation rate; reports per 1k plans and resolution time; notification opt-out; crash-free sessions. Establish baselines before claiming any improvement.

## Launch and growth constraints
- Supply is the risk. Seed real hosted plans in Mumbai and Pune; recruit recurring hosts.
- Moderation cost scales with the global community chat; keep reporting visible and rate limits server-side.
- Defer: recommendations, ratings, gamification, and any paid service until usage data justifies them.

## New hypotheses from the behavioural pass (all unvalidated)
| Hypothesis | Test |
|---|---|
| Letting people browse before adding a photo raises onboarding completion without lowering join rate (the gate still asks at join) | Compare completion and photo-added-at-join rates; watch declines at the gate |
| Members with several plans need one entry point for all of them (a single next-plan pill was rejected as unrepresentative); this is still unsolved | Usability task: "find where you're meeting tomorrow" from the map |
| Telling people their age range, and that the birthday is fixed, reduces mistaken birthdays | Support contacts about birthday corrections |
| Removing the completion score does not reduce profile completion | Edit-profile rate for new members |
