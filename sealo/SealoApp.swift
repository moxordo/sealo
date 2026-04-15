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
            }
        }
    }
}
