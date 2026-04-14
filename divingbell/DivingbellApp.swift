import SwiftUI

@main
struct DivingbellApp: App {
    @State private var store: AppStore
    @AppStorage("divingbell.isOnboarded") private var isOnboarded = false

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
    }
}
