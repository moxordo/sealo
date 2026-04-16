import SwiftUI

@main
struct SealoApp: App {
    @State private var store: AppStore
    @AppStorage("sealo.isOnboarded") private var isOnboarded = false
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let schedule = SharedDefaults.loadSchedule()
        let store = AppStore(schedule: schedule)
        store.reconcileWithSharedState()
        self._store = State(initialValue: store)
    }

    /// Keeps the Live Activity in sync on scene activation.
    ///
    /// Start ownership: only the main app (foregrounded) can start
    /// activities — Apple restricts `Activity.request()` to the
    /// main app, not extensions. So we start here if none is
    /// running AND the user is onboarded. This is a fallback for
    /// the case where the activity expired (8h ActivityKit lifetime
    /// cap) or was manually dismissed.
    ///
    /// The monitor extension can only *update* a running activity.
    /// If no activity exists and the user never opens Sealo, dives
    /// are still counted in SharedDefaults — they just aren't shown
    /// in the Dynamic Island until the next app open re-starts it.
    private func refreshLiveActivity() async {
        guard isOnboarded else { return }

        let startedAt = store.state.currentDive?.startedAt
                       ?? SharedDefaults.diveStartedAt
                       ?? Date()
        let contentState = DiveActivityAttributes.ContentState(
            from: store.state.dailyBudget,
            diveStartedAt: startedAt,
            isShieldArmed: store.state.isShieldArmed
        )

        if LiveActivityController.isRunning {
            await LiveActivityController.update(contentState)
        } else {
            LiveActivityController.start(contentState)
        }
    }

    private var shouldShowDashboard: Bool {
        #if targetEnvironment(simulator)
        // Simulator can't grant Family Controls authorization, so
        // skip onboarding and go straight to the dashboard with
        // fake dive controls. Real onboarding runs on device only.
        return true
        #else
        return isOnboarded
        #endif
    }

    var body: some Scene {
        WindowGroup {
            if shouldShowDashboard {
                ContentView(store: store)
            } else {
                OnboardingView(isOnboarded: $isOnboarded)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // When the app comes to foreground (e.g., user switches
            // back to Sealo from Instagram), pull the latest state
            // the monitor extension wrote to the App Group while we
            // were backgrounded, then let the reducer reconcile
            // (day-roll detection, dead-reckoning advance, etc.).
            if newPhase == .active {
                store.reconcileWithSharedState()
                store.send(.appBecameActive)
                Task { await refreshLiveActivity() }
            }
        }
    }
}
