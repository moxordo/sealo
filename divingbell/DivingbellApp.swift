import SwiftUI

@main
struct DivingbellApp: App {
    @State private var store = AppStore(
        schedule: Schedule(maxMinutesPerDay: 60, maxDivesPerDay: 6)
    )

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
    }
}
