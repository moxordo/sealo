import Foundation

/// Tracks how much of today's budget has been consumed.
///
/// One `DailyBudget` exists per calendar day (per `A4`, days roll at
/// local midnight). It is the authoritative accounting record for the
/// day — the reducer updates it on every threshold callback and on
/// every dead-reckoning tick.
///
/// Per `D2`, the budget is **set-wide**: all monitored apps share one
/// tank. Per `A5`, the shield arms when *either* `maxMinutes` or
/// `maxDives` is hit.
public struct DailyBudget: Codable, Equatable, Sendable {
    /// The calendar day this budget applies to (date-only, no time).
    public let date: Date

    /// Limits copied from the schedule at day-start so mid-day
    /// schedule changes don't retroactively adjust today's budget.
    public let maxMinutes: Int
    public let maxDives: Int

    /// Accumulated dive time in seconds. Updated on every threshold
    /// callback and on every dead-reckoning tick while a dive is in
    /// progress.
    public var consumedSeconds: TimeInterval

    /// Number of dives started today (completed or still in progress).
    public var consumedDives: Int

    /// Dive log for this day. Newest last.
    public var dives: [DiveSession]

    public init(
        date: Date,
        maxMinutes: Int,
        maxDives: Int,
        consumedSeconds: TimeInterval = 0,
        consumedDives: Int = 0,
        dives: [DiveSession] = []
    ) {
        self.date = date
        self.maxMinutes = maxMinutes
        self.maxDives = maxDives
        self.consumedSeconds = consumedSeconds
        self.consumedDives = consumedDives
        self.dives = dives
    }

    // MARK: - Derived state

    public var consumedMinutes: Double {
        consumedSeconds / 60.0
    }

    public var remainingMinutes: Double {
        max(0, Double(maxMinutes) - consumedMinutes)
    }

    public var remainingDives: Int {
        max(0, maxDives - consumedDives)
    }

    /// The O₂ fill fraction (0...1), representing **time** remaining
    /// in the daily budget only. Dive count is surfaced separately
    /// via the dot row in Live Activity + Lock Screen (`◎ ◎ ○ ○`).
    ///
    /// Previously this was `min(timeFraction, diveFraction)` so a
    /// single dive would drop the gauge by 1/maxDives even with zero
    /// time used (e.g. 83% gauge after 1 of 6 dives with 0 min spent).
    /// That conflated "oxygen/breath" with "dive count" — two
    /// distinct mental-model concepts. Oxygen = time remaining.
    /// Dive count is shown as dots. Both still gate the shield
    /// independently via `isExhausted`.
    public var fillFraction: Double {
        guard maxMinutes > 0 else { return 0 }
        return max(0, 1.0 - consumedMinutes / Double(maxMinutes))
    }

    /// True when either limit is hit. Per `D3`, this triggers the
    /// hard shield with no escape hatch.
    public var isExhausted: Bool {
        consumedMinutes >= Double(maxMinutes) || consumedDives >= maxDives
    }

    /// True when we should pre-arm the shield (~95% consumed) to
    /// avoid the arming race described in `05-feasibility-notes.md`.
    public var shouldPreArmShield: Bool {
        let timeRatio = maxMinutes > 0
            ? consumedMinutes / Double(maxMinutes)
            : 1.0
        let diveRatio = maxDives > 0
            ? Double(consumedDives) / Double(maxDives)
            : 1.0
        return max(timeRatio, diveRatio) >= 0.95
    }
}
