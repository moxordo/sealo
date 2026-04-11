# 03 — Confirmations

User-ratified decisions. **Do not silently change any entry on this
page.** If a decision needs to flip, stop, ask the user, and only then
update this file with a new entry (never in place — append the new
decision with a fresh ID and strike through the old one).

Format: `Dn | Decision | Ratified on | Rationale`.

---

## D1 — Apple Developer Program status

**Decision:** Not yet enrolled — user will enroll in parallel with M0–M2.
M0–M2 run entirely against `FakeScreenTimeService`. M3 flips to the real
backend once the Family Controls entitlement is approved.

**Ratified:** 2026-04-11

**Rationale:** Family Controls is the single hard dependency on Apple
review. Decoupling M0–M2 from that review via a fake service keeps the
build, test, and design-system work moving in parallel with the paperwork
rather than waiting on it.

**Impact if reversed:** We could start M3 Screen Time integration
immediately once enrollment lands, at the cost of re-sequencing M0–M2 to
fit around the waiting period.

---

## D2 — Budget scope

**Decision:** One shared oxygen tank across the whole monitored SNS app
set. Not per-app.

**Ratified:** 2026-04-11

**Rationale:** Simplest state model, matches the diving-bell metaphor
(one diver, one tank), fewest `DeviceActivityEvent` registrations, and
sidesteps the per-app complexity the Screen Time API's opaque tokens
would otherwise force on us.

**Impact if reversed:** Domain model roughly doubles: every budget,
every dive, and every threshold ladder would need a per-token variant,
and the UI would have to surface which app owns which tank.

---

## D3 — Enforcement strictness

**Decision:** Hard shield via `ManagedSettings` when oxygen runs out. No
"request more oxygen" escape hatch in v1. No extra-time mechanic. No
App Intents.

**Ratified:** 2026-04-11

**Rationale:** The whole point of the app is to enforce the user's
pre-scheduled limits against future-self's weaker will. Soft nudges are
easy to ignore. The hard shield is the strongest third-party enforcement
iOS allows.

**Impact if reversed:** M5 grows a `ShieldActionExtension` path that
round-trips an "extra-time granted" signal through the App Group and
re-registers new thresholds. Also grows an App Intents target for the
grant action. Roughly a week of additional work.

---

## D4 — Minimum iOS version

**Decision:** iOS 17.0.

**Ratified:** 2026-04-11

**Rationale:** Widest reasonable device reach for a 2026 launch while
still getting the full Screen Time + ActivityKit surface. iOS 18's
Swift Testing niceties are nice-to-have, not load-bearing; we can adopt
them behind `#available` where they meaningfully help.

**Impact if reversed:**
- Raising to iOS 18 lets us drop XCTest fallbacks and adopt newer
  Live Activity features unconditionally, at the cost of older devices.
- Dropping to iOS 16 forces us around several ActivityKit refinements
  that landed in 17. Recommended against.

---

## D5 — Gauge visual metaphor

**Decision:** Native iOS battery silhouette (horizontal pill with a
right-side nub), differentiated from the system battery only by color —
specifically a vibrant-but-controlled teal gradient fill.

**Ratified:** 2026-04-11

**Rationale:** Users recognise the native battery shape in under 100 ms
without reading any label — a decade of iOS training. Reusing the shape
inherits that recognition for free; changing the color owns the metaphor.
A round pressure-gauge dial or a diving-bell silhouette would sacrifice
recognition speed for literalism, which is a bad trade at Dynamic Island
sizes.

**Impact if reversed:** `OxygenTankGauge` becomes a custom shape with no
glyph-recognition head start; Appendix A mockups need re-drawing.

---

## D6 — Monitoring-set app icons

**Decision:** App icons from the user-chosen monitoring set appear only
inside the schedule editor (where the `FamilyActivityPicker` renders
them natively). The dashboard, Dynamic Island, Lock Screen, and widget
show the tank metaphor alone — no per-app chips anywhere else.

**Ratified:** 2026-04-11

**Rationale:** Per-app chips outside the editor would visually imply
per-app budgets and fight against `D2`'s shared-tank model. Keeping the
metaphor pure reduces both confusion and implementation work.

**Impact if reversed:** Dashboard grows an icon row bound to the current
`FamilyActivitySelection`; Dynamic Island expanded grows chip slots;
re-render costs accumulate across surfaces.
