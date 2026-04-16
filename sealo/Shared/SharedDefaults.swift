import Foundation
import FamilyControls

/// Keys and accessors for the App Group shared `UserDefaults`.
///
/// Both the main app and the `DeviceActivityMonitor` extension
/// read/write through this layer. This is the only IPC mechanism
/// between the two processes — per `CLAUDE.md`, the App Group
/// shared container is non-negotiable.
///
/// Data is stored as JSON-encoded `Data` blobs keyed by string
/// constants. We use `Codable` round-tripping rather than individual
/// keys to keep the data model centralized and versionable.
public enum SharedDefaults {
    public static let suiteName = "group.com.moxordo.sealo"

    private static var suite: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    // MARK: - Keys

    private enum Key {
        static let dailyBudget = "sealo.dailyBudget"
        static let schedule = "sealo.schedule"
        static let appSelection = "sealo.appSelection"
        static let lastThresholdUpdate = "sealo.lastThresholdUpdate"
        static let diveStartedAt = "sealo.diveStartedAt"
        static let isShieldArmed = "sealo.isShieldArmed"
        static let consumedDives = "sealo.consumedDives"
    }

    // MARK: - Schedule

    public static func saveSchedule(_ schedule: Schedule) {
        if let data = try? JSONEncoder().encode(schedule) {
            suite.set(data, forKey: Key.schedule)
        }
    }

    public static func loadSchedule() -> Schedule {
        guard let data = suite.data(forKey: Key.schedule),
              let schedule = try? JSONDecoder().decode(Schedule.self, from: data)
        else { return Schedule() }
        return schedule
    }

    // MARK: - Daily budget

    public static func saveDailyBudget(_ budget: DailyBudget) {
        if let data = try? JSONEncoder().encode(budget) {
            suite.set(data, forKey: Key.dailyBudget)
        }
    }

    public static func loadDailyBudget() -> DailyBudget? {
        guard let data = suite.data(forKey: Key.dailyBudget),
              let budget = try? JSONDecoder().decode(DailyBudget.self, from: data)
        else { return nil }
        return budget
    }

    // MARK: - App selection (opaque FamilyControls token data)

    public static func saveAppSelection(_ data: Data) {
        suite.set(data, forKey: Key.appSelection)
    }

    public static func loadAppSelectionData() -> Data? {
        suite.data(forKey: Key.appSelection)
    }

    // MARK: - Atomic fields (extension writes, app reads)

    public static var lastThresholdUpdate: Date? {
        get { suite.object(forKey: Key.lastThresholdUpdate) as? Date }
        set { suite.set(newValue, forKey: Key.lastThresholdUpdate) }
    }

    /// When the current dive started. Written by the monitor
    /// extension on the 1-sec dive-started callback; read by the
    /// Live Activity and home widget to drive the mm:ss timer.
    public static var diveStartedAt: Date? {
        get { suite.object(forKey: Key.diveStartedAt) as? Date }
        set { suite.set(newValue, forKey: Key.diveStartedAt) }
    }

    public static var isShieldArmed: Bool {
        get { suite.bool(forKey: Key.isShieldArmed) }
        set { suite.set(newValue, forKey: Key.isShieldArmed) }
    }

    public static var consumedDives: Int {
        get { suite.integer(forKey: Key.consumedDives) }
        set { suite.set(newValue, forKey: Key.consumedDives) }
    }
}
