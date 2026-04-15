import Foundation

/// Top-level app state observed by the UI layer.
///
/// This is the single source of truth that the reducer mutates and
/// the SwiftUI views observe via `@Observable`. It bundles the live
/// budget, the current dive (if any), and derived flags the UI needs.
///
/// Per `A7`, this is a plain struct held inside an `@Observable`
/// `AppStore` — no TCA, no Redux dep.
public struct OxygenState: Equatable, Sendable {
    /// The user's dive schedule (limits per day).
    public var schedule: Schedule

    /// Today's budget. Replaced on midnight rollover.
    public var dailyBudget: DailyBudget

    /// The dive currently in progress, if any. Also stored inside
    /// `dailyBudget.dives`, but kept here as a convenience so the UI
    /// doesn't have to scan the array.
    public var currentDive: DiveSession?

    /// Whether the `ManagedSettings` shield is currently armed.
    /// Becomes `true` at ~95% consumption (pre-arm) per
    /// `05-feasibility-notes.md` "Shield arming race".
    public var isShieldArmed: Bool

    /// The `Date` of the last authoritative correction from the
    /// `DeviceActivityMonitor` threshold callback. Dead-reckoning
    /// ticks advance `consumedSeconds` from this anchor.
    public var lastThresholdUpdate: Date?

    public init(
        schedule: Schedule = Schedule(),
        dailyBudget: DailyBudget,
        currentDive: DiveSession? = nil,
        isShieldArmed: Bool = false,
        lastThresholdUpdate: Date? = nil
    ) {
        self.schedule = schedule
        self.dailyBudget = dailyBudget
        self.currentDive = currentDive
        self.isShieldArmed = isShieldArmed
        self.lastThresholdUpdate = lastThresholdUpdate
    }

    // MARK: - Convenience accessors

    /// The O₂ gauge fill fraction (0...1).
    public var fillFraction: Double { dailyBudget.fillFraction }

    /// Whether the budget is fully exhausted.
    public var isExhausted: Bool { dailyBudget.isExhausted }

    /// Whether a dive is currently in progress.
    public var isDiving: Bool { currentDive != nil }
}
