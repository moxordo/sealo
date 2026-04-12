# 02 — Progress

Running log of what has landed, what is in flight, and what is blocked.
Updated as work happens. The current milestone's checklist lives here;
completed milestones collapse to a one-line summary.

---

## Current milestone: **M1 — Design system + gallery** (or M3 — user's choice)

**Status:** not started
**Gate (M1):** snapshot suite covers every gallery component x (light, dark).
**Gate (M3):** real device, threshold callback, shield engages.

> M1 was skipped earlier to build the domain core first (M2). M1 items
> (tokens, polished gauge, DiveCard, ScheduleStrip, BudgetDial, Gallery
> tab, snapshot tests) are still pending. User may choose M1 or M3 next.

---

## Completed: **M2 — Domain model + fake ScreenTimeService**

**Started:** 2026-04-12 | **Completed:** 2026-04-12
**Gate met:** scripts/test.sh exits 0 (21 tests, 0 failures). App
runnable in simulator with fake dive controls.

> M1 skipped — user chose inside-out development (domain first, UI second).

---

## Completed: **M0 — Rule files + test harness**

**Started:** 2026-04-11 | **Completed:** 2026-04-12
**Gate met:** `scripts/test.sh` exits 0 (4 tests, 0 failures).

### M0 checklist

- [x] `CLAUDE.md` — project-level guidance + ground rules
- [x] `docs/00-intentions.md` — user's original ask captured verbatim
- [x] `docs/01-plan.md` — trimmed, execution-relevant plan + Appendix A
- [x] `docs/02-progress.md` — this file
- [x] `docs/03-confirmations.md` — D1..D6 ratified decisions
- [x] `docs/04-assumptions.md` — A1..A10 current assumptions
- [x] `docs/05-feasibility-notes.md` — iOS capability tables
- [x] Xcode project scaffolded (iOS 17.0 floor)
      — `project.yml` + source skeleton + `xcodegen generate` done.
        Workspace deferred to M1.
- [x] SPM deps — both `swift-snapshot-testing` and `GRDB.swift`
      deferred (see deviations below). No external deps in M0.
- [x] `scripts/test.sh` headless driver written
      — preflight, project regen, `xcodebuild test` against
        auto-picked simulator, loop mode for M2 flakiness gate,
        structured exit codes (1/2/3), `build/latest.xcresult` path.
- [x] Placeholder `OxygenTankGauge` view
      — battery silhouette, solid teal fill (`#1BA89A`), no gradient
        or pulse yet, three `#Preview`s (default 67 %, empty, full).
- [x] Render-test canary for OxygenTankGauge at multiple fill levels
      + out-of-range clamping test. Pixel-diff snapshot tests deferred
      to M1.
- [x] `scripts/test.sh` exits 0 — M0 gate verified (2026-04-12).
      4 tests, 0 failures.

### In flight
- Nothing. M0 is complete.

### Blocked
- Nothing.

### Deviations from `01-plan.md`
- **Workspace deferred.** `01-plan.md` lists `divingbell.xcworkspace` in
  the target file tree. M0 ships only a `divingbell.xcodeproj` because a
  workspace earns its keep only when you have multiple sibling projects
  (e.g., SPM packages as separate projects). With one project it adds
  clutter for zero benefit. Promote to a workspace in M1 if needed.
- **`GRDB.swift` deferred from M0 to M2.** No consumer until
  persistence layer lands. Added just-in-time.
- **`swift-snapshot-testing` deferred from M0 to M1.** Xcode 26.4 /
  Swift 6.3 produces "built for incompatible target" when importing
  the SnapshotTesting module compiled via SPM into an Xcode-managed
  test target. Root cause: likely a module ABI compatibility change
  in Swift 6.3 that affects SPM-built packages consumed by xcodebuild
  test targets. M0 uses plain XCTest render canaries instead. M1 will
  resolve this (either newer swift-snapshot-testing release, or a
  Package.swift-based approach that avoids the xcodebuild SPM bridge).

### Tool environment quirks (worth remembering)
- **`brew install` is broken inside the Claude Code sandbox** because
  brew's portable-ruby bootstrap downloads from `ghcr.io`, which is
  DNS-blocked here (`github.com` over HTTPS works fine). Workaround
  used: download the XcodeGen artifactbundle directly from
  `github.com/yonaskolb/XcodeGen/releases/latest/download/xcodegen.artifactbundle.zip`
  and install the binary to `~/.local/bin/xcodegen`.
- Future tool installs should prefer "download release binary from
  github.com" over "brew install". SPM deps resolving from github.com
  will work; anything that routes through ghcr.io / pypi / other
  registries may need similar workarounds.
- **Xcode 26.4 ships without a bundled iOS simulator runtime.** Fresh
  installs need `xcodebuild -downloadPlatform iOS` as a separate step
  after `xcode-select` and license acceptance. This is new in Xcode
  26; older Xcodes bundled the runtime. Worth documenting in any
  onboarding doc we ever write.

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
