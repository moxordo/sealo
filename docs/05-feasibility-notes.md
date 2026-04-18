# 05 — Feasibility notes

What iOS does and does not allow for an app in this shape. Read this
file before touching any Screen Time, ActivityKit, ManagedSettings, or
WidgetKit code. It captures the platform-level facts that
future-me will otherwise have to re-derive every session.

---

## The Screen Time API family at a glance

| Need | API | What it gives |
|---|---|---|
| User picks which apps to monitor | `FamilyControls.FamilyActivityPicker` | Opaque `ApplicationToken` / `ActivityCategoryToken`. We never learn bundle IDs or app names — only tokens. UI shows Apple-rendered icons. |
| Start a daily monitoring window | `DeviceActivity.DeviceActivityCenter` | Start/stop a repeating `DeviceActivitySchedule`. Runs in a system-managed extension process. |
| Get callbacks at thresholds | `DeviceActivityMonitor` extension | `intervalDidStart`, `eventDidReachThreshold`, `intervalWillEndWarning`, `intervalDidEnd`. Threshold-based — not a live tick. |
| Block / shield apps | `ManagedSettings.ManagedSettingsStore` | Apply a shield to tokens. Shield UI is customisable via extensions. |
| Custom shield screen + actions | `ShieldConfigurationExtension`, `ShieldActionExtension` | SwiftUI-rendered shield screen, primary/secondary action buttons. |
| Dive-start inference | `DeviceActivityEvent` with a 1-sec threshold | Community-standard trick to get a "dive just began" callback. |
| Dynamic Island / Lock Screen live gauge | `ActivityKit` Live Activity | App-owned UI on Lock Screen + Dynamic Island. Time-limited. **Only the foreground main app can call `Activity.request()` — extensions can `.update()` and `.end()` existing activities but cannot start new ones (iOS 17.2+ `pushToStart` requires a server).** |
| Home / Lock Screen glanceable gauge | `WidgetKit` timeline widget | Periodically refreshed. Budget-limited. |

---

## The hard constraints you cannot wish away

### 1. Family Controls has two tiers of access

- **Development capability** — a checkbox in the developer portal
  (Certificates, Identifiers & Profiles → App ID → Capabilities →
  Family Controls). Takes effect immediately. Lets you run the full
  Screen Time API on your own device via Xcode. **This is all M3
  needs.**
- **Distribution entitlement** — a form submission
  (`developer.apple.com/contact/request/family-controls-distribution`)
  that Apple manually reviews. Required for TestFlight and App Store
  distribution. Takes 1–5 business days. **This is an M6 concern.**

**Consequence for the plan:** M0–M2 ran behind `FakeScreenTimeService`.
M3 uses `RealScreenTimeService` on the developer's own device
immediately after enabling the development capability. The distribution
entitlement is deferred to M6 (TestFlight beta).

### 2. We cannot poll foreground time

There is no API that answers "how many seconds has the user been in app
X right now". Instead:

- **Pre-register a ladder** of `DeviceActivityEvent`s with threshold
  `DateComponents`.
- **iOS fires a callback once** when usage crosses each threshold.
- **Each threshold fires exactly once per interval.** Re-registering the
  same value does nothing. You build a ladder:
  `[1m, 2m, 3m, 5m, 10m, 15m, 20m, 30m, 45m, 60m, …]` and each rung
  fires one callback when crossed.

**Practical minimum threshold ≈ 1 minute.** Thresholds below ~15 s are
batched or dropped. Even 30 s is flaky. Assume a 60-second floor.

**Practical maximum events per schedule ≈ 20.** Undocumented but widely
observed. Budget rungs carefully — dense near the budget ceiling (where
accuracy matters for shield arming), sparse earlier.

### 3. Live Activities can only be STARTED by the foreground main app

**Apple restricts `Activity.request()` to apps that have
`NSSupportsLiveActivities` in their main bundle's Info.plist AND
are currently foregrounded.** Extensions can import ActivityKit and
call `.update()` / `.end()` on activities the main app started, but
they cannot create new ones. If you try, `Activity.request()`
silently fails (no thrown error, no log message, no activity).

**Consequence for M4**: the Sealo Live Activity cannot start
exactly when the user opens Instagram (monitor extension fires
there, but it's not the foreground main app). Our pattern:

1. **Main app starts the activity during onboarding** ("Start
   diving" button) with an initial content state. The user's in
   the foreground; `Activity.request()` works.
2. **Monitor extension updates the running activity** on every
   `DeviceActivityMonitor` threshold callback via `.update()`.
3. **Main app restarts the activity on scene-active** if none is
   running (handles the 8h ActivityKit lifetime expiry).
4. **Main app ends the activity on day rollover** via
   `.end(dismissalPolicy: .immediate)`.

This means the Live Activity is *persistent throughout the day*
rather than *per-dive*. Better UX in practice (user sees their
oxygen budget at a glance all day), but semantically different
from the Appendix A mockup framing.

**Alternatives we deferred**: iOS 17.2+ supports `pushToStart` via
APNs, which would let a push notification start an activity when
the app isn't foregrounded. Requires server infrastructure — M6+
territory, not needed for M4.

### 4. No free-floating overlay windows

No third-party iOS app can pin a floating window on top of other apps.
The strongest *informational* presence iOS offers is the Dynamic Island
+ Lock Screen Live Activity + home widget trio. The strongest *active
interruption* is the `ManagedSettings` shield.

### 4. Dive sessions are set-wide, not per-app (see `D2`)

The Screen Time API does not reliably tell us *which* specific app the
user is currently in — only that they are inside the monitored set. We
can register per-token events, but distinguishing "Instagram session"
from "TikTok session" at the callback level is awkward and fragile.
Per `D2`, we do not try.

---

## Event cadence and dead reckoning

The mental model that makes the whole design work:

**OS → us (`DeviceActivityMonitor`):**
- Event-driven, not polled. Pre-register thresholds; iOS calls back.
- ~1 minute floor, ~20 events ceiling per schedule.
- `intervalWillEndWarning` fires once at a configurable lead time
  before interval end — useful for a "budget resets in 5 min" nudge.

**Us → visible gauge:**
- **Foreground app:** SwiftUI re-renders freely at 60/120 Hz. No budget.
- **Live Activity:** ~1 update every 30–60 s is safe; bursts get
  throttled. Each Activity has ~4 h of update budget, ~8 h display
  lifetime.
- **Widget:** **~40–70 timeline refreshes per day total across all
  widgets on the device.** Anything finer than ~15 min will be starved.

**Dead reckoning pattern.** The visible O₂ animation is our local
model's *prediction* of usage since the last authoritative event. OS
threshold callbacks are **corrections**: each one snaps our model back
to ground truth. Same mental model as GPS map animation — position
extrapolated between fixes, jerked onto the real path when a new fix
arrives. **This is the highest-leverage thing to test exhaustively in
the M2 reducer suite.**

---

## Shield arming race

Because `ManagedSettings` shields only engage on *next app foreground*,
not during an in-progress session, the "budget exhausted" callback must
fire *slightly before* real zero. Otherwise a user tap that races the
100 % callback slips one extra session through the door.

**Mitigation:** register a rung at ~95 % of the daily budget that
pre-arms the shield. By the time the user taps an app icon, the shield
is already in place. All mature Screen Time apps (Opal, Jomo, One Sec)
do a variant of this.

Bake it into the threshold ladder from day one.

---

## Three presence channels, layered

| Channel | When it shows | Interrupts? | Driven from |
|---|---|---|---|
| Live Activity + Dynamic Island | During an active dive | No — informational | `ActivityKit` from the app or monitor extension |
| Home / Lock Screen Widget | Between dives, all day | No — passive glance | `WidgetKit` timeline (~40–70 refreshes/day total) |
| `ManagedSettings` Shield | On foreground attempt after budget is exhausted | **Yes — iOS replaces the app's UI with our SwiftUI shield screen until the user backgrounds it** | `ManagedSettingsStore` from monitor extension |

They layer rather than compete. While a dive is in progress the Live
Activity is live *and* the widget updates in the background. When
budget hits zero, the next time the user tries to open a monitored
app, iOS shows our shield screen *instead of* the app's UI.

**Crucial subtlety:** the shield does **not** yank the user out of an
app mid-session. It is a gatekeeper at the door, not a timer inside the
room. The threshold ladder is what makes the gatekeeper effectively
on-time.

---

## Extension targets and their constraints

Each of the following runs in its own sandboxed process with its own
memory budget. This is why React Native would have been a nightmare —
you do not want a JS runtime in any of these.

| Target | Runs when | Approx memory budget |
|---|---|---|
| `sealoMonitor` (`DeviceActivityMonitor`) | Threshold callbacks fire | ~30 MB |
| `sealoShieldConfig` (`ShieldConfigurationExtension`) | Shield screen needs to render | ~30 MB |
| `sealoShieldAction` (`ShieldActionExtension`) | User taps shield button | ~30 MB |
| `sealoWidget` (`WidgetKit` + `ActivityKit`) | Widget timeline refresh / Live Activity render | ~30 MB |

All four talk to the main app through the **App Group shared container
only**. No direct IPC, no NSDistributedNotificationCenter, no file-less
signalling. Every state change gets written to the shared SQLite DB or
shared `UserDefaults` and read on the other side.

### Extension point identifiers — verify against `xctemplate`

The exact `NSExtensionPointIdentifier` string in each extension's
`Info.plist` must match what iOS's extension-host daemon is looking
for. Apple's documentation drifts from SDK reality; **the ground
truth is the `xctemplate` files under
`/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/Library/Xcode/Templates/Project Templates/iOS/Application Extension/*.xctemplate/TemplateInfo.plist`**.

Grepping for `NSExtensionPointIdentifier` in those files is the
authoritative lookup. Values that bit us during M3–M5:

| Extension | Wrong guess | Correct (verified) |
|---|---|---|
| DeviceActivityMonitor | `com.apple.deviceactivitymonitor` | `com.apple.deviceactivity.monitor-extension` |
| ShieldConfiguration | — | `com.apple.ManagedSettingsUI.shield-configuration-service` |
| ShieldAction | `com.apple.ManagedSettingsUI.shield-action-service` | `com.apple.ManagedSettings.shield-action-service` |

Pattern: extensions that *render UI* use `ManagedSettingsUI`.
Extensions that *respond to events without rendering* use plain
`ManagedSettings`. DeviceActivityMonitor is non-UI and lives under
`deviceactivity` (not `deviceactivityUI`).

### Xcode 26.4 `devicectl` bug — `appGroupDataContainer` copy

`xcrun devicectl device copy from --domain-type appGroupDataContainer`
fails in Xcode 26.4 with error code 7000:

```
File paths cannot contain '..'
(com.apple.dt.remoteservices.error error 11007)
NSFilePath = /private/var/mobile/Containers/Shared/AppGroup/<UUID>/<filename>
```

The device-side path has no `..` — the error is an internal
path-validation bug in `devicectl`'s handling of the app-group
domain. `--domain-type appDataContainer` works correctly.

**Workaround**: the main app mirrors the App Group log file into
its own `Documents/` folder on scene-active (see
`FileLogger.mirrorToMainAppDocuments()`). `./scripts/pull-logs.sh`
pulls via `appDataContainer` instead. Revisit when Xcode ships a
fix.

---

## Testing and signing tiers

### Free tier (no Developer Program enrollment)
- Xcode Personal Team signing. 7-day provisioning — re-install weekly.
- **Everything except Family Controls works.** This is the tier M0–M2
  runs on against `FakeScreenTimeService`.
- No TestFlight, no long-lived provisioning, no App Store submission.

### Paid tier ($99/yr Apple Developer Program)
- Required for the Family Controls entitlement application.
- 1-year provisioning profiles. TestFlight internal + external betas.
- App Store submission.
- Entitlement review takes days — apply in parallel with early
  milestones.

---

## What we are *not* using (and why)

- **`FamilyControls.AuthorizationCenter` without entitlement** — does
  not exist. The authorization API itself requires the entitlement.
- **`ScreenTime` framework (deprecated)** — superseded by Family
  Controls in iOS 15. Do not touch.
- **Push-driven Live Activity updates via ActivityKit push token** —
  deferred. v1 updates from the main app process and the monitor
  extension directly, which is simpler and stays within Apple's rate
  limits for our cadence. Revisit if we ever need cross-device sync
  (out of scope per `A6`).
- **App Intents / `Button(intent:)` in the Live Activity** — deferred.
  The Live Activity is a deep-link surface, not a control surface, per
  `D3`. Adding interactive buttons means an App Intents extension,
  which we do not need in v1.
- **CoreData / SwiftData** — App Group extension sharing is cleaner
  with GRDB + raw SQLite. Revisit only if a compelling reason appears.
