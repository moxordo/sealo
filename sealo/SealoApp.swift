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

    /// Keeps the Live Activity in sync with the dashboard's view of
    /// the world on scene activation. **Only updates**; never starts.
    /// Starting a Live Activity is owned by the monitor extension
    /// (which knows the exact moment a real dive begins on a
    /// monitored app). If the main app also started them, any Sealo
    /// re-entry would create a phantom dive Live Activity even when
    /// the user never opened Instagram.
    private func refreshLiveActivity() async {
        guard isOnboarded,
              LiveActivityController.isRunning,
              let startedAt = store.state.currentDive?.startedAt
                              ?? SharedDefaults.diveStartedAt
        else { return }

        let contentState = DiveActivityAttributes.ContentState(
            from: store.state.dailyBudget,
            diveStartedAt: startedAt,
            isShieldArmed: store.state.isShieldArmed
        )
        await LiveActivityController.update(contentState)
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
