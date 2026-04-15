# 01 — Plan

Execution-relevant slice of the approved plan. The full reasoning lives at
`/Users/andy/.claude/plans/modular-floating-cupcake.md`; this file is the
trimmed version committed into the repo so anyone cloning it has enough to
navigate without reading the full rationale.

---

## Architecture

```
┌────────────────────────── App (SwiftUI) ──────────────────────────┐
│  Scenes:   Dashboard, Schedule editor, Dive history, Gallery(dbg) │
│                                                                    │
│  Domain:   DiveSession, DailyBudget, Schedule, OxygenState         │
│  Services (protocols, fake + real impls):                          │
│     • ScreenTimeService   → FamilyControls + DeviceActivity        │
│     • ShieldService       → ManagedSettingsStore                   │
│     • LiveActivityService → ActivityKit                            │
│     • Clock               → Date/Timer for testability             │
│                                                                    │
│  State:    Observable reducer store (plain @Observable, no deps)   │
└────────────────────────────────────────────────────────────────────┘
            │                       │                      │
            ▼                       ▼                      ▼
  ┌──────────────────┐   ┌──────────────────────┐  ┌───────────────────┐
  │ DeviceActivity   │   │ Shield Configuration │  │ Widget + Live     │
  │ Monitor extension│   │ extension (custom    │  │ Activity extension│
  │ (threshold cbs)  │   │ "out of oxygen" UI)  │  │ (Dynamic Island)  │
  └──────────────────┘   └──────────────────────┘  └───────────────────┘
            │
            ▼
      App Group container (shared UserDefaults + SQLite via GRDB)
```

### Key architectural invariants

- **App Group** shared container is the only state exchange between main
  app and extensions. Non-negotiable.
- **`Clock`** protocol injected into every domain call that reads "now".
- **`ScreenTimeService`** protocol with `FakeScreenTimeService` + (later)
  `RealScreenTimeService`. Tests and simulator builds run entirely on the
  fake.
- **GRDB** for shared SQLite. Clean synchronous API works from extensions.
- **Plain `@Observable` reducer** — no TCA on day 1.

---

## Milestones

### M0 — Rule files + test harness (no product code yet)
- [ ] `CLAUDE.md` + `docs/00`–`docs/05` populated and reviewed.
- [ ] Xcode workspace: `sealo` app target, `sealoTests`,
      `sealoUITests`.
- [ ] SPM deps: `swift-snapshot-testing`, `GRDB.swift`.
- [ ] `scripts/test.sh` runs `xcodebuild test` headless, writes an
      `.xcresult` bundle.
- [ ] Placeholder `OxygenTankGauge` view + one snapshot test as the
      green-on-fresh-clone canary.
- **Gate:** `scripts/test.sh` exits 0 on a fresh clone, zero warnings.

### M1 — Design system + gallery
- [ ] Tokens: color, spacing, typography, motion.
- [ ] Components: `OxygenTankGauge`, `DiveCard`, `ScheduleStrip`,
      `BudgetDial`.
- [ ] Each component has ≥3 `#Preview`s and ≥2 snapshot tests
      (light + dark).
- [ ] Gallery tab mounts every component in every state, grouped by
      section. Debug-only (not in release builds).
- **Gate:** snapshot suite green, gallery tab navigable on-device.

### M2 — Domain model + fake ScreenTimeService
- [ ] Types: `DiveSession`, `DailyBudget`, `Schedule`, `OxygenState`.
- [ ] Pure-Swift reducer with exhaustive coverage.
- [ ] `FakeScreenTimeService` driven by test scripts through: normal
      dive, budget exhausted mid-dive, schedule rollover, background
      relaunch after OS kill, timezone change.
- **Gate:** entire app runnable in simulator against the fake;
  reducer suite green; an agent can drive a full "day of usage" from
  a test script.

### M3 — Real Screen Time integration (requires paid Dev Program)
- [ ] Apply for Family Controls entitlement in parallel.
- [ ] `FamilyActivityPicker` onboarding flow.
- [ ] `DeviceActivityMonitor` extension wired to the reducer via the
      App Group.
- [ ] `ManagedSettingsStore` shield applied on budget exhaustion.
- [ ] Manual real-device checklist completed.
- **Gate:** on a real device, a scheduled dive fires a real threshold
  callback, the reducer advances, and the shield engages.

### M4 — Live Activity + Dynamic Island + home widget
- [ ] `ActivityKit` Live Activity started on dive begin / ended on end.
- [ ] Dynamic Island minimal + compact + expanded per Appendix A.
- [ ] Lock Screen Live Activity card per Appendix A.
- [ ] WidgetKit timeline widget.
- **Gate:** Dynamic Island shows the battery within 2 s of dive start
  on a real device.

### M5 — Custom shield UI + onboarding polish
- [ ] `ShieldConfigurationExtension` — SwiftUI "out of oxygen" screen.
- [ ] `ShieldActionExtension` — surface-now / dismiss only. No
      "request more time" per `D3`.
- [ ] Onboarding: explain the metaphor, request Family Controls
      permission, drive the picker, set an initial schedule.

### M6 — TestFlight beta
- [ ] Archive, upload, submit to internal TestFlight.
- [ ] Invite self + ≤5 testers.
- [ ] Dogfood a week; feed findings into `02-progress.md`.

---

## Target file tree (after M5)

```
sealo/
├── CLAUDE.md
├── docs/
│   ├── 00-intentions.md
│   ├── 01-plan.md                       # this file
│   ├── 02-progress.md
│   ├── 03-confirmations.md
│   ├── 04-assumptions.md
│   └── 05-feasibility-notes.md
├── scripts/
│   └── test.sh                          # agent-runnable test driver
├── sealo.xcworkspace
├── sealo/                          # main app target
│   ├── SealoApp.swift
│   ├── Domain/
│   │   ├── DiveSession.swift
│   │   ├── DailyBudget.swift
│   │   ├── Schedule.swift
│   │   └── OxygenState.swift
│   ├── State/
│   │   └── AppStore.swift               # @Observable reducer
│   ├── Services/
│   │   ├── Clock.swift                  # protocol + SystemClock + FakeClock
│   │   ├── ScreenTimeService.swift      # protocol
│   │   ├── RealScreenTimeService.swift  # DeviceActivity wrapper (M3)
│   │   ├── FakeScreenTimeService.swift  # test backend (M0)
│   │   ├── ShieldService.swift
│   │   └── LiveActivityService.swift
│   ├── UI/
│   │   ├── DesignSystem/
│   │   │   ├── Tokens.swift
│   │   │   ├── OxygenTankGauge.swift
│   │   │   ├── DiveCard.swift
│   │   │   ├── ScheduleStrip.swift
│   │   │   └── BudgetDial.swift
│   │   ├── Dashboard/
│   │   ├── ScheduleEditor/
│   │   ├── DiveHistory/
│   │   └── Gallery/                     # debug-only tab
│   └── Extensions/                      # shared helpers
├── sealoMonitor/                   # DeviceActivityMonitor ext (M3)
├── sealoShieldConfig/              # ShieldConfigurationExtension (M5)
├── sealoShieldAction/              # ShieldActionExtension (M5)
├── sealoWidget/                    # WidgetKit + Live Activity (M4)
├── sealoTests/                     # Swift Testing / XCTest
└── sealoUITests/                   # XCUITest
```

---

## Appendix A — Dynamic Island / Live Activity mockups

Agreed before M4. The gauge is drawn as the **native iOS battery
silhouette** — horizontal pill with a small right-side nub — fill
animated in a vibrant-but-controlled teal gradient. One SwiftUI view
(`OxygenTankGauge`) reused at every scale.

### Color tokens (finalised in M1)
- Fill gradient: `#2EE6C8` → `#1BA89A` → `#14736B`, `LinearGradient`
  top-left to bottom-right.
- Silhouette stroke: 1 pt, `.white.opacity(0.9)` dark /
  `.black.opacity(0.8)` light.
- Empty interior: `.white.opacity(0.08)` dark /
  `.black.opacity(0.06)` light.
- Nub: solid, same color as stroke, ~30 % silhouette height, centered.

### Minimal (preempted by another Live Activity)
```
                                           ╭─────────╮
                                           │  ┌──┐   │
                                           │  │▓░│▌  │
                                           │  └──┘   │
                                           ╰─────────╯
```
- `minimal:` closure. Battery silhouette only, no label.
- Fill <15 % → whole glyph pulses every 2 s at reduced opacity. No hue
  change.

### Compact (default during an active dive)
```
 ╭─────────────────────────────────────────────────────╮
 │   ┌──────┐                                           │
 │   │▓▓▓░░░│▌ 67%    ●── sensor ──●        ⏱ 3:42    │
 │   └──────┘                                           │
 ╰─────────────────────────────────────────────────────╯
```
- `compactLeading:` — battery + `67%` label. Reads as one unit.
- `compactTrailing:` — dive timer mm:ss, `.monospacedDigit()` clock.
- Two questions only: *how much air?* and *how long down?*.

### Expanded (long-press / auto-reveal)
```
 ╭────────────────────────────────────────────────────╮
 │                     ●──sensor──●                   │
 │                                                    │
 │   ┌────────────────────────────────────┐           │
 │   │▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░│▌ 67%     │
 │   └────────────────────────────────────┘           │
 │                                                    │
 │   DIVE #4 of 6 · 18 min O₂ left today              │
 │   started 14:21 · now 14:25    ⏱ 3:42              │
 │   ◎ ◎ ◎ ◎ ○ ○                                      │
 │                                                    │
 │   ────────────────────────────────────────         │
 │              ⟶  Tap to open sealo             │
 ╰────────────────────────────────────────────────────╯
```
- `.leading` — full-width battery, fill animates 0 → current over ~400
  ms on bloom.
- `.trailing` — intentionally empty.
- `.center` — session details + dive-count dots (`◎` done, fourth dot
  pulses = current, `○` budgeted).
- `.bottom` — divider + tap-to-open hint.
- `.widgetURL(URL(string: "sealo://dive/current"))` wraps the
  entire activity — any tap deep-links. No `Button(intent:)`, no App
  Intents extension in v1.

### Lock Screen card
Same content as expanded, relaid as a full-width card. No interactive
controls.

### Design invariants
- Battery silhouette is drawn identically at every scale; only
  `.frame()` changes.
- Compact answers exactly two questions. Anything richer is a layering
  violation — push it to expanded.
- Dive-count dots only in expanded and Lock Screen, never compact or
  minimal.
- No interactive Live Activity buttons in v1.
- No color-state change (red / yellow / etc.). Low-O₂ uses opacity
  pulse only. Preserves calm aesthetic.

---

## Verification gates (machine-checkable)

- **M0:** `scripts/test.sh` exits 0 on a fresh clone, zero warnings.
- **M1:** snapshot suite covers every gallery component × (light, dark).
- **M2:** reducer suite drives the fake through normal dive, budget
  exhausted, schedule rollover, background relaunch, timezone change.
  Zero flakiness over 100 consecutive runs (`scripts/test.sh --loop 100`).
- **M3:** manual real-device checklist: picker → monitor starts →
  threshold callback visible in Console.app → shield applies → shield
  dismisses at midnight rollover.
- **M4:** Dynamic Island shows the battery within 2 s of dive start,
  stays live for the duration, ends cleanly on budget exhaustion.
- **M5:** shield SwiftUI view renders on block; action extension
  round-trips a dismiss back to the main app via App Group.
- **M6:** TestFlight build installs and launches on the user's iPhone.
