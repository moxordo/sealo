# 00 — Intentions

The user's original ask, captured as literally as possible so future
sessions can re-ground against the source of truth when the plan drifts.

---

## The original message

> I want to create an iPhone app that would track the time I've moved into
> an active session in certain SNS apps and keep a "health gauge" as a
> dynamic window. I want that gauge to look like an oxygen tank that
> visualises how much time I'm spending in that app.
>
> Effectively, I would get a number of "dive" sessions per day, and I can
> pre-schedule how much of dive time and dive sessions I can do per day.

## Core features (as originally stated)

1. **Session tracking** — detect when the user has "moved into an active
   session" in a set of SNS apps and measure how long they stay.
2. **Oxygen-tank gauge** — a visual "health gauge" styled after an oxygen
   tank that drains as a dive progresses.
3. **Dynamic window presence** — the gauge is visible *outside* the app
   itself, not only on the dashboard. (Interpreted in `03` as Dynamic
   Island + Lock Screen Live Activity + home widget.)
4. **Daily dive budget** — a configurable number of discrete dives allowed
   per day.
5. **Daily dive-time budget** — a configurable total number of minutes
   allowed per day.
6. **Pre-scheduling** — the user sets both limits in advance; they do not
   adjust on the fly mid-dive.

## Questions the user asked up front

- "How much of my needs can actually be reliably served within the app?"
  → answered in `05-feasibility-notes.md`. Short version: most of it,
  modulo the Family Controls entitlement and the event-driven nature of
  Screen Time. See `05` for the honest caveats.
- "Is there a way to test locally with my iPhone before shipping to
  AppStore?" → yes, free-tier Xcode signing works for everything except
  Family Controls; paid Developer Program ($99/yr) unlocks Family
  Controls + TestFlight. Decision recorded as `D1`.
- "I want a systematic way by which we can build upon our UI modules
  (like Storybook if possible)" → three-layer approach: Xcode `#Preview`s
  (inner loop), a Gallery tab (Storybook equivalent), and
  `swift-snapshot-testing` for pixel-diff regression.
- "React Native or SwiftUI (iOS native)?" → SwiftUI native. Reasoning in
  `03`, driven by the fact that Screen Time + ActivityKit have no RN
  bridge and each extension target rules out shipping a JS runtime.
- "For a sanitary development and testing workflow, I want us to be test
  driven with full E2E QA suites that you as a builder agent can harness
  for self-guided corrections whenever you are off the line from the
  requested spec." → `scripts/test.sh` as the canonical headless driver,
  `.xcresult` bundles parsed for pass/fail + snapshot diffs as the agent's
  self-correction signal.

## Workflow preferences the user emphasised

> In the early phases, I want you to write these down as rule files
> before actually moving on to the implementation steps.
>
> - My intentions
> - Your Plan
> - What has been completed or done.
> - My confirmations
> - What assumptions you have now.

This is why `docs/00` through `docs/04` exist and why they are written
*before* any code. `CLAUDE.md` points at them so every future session
reads them automatically.

> Let's work on it piece by piece.

Pacing signal: I should land one coherent chunk at a time and check in
rather than implementing whole milestones in a single push.

---

## Non-intentions

Things the user did *not* ask for, captured so I don't scope-creep into
them without explicit permission:

- No Android support.
- No user accounts, no cloud sync, no analytics SDK.
- No social features (sharing dive reports, leaderboards, etc.).
- No gamification (streaks, XP, achievements) beyond the raw dive count.
- No "request more oxygen" escape hatch in v1 — per `D3` the shield is
  hard.
- No App Intents extension in v1 — the Live Activity is a deep-link
  surface, not a control surface.
