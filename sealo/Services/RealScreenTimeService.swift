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
    nonisolated(unsafe) private static let activityName = DeviceActivityName("sealo.daily")

    /// The `DeviceActivityEvent.Name` for the 1-sec "dive started" trigger.
    nonisolated(unsafe) private static let diveStartedEvent = DeviceActivityEvent.Name("sealo.diveStarted")

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
        Log.service.notice("startMonitoring() called; schedule = \(userSchedule.maxMinutesPerDay) min / \(userSchedule.maxDivesPerDay) dives")

        // Build the threshold ladder.
        let ladderEvents = ThresholdLadder.events(
            forMaxMinutes: userSchedule.maxMinutesPerDay
        )
        Log.service.notice("ladder rungs = \(ladderEvents.count)")

        // Load the user's app selection. A FamilyActivitySelection
        // can contain three disjoint token sets — we need to watch
        // ALL of them because the picker can return apps, categories,
        // or web domains depending on how the user picked them.
        var appTokens: Set<ApplicationToken> = []
        var categoryTokens: Set<ActivityCategoryToken> = []
        var webDomainTokens: Set<WebDomainToken> = []

        if let selectionData = SharedDefaults.loadAppSelectionData(),
           let selection = try? JSONDecoder().decode(
               FamilyActivitySelection.self, from: selectionData
           ) {
            appTokens = selection.applicationTokens
            categoryTokens = selection.categoryTokens
            webDomainTokens = selection.webDomainTokens
        } else {
            Log.service.error("no app selection found in SharedDefaults")
        }

        Log.service.notice("selection tokens: apps=\(appTokens.count), categories=\(categoryTokens.count), webDomains=\(webDomainTokens.count)")

        guard !appTokens.isEmpty || !categoryTokens.isEmpty || !webDomainTokens.isEmpty else {
            Log.service.error("all three token sets are empty; DeviceActivityCenter would silently watch nothing. Aborting.")
            return
        }

        // Build events dictionary: 1-sec dive-started + ladder rungs.
        // Each event watches the SAME union of tokens (apps + categories
        // + web domains) so we don't miss anything the user picked.
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]

        events[Self.diveStartedEvent] = DeviceActivityEvent(
            applications: appTokens,
            categories: categoryTokens,
            webDomains: webDomainTokens,
            threshold: DateComponents(second: 1)
        )

        for (name, threshold) in ladderEvents {
            events[name] = DeviceActivityEvent(
                applications: appTokens,
                categories: categoryTokens,
                webDomains: webDomainTokens,
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

        // Stop any previous monitoring before re-registering so we
        // don't leak stale schedules across onboarding retries.
        center.stopMonitoring([Self.activityName])

        do {
            try center.startMonitoring(
                Self.activityName,
                during: monitoringSchedule,
                events: events
            )
            Log.service.notice("DeviceActivityCenter.startMonitoring succeeded with \(events.count) events")
        } catch {
            Log.service.error("DeviceActivityCenter.startMonitoring failed: \(error.localizedDescription)")
            throw error
        }
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

    /// Apply shield permanently over the monitored app set. Called
    /// from onboarding's "Start diving" tap (and from the "Edit
    /// monitored apps" flow when selection changes). From this point
    /// on, every foreground of a monitored app triggers our
    /// `SealoShieldConfigDataSource` → user taps "Continue diving" →
    /// `SealoShieldActionHandler` counts a new dive.
    ///
    /// Distinct from `armShield()` only conceptually — technically
    /// the same ManagedSettings call, just invoked at a different
    /// lifecycle moment. Kept separate method for readability and
    /// in case we later want to differentiate (e.g. hide "Continue
    /// diving" button on the exhaustion shield).
    public func applyPermanentShield() async throws {
        try await armShield()
        Log.service.notice("applyPermanentShield: shield applied to monitored set")
    }
}
