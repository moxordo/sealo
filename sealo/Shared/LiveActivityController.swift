import Foundation
import ActivityKit

/// Owns the lifecycle of the `DiveActivityAttributes` Live Activity.
///
/// Called from three places:
/// - Main app: starts a new activity after onboarding and when the
///   app becomes active and no activity is running. Ends it on day
///   rollover.
/// - Monitor extension: updates the running activity on threshold
///   crossings and dive-start events.
/// - (Future) shield-action extension in M5: updates when the user
///   unshields an app.
///
/// All methods are safe to call when no activity is running — the
/// update and end paths are no-ops in that case.
public enum LiveActivityController {

    /// Start a new Live Activity with the given content state. If an
    /// activity of this attribute type is already running, this is
    /// a no-op (call `update` instead). Only works from a process
    /// that declares `NSSupportsLiveActivities` in its Info.plist —
    /// in our project, the main `sealo` app.
    @discardableResult
    public static func start(
        _ contentState: DiveActivityAttributes.ContentState
    ) -> Activity<DiveActivityAttributes>? {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            Log.app.notice("Live Activities disabled in iOS settings; skipping start")
            return nil
        }

        // Skip if one is already running.
        if let existing = Activity<DiveActivityAttributes>.activities.first {
            Log.app.notice("Live Activity already running (id=\(existing.id.prefix(8))); skipping start")
            return existing
        }

        let attributes = DiveActivityAttributes()
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil)
            )
            Log.app.notice("started Live Activity id=\(activity.id.prefix(8))")
            return activity
        } catch {
            Log.app.error("Activity.request failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Update the first running activity's content state. Called
    /// from the monitor extension on every threshold crossing.
    /// Also called from the main app on day rollover and scene-phase
    /// changes so the UI stays fresh.
    public static func update(
        _ contentState: DiveActivityAttributes.ContentState
    ) async {
        for activity in Activity<DiveActivityAttributes>.activities {
            await activity.update(.init(state: contentState, staleDate: nil))
        }
    }

    /// End all running activities. Called on day rollover and when
    /// the user resets the app. `.immediate` dismissal removes them
    /// from the Lock Screen / Dynamic Island instantly instead of
    /// leaving them lingering for the default 4 hours.
    public static func endAll(
        finalState: DiveActivityAttributes.ContentState? = nil
    ) async {
        for activity in Activity<DiveActivityAttributes>.activities {
            if let finalState {
                await activity.end(
                    .init(state: finalState, staleDate: nil),
                    dismissalPolicy: .immediate
                )
            } else {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            Log.app.notice("ended Live Activity id=\(activity.id.prefix(8))")
        }
    }

    /// Whether an activity is currently running. Cheap check used
    /// by the main app to decide whether to start one.
    public static var isRunning: Bool {
        !Activity<DiveActivityAttributes>.activities.isEmpty
    }
}
