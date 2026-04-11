# divingbell

iPhone app that tracks time spent in a user-chosen set of SNS apps as
discrete "dive sessions" and visualises the remaining daily oxygen budget
as a teal-gradient battery-shaped gauge in the Dynamic Island, Lock Screen
Live Activity, and home-screen widget. When oxygen runs out, a
`ManagedSettings` shield blocks the monitored apps until local midnight.

Codename metaphor: a **diving bell** is a sealed chamber with a finite
oxygen supply. One dive = one foreground session in a monitored app.
Running out of oxygen forces you to surface.

---

## Ground rules for every Claude Code session

**Load-bearing rule — follow on every iteration:**
- `.claude/rules/docs-sync.md` — the pre-iteration / during / post-iteration
  protocol that keeps code and `docs/` in sync. Not optional. Read it at
  the start of every session before touching any non-read tool.

**Read before writing code (always):**
- `docs/00-intentions.md` — what the user asked for, in their words
- `docs/01-plan.md` — current implementation plan + milestones
- `docs/02-progress.md` — what's done / in-flight / blocked right now
- `docs/03-confirmations.md` — user-ratified decisions `D1..Dn`
- `docs/04-assumptions.md` — assumptions currently operating under `A1..An`

**Read when touching iOS APIs:**
- `docs/05-feasibility-notes.md` — what the platform does and does not allow

**Write as work happens (see `.claude/rules/docs-sync.md` for the full
tripwire list):**
- Update `02-progress.md` as tasks land or blockers appear.
- Promote any new assumption to `04-assumptions.md` the moment you notice
  yourself making it.
- Never silently break a `03-confirmations.md` entry. If a confirmed
  decision needs to change, stop, ask, and only then update `03`.

---

## Load-bearing technical pillars

- **SwiftUI native, no React Native.** Screen Time APIs are Swift-only; RN
  would mean writing the hard parts in Swift anyway.
- **Plain `@Observable` reducer** for state. No TCA / Redux on day 1.
  Revisit only if tests feel awkward.
- **All Screen Time access goes through `ScreenTimeService`** protocol,
  with a `FakeScreenTimeService` for tests. `RealScreenTimeService` does
  not exist until M3.
- **All time access goes through an injected `Clock`**. `SystemClock` for
  prod; `FakeClock` for tests. Never call `Date()` directly in domain code.
- **Dead reckoning** — the visible gauge is our local model's extrapolation
  between authoritative `DeviceActivityMonitor` threshold callbacks.
  Threshold callbacks are corrections; interpolation is our responsibility.
- **App Group shared container** is the only state-exchange mechanism
  between the main app and its extensions. Non-negotiable.
- **Shield arms early.** A threshold rung at ~95 % of daily budget pre-arms
  the `ManagedSettings` shield so it's in place *before* the user's next
  app launch. See `docs/05-feasibility-notes.md` § "Shield arming race".

## Design pillars

- The gauge is drawn as the **native iOS battery silhouette** — horizontal
  pill with a small right-side nub. Differentiated only by a teal gradient
  fill. One SwiftUI view (`OxygenTankGauge`) reused at every scale:
  minimal, compact, expanded, lock screen, widget, dashboard.
- **Calm, not alarmist.** Low-O₂ communicates via opacity pulse, never via
  hue shift. No red, no yellow, no traffic-light semantics.
- **Compact Dynamic Island answers exactly two questions** — *"how much
  air?"* and *"how long down?"*. Anything richer must be pushed to
  expanded. See `01-plan.md` Appendix A.
- **No interactive Live Activity buttons in v1.** The entire surface is a
  `.widgetURL` deep-link and nothing more.

## Testing is the self-correction signal

- `scripts/test.sh` is the canonical test driver. It must exit 0 on every
  commit. No exceptions, no skip flags.
- Every design-system component has ≥3 Xcode `#Preview`s (default, edge
  case, dark mode) and ≥2 `swift-snapshot-testing` snapshots (light, dark).
- Reducer tests are pure Swift — no simulator, no flakes. Exhaustive
  coverage of: normal dive, budget exhausted mid-dive, schedule rollover,
  background relaunch, timezone change.
- XCUITest E2E runs on the iOS Simulator via `xcodebuild test`. The
  `.xcresult` bundle is the machine-readable signal I parse for
  self-correction.

## Tone

- No emoji in code, commits, or docs unless the user explicitly asks.
- Short PR titles (<70 chars). "Why" in the body, not the title.
- Don't add features, refactors, or "improvements" beyond what was asked.
- Don't stub error handling for impossible cases. Trust framework
  guarantees; validate only at system boundaries.
