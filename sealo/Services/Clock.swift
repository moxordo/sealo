import Foundation

/// Abstraction over "what time is it right now" so domain code never
/// calls `Date()` directly.
///
/// `SystemClock` is the prod implementation. `FakeClock` lets tests
/// advance time manually and deterministically. Per `CLAUDE.md`:
/// "Never call `Date()` directly in domain code."
public protocol SealoClock: Sendable {
    /// The current date/time.
    var now: Date { get }
}

// MARK: - SystemClock (prod)

/// Wraps `Date()` for production use.
public struct SystemClock: SealoClock, Sendable {
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
public final class FakeClock: SealoClock, @unchecked Sendable {
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

// Date helpers (startOfDay, isSameDay) are in Shared/DateHelpers.swift
// so both the app and the DeviceActivityMonitor extension can use them.
