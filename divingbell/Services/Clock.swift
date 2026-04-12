import Foundation

/// Abstraction over "what time is it right now" so domain code never
/// calls `Date()` directly.
///
/// `SystemClock` is the prod implementation. `FakeClock` lets tests
/// advance time manually and deterministically. Per `CLAUDE.md`:
/// "Never call `Date()` directly in domain code."
public protocol DivingbellClock: Sendable {
    /// The current date/time.
    var now: Date { get }
}

// MARK: - SystemClock (prod)

/// Wraps `Date()` for production use.
public struct SystemClock: DivingbellClock, Sendable {
    public init() {}
    public var now: Date { Date() }
}

// MARK: - FakeClock (tests)

/// A manually-controlled clock for deterministic tests.
///
/// Usage:
/// ```swift
/// let clock = FakeClock(now: someDate)
/// // ... trigger events ...
/// clock.advance(by: 300)  // 5 minutes later
/// // ... assert state ...
/// ```
public final class FakeClock: DivingbellClock, @unchecked Sendable {
    private var _now: Date

    public init(now: Date = Date(timeIntervalSinceReferenceDate: 0)) {
        self._now = now
    }

    public var now: Date { _now }

    /// Advance the clock by the given number of seconds.
    public func advance(by seconds: TimeInterval) {
        _now = _now.addingTimeInterval(seconds)
    }

    /// Set the clock to an exact date.
    public func set(to date: Date) {
        _now = date
    }
}

// MARK: - Calendar helpers

extension Date {
    /// The start of the calendar day (00:00:00) in the user's local
    /// timezone. Used for daily budget rollover per `A4`.
    public func startOfDay(in calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: self)
    }

    /// Whether two dates fall on the same calendar day in the user's
    /// local timezone.
    public func isSameDay(as other: Date, in calendar: Calendar = .current) -> Bool {
        calendar.isDate(self, inSameDayAs: other)
    }
}
