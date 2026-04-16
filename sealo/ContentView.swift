import SwiftUI

/// M2 dashboard. Shows the OxygenTankGauge driven by live AppStore
/// state, plus controls to simulate dives via FakeScreenTimeService
/// events. Real Screen Time integration replaces the fake controls
/// in M3; real dashboard design replaces this layout in M1.
struct ContentView: View {
    @Bindable var store: AppStore

    var body: some View {
        VStack(spacing: 24) {
            Text("Sealo")
                .font(.title2.weight(.semibold))

            // Gauge driven by the reducer's fill fraction.
            OxygenTankGauge(fill: store.state.fillFraction)
                .frame(width: 260, height: 120)

            // Stats row.
            HStack(spacing: 32) {
                statCell(
                    label: "O₂",
                    value: String(format: "%.0f%%", store.state.fillFraction * 100)
                )
                statCell(
                    label: "Dives",
                    value: "\(store.state.dailyBudget.consumedDives)/\(store.state.dailyBudget.maxDives)"
                )
                statCell(
                    label: "Min left",
                    value: String(format: "%.0f", store.state.dailyBudget.remainingMinutes)
                )
            }

            if store.state.isExhausted {
                Text("Oxygen depleted")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Fake dive controls (replaced by real Screen Time in M3).
            fakeControls
        }
        .padding()
        .onAppear {
            store.send(.appBecameActive)
        }
    }

    // MARK: - Fake dive controls

    @ViewBuilder
    private var fakeControls: some View {
        VStack(spacing: 12) {
            Text("Simulate (debug)")
                .font(.caption)
                .foregroundStyle(.tertiary)

            // Reducer + dashboard state controls (from M2).
            HStack(spacing: 16) {
                Button(store.state.isDiving ? "End dive" : "Start dive") {
                    if store.state.isDiving {
                        store.send(.screenTime(.diveEnded))
                    } else {
                        store.send(.screenTime(.diveStarted))
                    }
                    syncLiveActivity()
                }
                .buttonStyle(.borderedProminent)
                .tint(store.state.isDiving ? .red : .teal)
                .disabled(store.state.isExhausted && !store.state.isDiving)

                Button("+1 min") {
                    store.send(.screenTime(.thresholdReached(
                        totalMinutes: Int(store.state.dailyBudget.consumedMinutes) + 1
                    )))
                    syncLiveActivity()
                }
                .buttonStyle(.bordered)
                .disabled(!store.state.isDiving)

                Button("New day") {
                    store.send(.dayRolled)
                    // Also stop + restart monitoring so iOS's own
                    // threshold-crossing state is wiped. Without this,
                    // iOS remembers the 1-sec dive-started threshold
                    // was already crossed today and re-fires it
                    // immediately on the next app foreground, making
                    // our "fresh day" state pop back to used.
                    Task {
                        let service = RealScreenTimeService()
                        try? await service.stopMonitoring()
                        try? await service.startMonitoring()
                    }
                }
                .buttonStyle(.bordered)
            }

            if store.state.isDiving {
                Button("Tick (dead reckon)") {
                    store.send(.tick)
                    syncLiveActivity()
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }

            // M4 Live Activity preview controls. Works in the
            // simulator, which can render Live Activities even
            // though it can't do real Screen Time accounting.
            Divider().padding(.vertical, 4)

            Text("Live Activity (M4 preview)")
                .font(.caption)
                .foregroundStyle(.tertiary)

            HStack(spacing: 16) {
                Button("Start LA") {
                    let startedAt = store.state.currentDive?.startedAt
                                  ?? Date()
                    let state = DiveActivityAttributes.ContentState(
                        from: store.state.dailyBudget,
                        diveStartedAt: startedAt,
                        isShieldArmed: store.state.isShieldArmed
                    )
                    LiveActivityController.start(state)
                }
                .buttonStyle(.bordered)

                Button("Update LA") {
                    syncLiveActivity()
                }
                .buttonStyle(.bordered)

                Button("End LA") {
                    Task { await LiveActivityController.endAll() }
                }
                .buttonStyle(.bordered)
            }
        }
    }

    /// Push the reducer's current snapshot into the Live Activity,
    /// whether or not an activity is running (no-op if none).
    private func syncLiveActivity() {
        let startedAt = store.state.currentDive?.startedAt
                      ?? SharedDefaults.diveStartedAt
                      ?? Date()
        let state = DiveActivityAttributes.ContentState(
            from: store.state.dailyBudget,
            diveStartedAt: startedAt,
            isShieldArmed: store.state.isShieldArmed
        )
        Task { await LiveActivityController.update(state) }
    }

    // MARK: - Helpers

    private func statCell(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.monospacedDigit().weight(.semibold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview("Full budget") {
    ContentView(store: AppStore(
        schedule: Schedule(maxMinutesPerDay: 60, maxDivesPerDay: 6)
    ))
}

#Preview("Mid-dive at 50%") {
    let clock = FakeClock()
    let store = AppStore(schedule: Schedule(maxMinutesPerDay: 10, maxDivesPerDay: 6), clock: clock)
    store.send(.screenTime(.diveStarted))
    clock.advance(by: 300)
    store.send(.tick)
    return ContentView(store: store)
}

#Preview("Exhausted") {
    let clock = FakeClock()
    let store = AppStore(schedule: Schedule(maxMinutesPerDay: 1, maxDivesPerDay: 6), clock: clock)
    store.send(.screenTime(.diveStarted))
    clock.advance(by: 60)
    store.send(.tick)
    store.send(.screenTime(.diveEnded))
    return ContentView(store: store)
}
