import SwiftUI

/// M0 placeholder root view. Replaced in M1 when the dashboard, schedule
/// editor, dive history, and debug Gallery tab land.
struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("divingbell")
                .font(.largeTitle.weight(.semibold))
            Text("M0 scaffold — real UI lands in M1")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
