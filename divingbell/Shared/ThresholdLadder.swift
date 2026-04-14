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

    /// Generate a ladder of minute thresholds for a given budget.
    ///
    /// Strategy: sparse early (every 5 min), dense near the ceiling
    /// (every 1 min in the last 10 min). Total rungs stay under 20.
    ///
    /// Returns minute values in ascending order.
    public static func rungs(forMaxMinutes maxMinutes: Int) -> [Int] {
        guard maxMinutes > 0 else { return [] }

        var result: [Int] = []

        // 1-second "dive started" rung is handled separately as the
        // DeviceActivityEvent with a 1-sec threshold. Not included here.

        // Sparse early phase: every 5 minutes up to (max - 10).
        let sparseEnd = max(0, maxMinutes - 10)
        var t = 5
        while t <= sparseEnd && result.count < 10 {
            result.append(t)
            t += 5
        }

        // Dense tail: every 1 minute in the last 10 minutes.
        let denseStart = max(1, maxMinutes - 9)
        for m in denseStart...maxMinutes {
            if !result.contains(m) && result.count < 19 {
                result.append(m)
            }
        }

        // Always include the 95% pre-arm rung if not already present.
        let preArmMinute = Int(Double(maxMinutes) * 0.95)
        if preArmMinute > 0 && !result.contains(preArmMinute) && result.count < 20 {
            result.append(preArmMinute)
            result.sort()
        }

        return result
    }

    /// Convert minute thresholds into `DeviceActivityEvent.Name` +
    /// `DateComponents` pairs suitable for `DeviceActivitySchedule`.
    public static func events(
        forMaxMinutes maxMinutes: Int
    ) -> [(name: DeviceActivityEvent.Name, threshold: DateComponents)] {
        rungs(forMaxMinutes: maxMinutes).map { minutes in
            let name = DeviceActivityEvent.Name("divingbell.threshold.\(minutes)m")
            var dc = DateComponents()
            dc.minute = minutes
            return (name: name, threshold: dc)
        }
    }
}
