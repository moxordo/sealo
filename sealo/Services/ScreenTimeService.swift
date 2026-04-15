import Foundation

/// Events that the Screen Time layer fires into the domain.
///
/// In prod (`RealScreenTimeService`, M3), these are driven by
/// `DeviceActivityMonitor` threshold callbacks. In tests
/// (`FakeScreenTimeService`), they are injected manually.
public enum ScreenTimeEvent: Equatable, Sendable {
    /// The user entered an app in the monitored set. Corresponds to
    /// the 1-second `DeviceActivityEvent` threshold trick described
    /// in `05-feasibility-notes.md`.
    case diveStarted

    /// The user left the monitored set (inferred from the monitoring
    /// interval ending or a new day rolling over without further
    /// threshold callbacks).
    case diveEnded

    /// The user has accumulated `totalMinutes` of usage in the
    /// monitored set during this monitoring interval. Each rung of
    /// the threshold ladder fires exactly once.
    case thresholdReached(totalMinutes: Int)
}

/// Boundary protocol between the domain and iOS Screen Time APIs.
///
/// `RealScreenTimeService` (M3) wraps `FamilyControls`,
/// `DeviceActivity`, and `ManagedSettings`. `FakeScreenTimeService`
/// (below) lets tests drive the event stream and verify shield state
/// without touching any real iOS framework.
public protocol ScreenTimeService: Sendable {
    /// Start monitoring the user-chosen app set. In prod, this
    /// registers a `DeviceActivitySchedule` + the threshold ladder.
    func startMonitoring() async throws

    /// Stop monitoring.
    func stopMonitoring() async throws

    /// Arm the `ManagedSettings` shield on the monitored app set.
    /// Called when budget hits ~95% (pre-arm) or 100% (hard arm).
    func armShield() async throws

    /// Disarm the shield (e.g., on midnight rollover).
    func disarmShield() async throws
}

// MARK: - FakeScreenTimeService

/// Test-only implementation that records calls and lets tests inject
/// events into the domain via a closure.
public final class FakeScreenTimeService: ScreenTimeService, @unchecked Sendable {
    public private(set) var isMonitoring = false
    public private(set) var isShieldArmed = false

    /// Every call to a protocol method is logged here for assertions.
    public private(set) var callLog: [String] = []

    public init() {}

    public func startMonitoring() async throws {
        isMonitoring = true
        callLog.append("startMonitoring")
    }

    public func stopMonitoring() async throws {
        isMonitoring = false
        callLog.append("stopMonitoring")
    }

    public func armShield() async throws {
        isShieldArmed = true
        callLog.append("armShield")
    }

    public func disarmShield() async throws {
        isShieldArmed = false
        callLog.append("disarmShield")
    }
}
