# 02 — Progress

Running log of what has landed, what is in flight, and what is blocked.
Updated as work happens. The current milestone's checklist lives here;
completed milestones collapse to a one-line summary.

---

## Current milestone: **M0 — Rule files + test harness**

**Status:** rule files complete; awaiting user review before Xcode scaffold
**Started:** 2026-04-11
**Gate:** `scripts/test.sh` exits 0 on a fresh clone with zero warnings.

### M0 checklist

- [x] `CLAUDE.md` — project-level guidance + ground rules
- [x] `docs/00-intentions.md` — user's original ask captured verbatim
- [x] `docs/01-plan.md` — trimmed, execution-relevant plan + Appendix A
- [x] `docs/02-progress.md` — this file
- [x] `docs/03-confirmations.md` — D1..D6 ratified decisions
- [x] `docs/04-assumptions.md` — A1..A10 current assumptions
- [x] `docs/05-feasibility-notes.md` — iOS capability tables
- [ ] Xcode project + workspace scaffolded (iOS 17.0 floor)
- [ ] SPM deps wired: `swift-snapshot-testing` (test target),
      `GRDB.swift` (app target)
- [ ] `scripts/test.sh` headless driver written
- [ ] Placeholder `OxygenTankGauge` view (battery silhouette, solid teal
      fill — no gradient or pulse yet)
- [ ] One snapshot-test canary asserting 50 %-fill render matches baseline
- [ ] `scripts/test.sh` exits 0 on a fresh clone — M0 gate verified

### In flight
- Rule files landed. Pausing for user review per the "piece by piece"
  pacing signal before moving to Xcode scaffolding.

### Blocked
- Nothing currently.

### Notes and decisions captured during M0
- Gauge shape agreed as the native iOS battery silhouette (horizontal
  pill + right-side nub), not a vertical scuba cylinder. Recorded as
  visual direction in `01-plan.md` Appendix A. (2026-04-11)
- Fill color confirmed as a controlled teal gradient — tokens drafted
  in Appendix A, to be finalised during M1 design-system work.
- Monitoring-set app icons agreed to appear only inside the schedule
  editor, not on the dashboard or Dynamic Island. Keeps the shared-tank
  model (per `D2`) visually pure.
- `.claude/rules/docs-sync.md` added as the load-bearing rule file that
  enforces docs ↔ code sync on every iteration. Referenced from
  `CLAUDE.md`'s Ground Rules section so every session auto-loads the
  pointer. Enforcement is currently by convention; a `UserPromptSubmit`
  hook is the documented escalation path if slippage is observed.
  (2026-04-11)

---

## Completed milestones

_None yet._

---

## Backlog / out-of-milestone notes

- Apply for Apple Developer Program enrollment in parallel with M0–M2 so
  the Family Controls entitlement review (`D1`) is in flight by the time
  M3 starts.
- Draft a manual real-device test-plan document as M3 approaches. Should
  cover: picker flow, threshold callback visible in Console.app, shield
  applies, shield dismisses at midnight rollover.
- Consider publishing a short "how divingbell measures time" explainer
  once dead reckoning is live, so users understand why the gauge snaps
  on updates.
