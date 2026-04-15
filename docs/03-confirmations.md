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

## D5 — Visual system (amended 2026-04-15)

**Decision:** Two complementary visual layers, each optimised for a
different job:

1. **Battery silhouette gauge** for glanceable surfaces — Dynamic
   Island minimal/compact/expanded, Lock Screen Live Activity, home
   widgets. Native iOS battery shape (horizontal pill + right-side
   nub) with a vibrant-but-controlled teal gradient fill. Chosen
   because users recognise the shape in under 100 ms without reading
   any label.

2. **Sealo character** for in-app and emotional surfaces — dashboard
   hero, onboarding, shield screen, notifications. A playful diving
   seal who embodies the oxygen-budget metaphor and adds a companion
   layer the battery alone can't carry.

The two never compete for the same slot. The gauge lives where
sub-100 ms read matters. Sealo lives where emotional engagement and
brand identity matter.

**Ratified:** 2026-04-11 (original battery-silhouette decision)
**Amended:** 2026-04-15 (added Sealo character layer alongside)

**Rationale:** The battery silhouette alone won on glanceability but
gave up the behavior-change potency of a mascot-driven brand (Duolingo,
Headspace, Finch all demonstrate the latter). Replacing the silhouette
with a seal-shaped gauge would sacrifice glanceability at small sizes
(rendering a seal at 24 pt tall is genuinely hard). Keeping both —
silhouette for the "how much air?" read, Sealo for the "who am I
diving with?" read — captures both benefits without compromising
either.

**Impact if reversed:**
- Dropping Sealo → loses the emotional/brand layer; app reverts to
  functional dashboard with no character.
- Dropping battery silhouette → loses sub-100 ms Dynamic Island
  recognition; all small-surface read times degrade.

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

---

## D7 — Sealo tone guardrail

**Decision:** Sealo never expresses negative emotions toward the user.
Sealo may get tired (low oxygen), but not angry or disappointed.
Sealo celebrates when the user resurfaces; Sealo never shames the
user for hitting a limit. Emotional states react to the *situation*
(running out of breath, reaching the surface, starting a fresh day),
never to user *failure*.

**Ratified:** 2026-04-15

**Rationale:** Mascot apps have a well-known failure mode where the
character becomes a guilt vector — Duolingo's owl is the canonical
example. The fix is to decouple the character's emotional expression
from user compliance: Sealo looks tired because the tank is low, not
because "you scrolled too much today." Preserves the "calm, not
alarmist" design pillar from `CLAUDE.md` while still allowing a
mascot's emotional range.

**Impact if reversed:** Opens the door to Duolingo-style nagging
notifications. Reduces trust. Likely long-term uninstall driver for
an app whose premise is already adversarial to user habits.

---

## D8 — Rebrand: divingbell → Sealo

**Decision:** App, project, bundle identifiers, and GitHub repo all
rename from `divingbell` to `sealo`. Display name is **Sealo**
(capitalised). Bundle ID is `com.moxordo.sealo` (+ `.monitor`,
`.tests`, `.uitests`). App Group is `group.com.moxordo.sealo`.
Character name: Sealo. App name: Sealo. Both are the same.

**Ratified:** 2026-04-15
**Amended:** 2026-04-15 — prefix changed from `io.moxordo.*` to
`com.moxordo.*` before any App IDs were registered with Apple, so
zero portal rework was needed. Both prefixes are functionally
identical; `com.` is the more traditional convention.

**Rationale:** "divingbell" was a codename chosen for the metaphor
(sealed chamber with finite oxygen). It was descriptive but awkward
to say, long to type, and hard to search for in an App Store.
"Sealo" is 2 syllables, follows the successful character-name pattern
(Duo, Nomo, Mobi), and IS the mascot — app and character share a
name, which doubles the brand surface for free. No major "seal app"
owns that mascot space today.

**Impact if reversed:** The rename is mechanical (one migration
commit); reversing it is equally mechanical. Much more painful if we
defer the rename past the point where App Store metadata, press
coverage, or user habits have accumulated — but at M3 with no real
users yet, the window is still open.
