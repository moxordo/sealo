import Foundation
import Observation

/// Events that can be dispatched to the `AppStore` reducer.
public enum AppEvent: Equatable, Sendable {
    /// A `ScreenTimeEvent` arrived from the service layer.
    case screenTime(ScreenTimeEvent)

    /// Dead-reckoning tick. Fired by a timer while a dive is in
    /// progress. The reducer advances `consumedSeconds` by the
    /// elapsed time since `lastThresholdUpdate`.
    case tick

    /// The user changed their schedule in the schedule editor.
    case scheduleChanged(Schedule)

    /// Midnight rollover detected. Resets the daily budget.
    case dayRolled

    /// App came to foreground (or was relaunched by the OS).
    /// Reconcile state: check if a day rolled while backgrounded,
    /// resume a dive if one was in progress, etc.
    case appBecameActive
}

/// Observable store holding the app's live state.
///
/// Per `A7`, this is a plain `@Observable` class with a synchronous
/// `send(_:)` method — no TCA, no middleware, no async reducers.
/// All side effects (starting/stopping monitoring, arming shields)
/// are returned as `Effect` values that the caller is responsible
/// for executing. This keeps the reducer pure and testable.
@Observable
public final class AppStore {
    public private(set) var state: OxygenState
    public let clock: any SealoClock

    public init(
        schedule: Schedule = Schedule(),
        clock: any SealoClock = SystemClock()
    ) {
        self.clock = clock
        let now = clock.now
        self.state = OxygenState(
            schedule: schedule,
            dailyBudget: DailyBudget(
                date: now.startOfDay(),
                maxMinutes: schedule.maxMinutesPerDay,
                maxDives: schedule.maxDivesPerDay
            )
        )
    }

    /// Convenience initializer for tests that need full control.
    public init(state: OxygenState, clock: any SealoClock) {
        self.state = state
        self.clock = clock
    }

    /// Reconcile local state with the App Group shared state written
    /// by the `DeviceActivityMonitor` extension while we were backgrounded.
    public func reconcileWithSharedState() {
        if let sharedBudget = SharedDefaults.loadDailyBudget() {
            state.dailyBudget = sharedBudget
        }
        state.isShieldArmed = SharedDefaults.isShieldArmed
        state.lastThresholdUpdate = SharedDefaults.lastThresholdUpdate
    }

    // MARK: - Reducer

    /// Side effects the caller should execute after `send` returns.
    public enum Effect: Equatable, Sendable {
        case armShield
        case disarmShield
        case startMonitoring
        case stopMonitoring
    }

    /// Dispatch an event and get back any side effects to execute.
    /// The reducer itself is **pure** — it only mutates `state` and
    /// returns effects; it never calls async APIs directly.
    @discardableResult
    public func send(_ event: AppEvent) -> [Effect] {
        var effects: [Effect] = []

        switch event {
        case .screenTime(let screenTimeEvent):
            effects = reduce(screenTimeEvent: screenTimeEvent)

        case .tick:
            effects = reduceTick()

        case .scheduleChanged(let newSchedule):
            state.schedule = newSchedule

        case .dayRolled:
            effects = reduceDayRolled()

        case .appBecameActive:
            effects = reduceAppBecameActive()
        }

        return effects
    }

    // MARK: - Sub-reducers

    private func reduce(screenTimeEvent: ScreenTimeEvent) -> [Effect] {
        var effects: [Effect] = []
        let now = clock.now

        switch screenTimeEvent {
        case .diveStarted:
            guard state.currentDive == nil else { return [] }
            guard !state.isExhausted else {
                // Budget already gone — ensure shield stays armed.
                if !state.isShieldArmed {
                    state.isShieldArmed = true
                    effects.append(.armShield)
                }
                return effects
            }

            let dive = DiveSession(startedAt: now)
            state.currentDive = dive
            state.dailyBudget.dives.append(dive)
            state.dailyBudget.consumedDives += 1
            state.lastThresholdUpdate = now

            // Check if the new dive count alone triggers pre-arm.
            effects.append(contentsOf: checkShieldArming())

        case .diveEnded:
            guard var dive = state.currentDive else { return [] }
            dive.endedAt = now
            state.currentDive = nil

            // Update the dive record in the log.
            if let idx = state.dailyBudget.dives.lastIndex(where: { $0.id == dive.id }) {
                state.dailyBudget.dives[idx] = dive
            }

            // Final tick to capture any remaining seconds.
            advanceConsumedTime(to: now)

        case .thresholdReached(let totalMinutes):
            // Authoritative correction: snap consumed time to the
            // OS-reported value and update the dead-reckoning anchor.
            state.dailyBudget.consumedSeconds = Double(totalMinutes) * 60.0
            state.lastThresholdUpdate = now
            effects.append(contentsOf: checkShieldArming())
        }

        return effects
    }

    private func reduceTick() -> [Effect] {
        guard state.isDiving else { return [] }
        let now = clock.now
        advanceConsumedTime(to: now)
        return checkShieldArming()
    }

    private func reduceDayRolled() -> [Effect] {
        let now = clock.now
        var effects: [Effect] = []

        // End any in-progress dive.
        if var dive = state.currentDive {
            dive.endedAt = now
            if let idx = state.dailyBudget.dives.lastIndex(where: { $0.id == dive.id }) {
                state.dailyBudget.dives[idx] = dive
            }
            state.currentDive = nil
        }

        // Fresh budget for the new day.
        state.dailyBudget = DailyBudget(
            date: now.startOfDay(),
            maxMinutes: state.schedule.maxMinutesPerDay,
            maxDives: state.schedule.maxDivesPerDay
        )
        state.lastThresholdUpdate = nil

        // Disarm shield for the new day.
        if state.isShieldArmed {
            state.isShieldArmed = false
            effects.append(.disarmShield)
        }

        return effects
    }

    private func reduceAppBecameActive() -> [Effect] {
        let now = clock.now

        // Check if a day rolled while we were backgrounded.
        if !now.isSameDay(as: state.dailyBudget.date) {
            return reduceDayRolled()
        }

        // If a dive was in progress, advance consumed time.
        if state.isDiving {
            advanceConsumedTime(to: now)
            return checkShieldArming()
        }

        return []
    }

    // MARK: - Helpers

    /// Dead reckoning: advance consumed seconds from the last known
    /// anchor to `now`.
    private func advanceConsumedTime(to now: Date) {
        guard let anchor = state.lastThresholdUpdate else {
            state.lastThresholdUpdate = now
            return
        }
        let elapsed = max(0, now.timeIntervalSince(anchor))
        state.dailyBudget.consumedSeconds += elapsed
        state.lastThresholdUpdate = now
    }

    /// Check whether the shield should be armed (pre-arm at ~95% or
    /// hard arm at 100%). Returns effects if shield state changed.
    private func checkShieldArming() -> [Effect] {
        if state.dailyBudget.isExhausted || state.dailyBudget.shouldPreArmShield {
            if !state.isShieldArmed {
                state.isShieldArmed = true
                return [.armShield]
            }
        }
        return []
    }
}
