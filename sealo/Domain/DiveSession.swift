import Foundation

/// One discrete foreground session in the monitored SNS app set.
///
/// A dive starts when the `DeviceActivityMonitor` (or the fake)
/// fires the 1-second threshold callback, meaning the user just
/// entered an app in the monitored set. It ends when the user leaves
/// the set or the budget is exhausted.
///
/// Per `D2`, dives are **set-wide** — we do not track which specific
/// app the user is in, only that they are in the monitored set.
public struct DiveSession: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let startedAt: Date

    /// Nil while the dive is in progress; set when the dive ends
    /// (either voluntarily or by shield enforcement).
    public var endedAt: Date?

    public init(id: UUID = UUID(), startedAt: Date, endedAt: Date? = nil) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
    }

    /// Duration of this dive in seconds. If the dive is still in
    /// progress, pass `now` to compute the live duration; if ended,
    /// `now` is ignored.
    public func duration(now: Date) -> TimeInterval {
        let end = endedAt ?? now
        return max(0, end.timeIntervalSince(startedAt))
    }

    public var isInProgress: Bool { endedAt == nil }
}
