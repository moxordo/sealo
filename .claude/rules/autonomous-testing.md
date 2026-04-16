# Rule — maximise autonomous testing, minimise device round-trips

**Status:** load-bearing. Pairs with `docs-sync.md` as the two
always-on governance rules for this repo.

The goal: every code change I hand back to the user should have been
verified by *me* against the simulator-testable surface before the
user sees it. The user's device time is reserved for the ~20 % of
changes that genuinely touch iOS behavior no simulator can fake.

---

## The fakable / unfakable taxonomy

Every iOS capability we use falls into one of two buckets. This
distinction governs whether I can validate a change myself or must
hand off to the user.

### Fakable in the simulator (I verify autonomously)

| Capability | How I verify |
|---|---|
| Domain types, reducer logic, budget arithmetic | Unit tests via `scripts/test.sh` |
| `FakeScreenTimeService` behaviour and test double correctness | Unit tests |
| `ThresholdLadder` rung generation | Unit tests |
| SwiftUI view rendering at any size / color scheme | Snapshot tests via `ImageRenderer` (no SPM deps) |
| `OxygenTankGauge`, `DiveDotsView`, dashboard, onboarding flows | Snapshot + XCUITest |
| App launch, scene-phase handling, widget timeline provider | Unit tests + XCUITest |
| `Activity.request` / `.update` / `.end` call correctness | Unit tests against a mocked ActivityKit surface |
| Live Activity SwiftUI layouts (minimal / compact / expanded / Lock) | Snapshot tests via `ImageRenderer` |
| `AppStore` reducer's response to every `AppEvent` | Unit tests |
| Day-rollover detection, shield-arming math, dead reckoning | Unit tests |
| App Group `SharedDefaults` read/write round-trips | Unit tests |

### Unfakable without a real iPhone (user must verify)

| Capability | Why it needs real iOS |
|---|---|
| `FamilyActivityPicker` authorization and real token selection | Simulator can't grant Family Controls |
| Real `DeviceActivityMonitor` threshold callbacks | Requires actual foreground usage in a monitored app |
| Real `ManagedSettings` shield blocking an app | Requires the iOS Springboard to enforce |
| Live Activity appearance on the physical Dynamic Island | Simulator renders but visual fidelity differs |
| Widget placement on real home screen | User chooses; simulator's widget gallery is close but not identical |
| Device-signing, provisioning, App Store assets | Device / Xcode / portal only |
| Subjective tone + visual judgement ("does this feel right?") | Human call, by definition |

When a change touches only fakable capabilities, I run the full
suite and report results. When it touches an unfakable capability,
I still run the full suite to verify fakable parts, and the report
ends with a one-line note: *"device test required for [specific
behavior]."*

---

## What I must run before reporting "done"

`./scripts/test.sh --full` is the canonical pre-handoff gate. It
runs:

1. **Unit tests** (reducer, services, ladder, budget) — must exit 0
2. **Snapshot tests** (SwiftUI views at committed baselines) — must
   exit 0 with no new-baseline writes
3. **XCUITest** (tap-through of main flows in simulator) — must exit 0

If any layer is red, I fix it before reporting back. If I recorded
a new snapshot baseline, I commit the PNG and mention the new
baseline in the handoff so the user knows there's visual state to
review.

## When to ask the user to test on device

A device round-trip is justified if and only if the change:

- Modifies `RealScreenTimeService` or anything in `sealoMonitor/`
- Changes the Family Controls authorization flow
- Changes the App Group entitlements or App ID registration
- Alters `ManagedSettings` shield behaviour
- Changes Live Activity starts that rely on `NSSupportsLiveActivities`
  in the real signing profile
- Touches the real-device signing / provisioning chain

A device round-trip is **not** justified for:

- Pure SwiftUI layout changes
- Reducer logic changes
- Domain type changes
- Debug-UI / simulate-controls changes
- Documentation changes

If the change is a mix, I isolate the device-only part mentally
and give the user a minimal device checklist instead of "please
re-run the whole M3 flow."

---

## Pre-handoff checklist (every code-change iteration)

1. Ran `./scripts/test.sh --full` — green
2. No un-committed snapshot baselines (if I recorded any, I
   committed them and named them in the handoff)
3. Reviewed the `docs-sync.md` tripwires for this change
4. Stated in the handoff which layers are verified (unit / snapshot
   / UITest) and which aren't, if any
5. If device-only behavior was touched, produced a tight device
   test plan — not "try the whole app"

Skipping this checklist is the same failure mode as skipping
`docs-sync.md`: silent, slow, and erodes trust across iterations.

---

## What I explicitly will NOT do autonomously

- Make subjective tone / UX / copy decisions — surface them and
  propose alternatives for the user to pick
- Declare a feature "shipped" without a real-device verification
  for the unfakable portions
- Record snapshot baselines on the user's behalf without mentioning
  the diff in the handoff (baselines are product state, not
  invisible byproducts)
- Ship UI changes without at least one snapshot test as regression
  protection

---

## Escalation

If I run the full suite and it passes, I report "verified". If
it fails, I either fix and re-run or surface the specific failure
to the user and wait. I never report "should work" or "probably
fine" — those phrases are explicitly banned by this rule.
