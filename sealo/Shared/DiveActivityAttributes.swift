import Foundation
import ActivityKit

/// The contract between the three processes involved in a Live Activity:
///
/// 1. **`sealoMonitor` extension** calls `Activity.request(...)` when
///    the 1-sec dive-start threshold fires, and `activity.update(...)`
///    on each threshold rung.
/// 2. **`sealoWidget` extension** renders the Live Activity (Dynamic
///    Island minimal/compact/expanded + Lock Screen) using the
///    current `ContentState` snapshot.
/// 3. **Main `sealo` app** can also update the activity (e.g. when a
///    debug control fires `.scheduleChanged`) and ends it on
///    `.dayRolled`.
///
/// Because the type is compiled into all three targets (via
/// project.yml sources inclusion), every site sees the same fields
/// with the same memory layout.
public struct DiveActivityAttributes: ActivityAttributes {

    /// Dynamic state that changes over the lifetime of the activity.
    /// Everything the UI depends on lives here. Kept small — Apple's
    /// guideline is under 4 KB per update to avoid throttling.
    public struct ContentState: Codable, Hashable, Sendable {
        /// O₂ gauge fill in 0...1. The main driver of the battery
        /// visual. Derived from `DailyBudget.fillFraction` at update
        /// time so the widget extension doesn't have to recompute it.
        public var fillFraction: Double

        /// Wall-clock instant this dive began. The widget uses
        /// `.timer(from:)` and `Text(timerInterval:)` to tick the
        /// mm:ss display without our code having to update every
        /// second.
        public var diveStartedAt: Date

        /// Which dive we're on today (1-based).
        public var diveNumber: Int

        /// Max dives per day per the current schedule. Drives the
        /// dive-count dots `◎ ◎ ◎ ○ ○ ○` in the expanded view.
        public var maxDives: Int

        /// Remaining minutes in the daily oxygen budget. Shown in the
        /// expanded view's center region.
        public var minutesRemaining: Double

        /// Whether the shield is currently armed. Drives the
        /// low-O₂ opacity pulse (battery pulses at reduced opacity
        /// when fillFraction < 15 % OR shield is armed).
        public var isShieldArmed: Bool

        public init(
            fillFraction: Double,
            diveStartedAt: Date,
            diveNumber: Int,
            maxDives: Int,
            minutesRemaining: Double,
            isShieldArmed: Bool
        ) {
            self.fillFraction = fillFraction
            self.diveStartedAt = diveStartedAt
            self.diveNumber = diveNumber
            self.maxDives = maxDives
            self.minutesRemaining = minutesRemaining
            self.isShieldArmed = isShieldArmed
        }
    }

    /// Static attributes set at activity-start time and never changed.
    /// Kept minimal — everything that might vary goes in ContentState.
    public let activityID: String

    public init(activityID: String = UUID().uuidString) {
        self.activityID = activityID
    }
}

// MARK: - Construction helpers

extension DiveActivityAttributes.ContentState {
    /// Build a content state from the current `OxygenState`. Used by
    /// the main app's `.diveStarted` → activity.request flow and by
    /// the monitor extension's `handleThresholdReached` → activity.update
    /// flow.
    public init(from state: OxygenState, dive: DiveSession) {
        self.init(
            fillFraction: state.dailyBudget.fillFraction,
            diveStartedAt: dive.startedAt,
            diveNumber: state.dailyBudget.consumedDives,
            maxDives: state.dailyBudget.maxDives,
            minutesRemaining: state.dailyBudget.remainingMinutes,
            isShieldArmed: state.isShieldArmed
        )
    }

    /// Build from raw SharedDefaults values — used by the monitor
    /// extension where the full OxygenState isn't constructed.
    public init(from budget: DailyBudget, diveStartedAt: Date, isShieldArmed: Bool) {
        self.init(
            fillFraction: budget.fillFraction,
            diveStartedAt: diveStartedAt,
            diveNumber: budget.consumedDives,
            maxDives: budget.maxDives,
            minutesRemaining: budget.remainingMinutes,
            isShieldArmed: isShieldArmed
        )
    }
}
