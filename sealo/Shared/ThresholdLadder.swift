import Foundation
import DeviceActivity

/// Builds the threshold ladder of `DeviceActivityEvent`s to register
/// with `DeviceActivityCenter`.
///
/// Per `docs/05-feasibility-notes.md`:
/// - Practical minimum threshold ~1 minute.
/// - Practical maximum ~20 events per schedule.
/// - Dense near the budget ceiling (shield-arming accuracy), sparse
///   early (save event budget for where it matters).
///
/// The ladder is rebuilt whenever the schedule changes or a new day
/// starts. Each rung fires exactly once per monitoring interval.
public enum ThresholdLadder {

    /// Maximum total DeviceActivityEvent rungs per schedule. iOS
    /// caps this around 20; we use 19 to leave headroom for the
    /// pre-arm rung that gets inserted separately.
    private static let maxRungs = 19

    /// Generate a ladder of minute thresholds for a given budget.
    ///
    /// Strategy — density-weighted for real SNS usage patterns:
    /// - **Dense early** (1-min precision for minutes 1..5): most
    ///   user sessions are short, so the gauge should feel
    ///   responsive in the first few minutes of a dive.
    /// - **Sparse middle** (every 5 min): long sessions are less
    ///   common and users don't need second-by-second precision
    ///   when they're deep in the dive.
    /// - **Dense end** (every 1 min for last 5 min): shield-arming
    ///   timing accuracy matters here, so no coarse rungs allowed.
    ///
    /// Budget-aware: tiny budgets (<10 min) use 1-min everywhere.
    ///
    /// Returns minute values in ascending order, no duplicates.
    public static func rungs(forMaxMinutes maxMinutes: Int) -> [Int] {
        guard maxMinutes > 0 else { return [] }

        var rungs: Set<Int> = []

        // For tiny budgets, just use 1-min everywhere.
        if maxMinutes <= 10 {
            for m in 1...maxMinutes {
                rungs.insert(m)
            }
        } else {
            // Dense early: minutes 1..5.
            for m in 1...min(5, maxMinutes) {
                rungs.insert(m)
            }

            // Sparse middle: every 5 minutes from 10 up to (max - 5).
            let middleEnd = max(0, maxMinutes - 5)
            var t = 10
            while t <= middleEnd {
                rungs.insert(t)
                t += 5
            }

            // Dense end: minutes (max-4)...max.
            let denseStart = max(1, maxMinutes - 4)
            for m in denseStart...maxMinutes {
                rungs.insert(m)
            }

            // Pre-arm rung at 95% if not already covered.
            let preArm = Int(Double(maxMinutes) * 0.95)
            if preArm > 0 {
                rungs.insert(preArm)
            }
        }

        // Cap at maxRungs by pruning middle-density rungs first.
        var sorted = rungs.sorted()
        while sorted.count > maxRungs {
            // Drop the rung with the largest neighbour gap in the
            // middle section (keeps both dense ends intact).
            let middleStart = 5
            let middleEnd = maxMinutes - 5
            if let victim = sorted.first(where: {
                $0 > middleStart && $0 < middleEnd
            }) {
                sorted.removeAll { $0 == victim }
            } else {
                sorted.removeLast()
            }
        }

        return sorted
    }

    /// Convert minute thresholds into `DeviceActivityEvent.Name` +
    /// `DateComponents` pairs suitable for `DeviceActivitySchedule`.
    public static func events(
        forMaxMinutes maxMinutes: Int
    ) -> [(name: DeviceActivityEvent.Name, threshold: DateComponents)] {
        rungs(forMaxMinutes: maxMinutes).map { minutes in
            let name = DeviceActivityEvent.Name("sealo.threshold.\(minutes)m")
            var dc = DateComponents()
            dc.minute = minutes
            return (name: name, threshold: dc)
        }
    }
}
