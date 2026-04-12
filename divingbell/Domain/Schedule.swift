import Foundation

/// The user's pre-configured daily dive limits.
///
/// Per the original intention: "I can pre-schedule how much of dive
/// time and dive sessions I can do per day." The schedule holds both
/// limits. Per `A5`, the shield engages when *either* limit is hit.
///
/// The schedule is set once (during onboarding or in the schedule
/// editor) and does not change mid-dive. Future milestones may add
/// per-weekday or per-time-of-day scheduling; for now it is a single
/// flat config.
public struct Schedule: Codable, Equatable, Sendable {
    /// Maximum total minutes of dive time per day.
    public var maxMinutesPerDay: Int

    /// Maximum number of discrete dive sessions per day.
    public var maxDivesPerDay: Int

    public init(maxMinutesPerDay: Int = 60, maxDivesPerDay: Int = 6) {
        self.maxMinutesPerDay = maxMinutesPerDay
        self.maxDivesPerDay = maxDivesPerDay
    }
}
