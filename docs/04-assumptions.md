# 04 — Assumptions

Beliefs currently operating on that have not been explicitly ratified by
the user. Each one is a place where I will stop and ask rather than
silently break if the assumption turns out to be wrong. Promote new
assumptions to this file the moment you notice yourself making them.

Format: `An | Assumption | Stated on | Why I'm assuming it | What I'd do
if it flips`.

---

## A1 — Local dev environment

**Assumption:** The user is on macOS with Xcode installed (or willing to
install it) and has an iPhone running iOS 17.0 or later available for
on-device testing.

**Stated:** 2026-04-11
**Why:** The user asked for "a way to test locally with my iPhone before
shipping to AppStore", which presupposes they *have* an iPhone and a
Mac capable of running Xcode. Not verified explicitly yet.
**If it flips:** Fall back to simulator-only M0–M2; defer on-device
testing until hardware is available. M3 onward requires a real device.

---

## A2 — Monitoring set is user-chosen at onboarding

**Assumption:** The "certain SNS apps" are a user-chosen set picked via
`FamilyActivityPicker` during first-run onboarding, not a hardcoded list
of bundle IDs.

**Stated:** 2026-04-11
**Why:** The Screen Time API does not expose bundle IDs to third-party
apps — only opaque `ApplicationToken`s returned by the picker. We
literally cannot hardcode a monitoring set even if we wanted to.
**If it flips:** Impossible. This is a platform constraint, not a
product choice. Any future-self who thinks this can flip has not read
`05-feasibility-notes.md`.

---

## A3 — "Dynamic window" = Live Activity + Dynamic Island + Widget

**Assumption:** When the user said "dynamic window", they meant the
Dynamic Island + Lock Screen Live Activity + home widget combination,
not a literal free-floating overlay pinned on top of other apps.

**Stated:** 2026-04-11
**Why:** iOS does not allow any third-party app to render a
free-floating window on top of other apps. The closest thing the platform
offers is Live Activity / Dynamic Island. The user accepted this
interpretation in conversation.
**If it flips:** Nothing to do — the platform does not support any
alternative.

---

## A4 — Daily budgets roll at local midnight

**Assumption:** The daily budget resets at 00:00 in the user's local
timezone, not UTC and not a user-configurable wake time.

**Stated:** 2026-04-11
**Why:** Default intuition. Users think in local-day terms.
**If it flips:** Change is localised to `Schedule` and `DailyBudget`
reducer logic; `Clock` already returns a local `Date`, so the mechanical
change is small. UI would need a new setting.

---

## A5 — Both limits cause the shield

**Assumption:** "Pre-schedule dive time and dive sessions per day" means
the user sets both (a) maximum total minutes per day and (b) maximum
discrete sessions per day, and the shield engages when *either* limit is
hit.

**Stated:** 2026-04-11
**Why:** Literal reading of the user's wording ("a number of 'dive'
sessions per day, and I can pre-schedule how much of dive time and dive
sessions I can do per day"). Both limits are first-class.
**If it flips:** If only one limit matters, the `DailyBudget` type and
reducer collapse; UI drops one input. Minor rework.

---

## A6 — v1 is single-user, on-device only

**Assumption:** No account system, no server, no cloud sync, no analytics
SDK, no crash reporting service in v1. Everything lives on the device.

**Stated:** 2026-04-11
**Why:** The user did not ask for any of these. Adding them would be
scope creep. Also sidesteps a privacy review burden.
**If it flips:** A sync/account layer is a whole new tier in the
architecture diagram. Do not add speculatively.

---

## A7 — State library: plain `@Observable`, no TCA on day 1

**Assumption:** State management uses plain SwiftUI `@Observable` with a
reducer convention in `AppStore.swift`. No The Composable Architecture,
no Redux-style library on day 1.

**Stated:** 2026-04-11
**Why:** Adding a state library is a decision better made after feeling
real pain than before. `@Observable` + pure reducer functions are enough
for testable state on iOS 17+. Keeps dependency surface minimal for the
builder agent loop.
**If it flips:** The reducer convention was designed to be TCA-shaped,
so migrating later is mostly moving code into `Feature` boundaries. Not
cheap, but not a rewrite.

---

## A8 — Persistence: SQLite via GRDB in the App Group container

**Assumption:** Persistent state (dive history, schedules, budget
accounting) lives in a SQLite database stored inside the App Group
container, accessed via the GRDB.swift library. Extensions read the
same database.

**Stated:** 2026-04-11
**Why:** App Group sharing is non-negotiable for Screen Time apps;
extensions must read main-app state. GRDB has a clean synchronous API
that works from extensions and integrates with Swift's concurrency
model. Core Data is heavier and more awkward to share across extensions.
**If it flips:** Swapping GRDB for raw `SQLite3` or SwiftData would be
mechanical but boring work at the DAO layer. App Group itself is not
negotiable.

---

## A9 — Gallery is a debug-only tab

**Assumption:** The Storybook-equivalent Gallery view is a debug-only
tab inside the main app binary (gated behind `#if DEBUG`), not a
separate distribution target or a separate app.

**Stated:** 2026-04-11
**Why:** Single binary is simpler to ship, simpler to install on the
user's phone, and the gallery never ships to end users anyway. Splitting
it into its own target would be premature.
**If it flips:** Extract `sealoGallery` as a second app target
reading the same design-system module. Mechanical refactor.

---

## A10 — Bundle identifier (promoted to D8 on 2026-04-15)

**Assumption:** The app's bundle identifier will be
`com.moxordo.sealo`, matching the existing `/Users/andy/moxordo/`
workspace convention on the user's machine.

**Stated:** 2026-04-11
**Promoted:** 2026-04-15 → `D8` in `03-confirmations.md`.
**Why:** The rebrand from divingbell to Sealo made the bundle ID a
first-class ratified decision rather than a convenience assumption.
See `D8` for the full rationale.
