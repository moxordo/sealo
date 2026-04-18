import Foundation
import ManagedSettings

/// Handles taps on Sealo's shield buttons.
///
/// iOS invokes `handle(action:for:completionHandler:)` when the user
/// taps either button on our shield screen:
///
/// - **Primary button** ("Resurface"): user chooses to go back. We
///   keep the shield in place (`.none`), and iOS sends them to the
///   home screen. No dive counted.
/// - **Secondary button** ("Continue diving"): user acknowledges
///   they're starting a dive. We count a new dive in SharedDefaults,
///   update the Live Activity with the new dive state, and tell iOS
///   to defer the shield for this session (`.defer`) so the user
///   can actually use the app.
///
/// Per `D3` we do NOT offer "request more time" or any escape hatch
/// beyond a single dismiss action. The two buttons are the entire
/// interaction surface.
final class SealoShieldActionHandler: ShieldActionDelegate {

    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        handle(action: action, completion: completionHandler)
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        handle(action: action, completion: completionHandler)
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        handle(action: action, completion: completionHandler)
    }

    // MARK: - Unified handler

    private func handle(
        action: ShieldAction,
        completion: @escaping (ShieldActionResponse) -> Void
    ) {
        switch action {
        case .primaryButtonPressed:
            // "Resurface" — user chose to back out. Close the shield
            // and the monitored app goes back to the user's last
            // state (home screen typically). No dive counted.
            Log.monitor.notice("shield: Resurface (primary)")
            completion(.close)

        case .secondaryButtonPressed:
            // "Continue diving" — user commits to a dive.
            Log.monitor.notice("shield: Continue diving (secondary)")
            startNewDive()
            // `.defer` lifts the shield for this session so the user
            // can actually use the app. Shield will re-apply on next
            // foreground.
            completion(.defer)

        @unknown default:
            Log.monitor.error("shield: unknown action \(String(describing: action))")
            completion(.close)
        }
    }

    // MARK: - Dive accounting

    /// Record a new dive — increments count, sets start time, pushes
    /// fresh Live Activity content state. All via App Group shared
    /// state so the main app sees the update on its next
    /// `.appBecameActive`.
    private func startNewDive() {
        let now = Date()
        let count = SharedDefaults.consumedDives + 1
        SharedDefaults.consumedDives = count
        SharedDefaults.diveStartedAt = now
        SharedDefaults.lastThresholdUpdate = now

        // Update budget snapshot for the main app + widget to read.
        if var budget = SharedDefaults.loadDailyBudget() {
            budget.consumedDives = count
            SharedDefaults.saveDailyBudget(budget)

            let stateSnapshot = DiveActivityAttributes.ContentState(
                from: budget,
                diveStartedAt: now,
                isShieldArmed: SharedDefaults.isShieldArmed
            )
            Task { @MainActor in
                await LiveActivityController.update(stateSnapshot)
            }
        } else {
            Log.monitor.error("startNewDive: no daily budget in SharedDefaults")
        }
    }
}
