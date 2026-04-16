import DeviceActivity
import FamilyControls
import ManagedSettings
import Foundation

/// The system-managed extension that receives `DeviceActivityMonitor`
/// threshold callbacks.
///
/// This runs in its own sandboxed process (~30 MB memory budget). It
/// cannot access the main app's `AppStore` — all IPC goes through
/// `SharedDefaults` (App Group UserDefaults).
///
/// Responsibilities:
/// 1. Detect dive-start (1-second threshold → increment dive count).
/// 2. Snap consumed time on each threshold rung.
/// 3. Arm the `ManagedSettings` shield when budget is at 95% or 100%.
/// 4. Disarm the shield on interval end (midnight rollover).
///
/// The main app reconciles its `AppStore` state from `SharedDefaults`
/// on every `.appBecameActive` event.
class SealoMonitor: DeviceActivityMonitor {

    private let store = ManagedSettingsStore()

    // MARK: - DeviceActivityMonitor callbacks

    override func intervalDidStart(for activity: DeviceActivityName) {
        Log.monitor.notice("intervalDidStart for \(activity.rawValue)")

        // New monitoring interval started (typically at midnight).
        // Reset the daily budget in shared state.
        let schedule = SharedDefaults.loadSchedule()
        let freshBudget = DailyBudget(
            date: Date().startOfDay(),
            maxMinutes: schedule.maxMinutesPerDay,
            maxDives: schedule.maxDivesPerDay
        )
        SharedDefaults.saveDailyBudget(freshBudget)
        SharedDefaults.isShieldArmed = false
        SharedDefaults.consumedDives = 0
        SharedDefaults.lastThresholdUpdate = nil

        // Disarm any leftover shield from yesterday.
        store.shield.applications = nil
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        Log.monitor.notice("intervalDidEnd for \(activity.rawValue)")
        store.shield.applications = nil
        SharedDefaults.isShieldArmed = false
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        let eventName = event.rawValue
        Log.monitor.notice("eventDidReachThreshold: \(eventName) (activity=\(activity.rawValue))")

        // Parse the threshold minute from the event name.
        // Format: "sealo.threshold.Nm" where N is the minute count.
        // Special case: "sealo.diveStarted" for the 1-sec trigger.
        if eventName == "sealo.diveStarted" {
            handleDiveStarted()
            return
        }

        guard eventName.hasPrefix("sealo.threshold."),
              let minuteStr = eventName.split(separator: ".").last?.dropLast(), // drop "m"
              let minutes = Int(minuteStr)
        else {
            Log.monitor.error("unrecognised event name: \(eventName)")
            return
        }

        handleThresholdReached(totalMinutes: minutes)
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        Log.monitor.notice("intervalWillEndWarning for \(activity.rawValue)")
    }

    // MARK: - Handlers

    private func handleDiveStarted() {
        let now = Date()
        let count = SharedDefaults.consumedDives + 1
        SharedDefaults.consumedDives = count
        SharedDefaults.lastThresholdUpdate = now
        SharedDefaults.diveStartedAt = now
        Log.monitor.notice("handleDiveStarted: count=\(count)")

        if var budget = SharedDefaults.loadDailyBudget() {
            budget.consumedDives = count
            SharedDefaults.saveDailyBudget(budget)

            // Start or update the Live Activity. The extension is
            // the only surface that knows the EXACT moment a dive
            // begins (user foregrounded a monitored app), so it
            // owns the `start` action — the main app only updates.
            let stateSnapshot = DiveActivityAttributes.ContentState(
                from: budget,
                diveStartedAt: now,
                isShieldArmed: SharedDefaults.isShieldArmed
            )
            Task { @MainActor in
                if LiveActivityController.isRunning {
                    await LiveActivityController.update(stateSnapshot)
                } else {
                    LiveActivityController.start(stateSnapshot)
                }
            }

            if budget.isExhausted || budget.shouldPreArmShield {
                armShield()
            }
        } else {
            Log.monitor.error("handleDiveStarted: no daily budget in SharedDefaults")
        }
    }

    private func handleThresholdReached(totalMinutes: Int) {
        let now = Date()
        SharedDefaults.lastThresholdUpdate = now
        Log.monitor.notice("handleThresholdReached: totalMinutes=\(totalMinutes)")

        if var budget = SharedDefaults.loadDailyBudget() {
            budget.consumedSeconds = Double(totalMinutes) * 60.0
            SharedDefaults.saveDailyBudget(budget)

            // Update Live Activity with the new gauge fill.
            let diveStartedAt = SharedDefaults.diveStartedAt ?? now
            let stateSnapshot = DiveActivityAttributes.ContentState(
                from: budget,
                diveStartedAt: diveStartedAt,
                isShieldArmed: SharedDefaults.isShieldArmed
            )
            Task { @MainActor in
                await LiveActivityController.update(stateSnapshot)
            }

            if budget.isExhausted || budget.shouldPreArmShield {
                armShield()
            }
        } else {
            Log.monitor.error("handleThresholdReached: no daily budget in SharedDefaults")
        }
    }

    private func armShield() {
        guard !SharedDefaults.isShieldArmed else { return }

        // Load the user's app selection and apply the shield.
        if let selectionData = SharedDefaults.loadAppSelectionData(),
           let selection = try? JSONDecoder().decode(
               FamilyActivitySelection.self, from: selectionData
           ) {
            store.shield.applications = selection.applicationTokens
            store.shield.applicationCategories = .specific(selection.categoryTokens)
            SharedDefaults.isShieldArmed = true
        }
    }
}
