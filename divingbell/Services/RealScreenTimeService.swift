import Foundation
import FamilyControls
import DeviceActivity
import ManagedSettings

/// Production implementation of `ScreenTimeService`.
///
/// Wraps `AuthorizationCenter`, `DeviceActivityCenter`, and
/// `ManagedSettingsStore`. Used from M3 onward; M0–M2 used
/// `FakeScreenTimeService` exclusively.
public final class RealScreenTimeService: ScreenTimeService, @unchecked Sendable {

    private let center = DeviceActivityCenter()
    private let store = ManagedSettingsStore()

    /// The `DeviceActivityName` for our daily monitoring schedule.
    nonisolated(unsafe) private static let activityName = DeviceActivityName("divingbell.daily")

    /// The `DeviceActivityEvent.Name` for the 1-sec "dive started" trigger.
    nonisolated(unsafe) private static let diveStartedEvent = DeviceActivityEvent.Name("divingbell.diveStarted")

    public init() {}

    // MARK: - Authorization

    /// Request Family Controls authorization. Must be called before
    /// any monitoring can start. Shows the system permission dialog.
    public func requestAuthorization() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
    }

    /// Whether the user has already granted authorization.
    public var isAuthorized: Bool {
        AuthorizationCenter.shared.authorizationStatus == .approved
    }

    // MARK: - ScreenTimeService conformance

    public func startMonitoring() async throws {
        let userSchedule = SharedDefaults.loadSchedule()

        // Build the threshold ladder.
        let ladderEvents = ThresholdLadder.events(
            forMaxMinutes: userSchedule.maxMinutesPerDay
        )

        // Load the user's app selection for per-app events.
        var appTokens: Set<ApplicationToken> = []
        if let selectionData = SharedDefaults.loadAppSelectionData(),
           let selection = try? JSONDecoder().decode(
               FamilyActivitySelection.self, from: selectionData
           ) {
            appTokens = selection.applicationTokens
        }

        // Build events dictionary: 1-sec dive-started + ladder rungs.
        // Each event watches the same set of application tokens.
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]

        // Dive-started trigger: 1-second threshold.
        events[Self.diveStartedEvent] = DeviceActivityEvent(
            applications: appTokens,
            threshold: DateComponents(second: 1)
        )

        // Ladder rungs.
        for (name, threshold) in ladderEvents {
            events[name] = DeviceActivityEvent(
                applications: appTokens,
                threshold: threshold
            )
        }

        // Daily schedule: midnight to midnight, repeating.
        let monitoringSchedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
            repeats: true,
            warningTime: DateComponents(minute: 5)
        )

        try center.startMonitoring(
            Self.activityName,
            during: monitoringSchedule,
            events: events
        )
    }

    public func stopMonitoring() async throws {
        center.stopMonitoring([Self.activityName])
    }

    public func armShield() async throws {
        if let selectionData = SharedDefaults.loadAppSelectionData(),
           let selection = try? JSONDecoder().decode(
               FamilyActivitySelection.self, from: selectionData
           ) {
            store.shield.applications = selection.applicationTokens
            store.shield.applicationCategories = .specific(selection.categoryTokens)
            SharedDefaults.isShieldArmed = true
        }
    }

    public func disarmShield() async throws {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        SharedDefaults.isShieldArmed = false
    }
}
