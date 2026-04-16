import ActivityKit
import SwiftUI
import WidgetKit

/// ActivityKit configuration for the Sealo dive Live Activity.
///
/// Renders three Dynamic Island presentations (minimal, compact,
/// expanded) plus the Lock Screen card. All four states reuse the
/// same `OxygenTankGauge` SwiftUI view, sized differently —
/// honoring `D5`'s "battery silhouette at every scale" invariant.
///
/// Per `D3`, no `Button(intent:)` controls; the whole activity is
/// a `widgetURL` deep-link into the main app.
public struct SealoLiveActivity: Widget {

    public init() {}

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: DiveActivityAttributes.self) { context in
            // Lock Screen / notification center card.
            LockScreenDiveView(state: context.state)
                .widgetURL(URL(string: "sealo://dive/current"))
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded — shown when user long-presses or the system
                // auto-reveals (e.g., on dive start).
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedBatteryRegion(state: context.state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    // Intentionally empty — the leading region is
                    // full-width visually. Keeping this slot empty
                    // matches the Appendix A mockup.
                    Color.clear
                }
                DynamicIslandExpandedRegion(.center) {
                    ExpandedCenterRegion(state: context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomRegion()
                }
            } compactLeading: {
                CompactLeadingView(state: context.state)
            } compactTrailing: {
                CompactTrailingView(state: context.state)
            } minimal: {
                MinimalView(state: context.state)
            }
            .widgetURL(URL(string: "sealo://dive/current"))
            .keylineTint(.teal)
        }
    }
}

// MARK: - Dynamic Island compact

private struct CompactLeadingView: View {
    let state: DiveActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 4) {
            OxygenTankGauge(fill: state.fillFraction)
                .frame(width: 22, height: 12)
            Text("\(Int((state.fillFraction * 100).rounded()))%")
                .font(.caption2.weight(.semibold).monospacedDigit())
                .foregroundStyle(Color(red: 27/255, green: 168/255, blue: 154/255))
        }
    }
}

private struct CompactTrailingView: View {
    let state: DiveActivityAttributes.ContentState

    var body: some View {
        // Text(timerInterval:) is the magic that lets iOS advance the
        // mm:ss display every second WITHOUT waking our extension.
        Text(timerInterval: state.diveStartedAt...Date.distantFuture,
             countsDown: false,
             showsHours: false)
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 50)
    }
}

private struct MinimalView: View {
    let state: DiveActivityAttributes.ContentState

    var body: some View {
        OxygenTankGauge(fill: state.fillFraction)
            .frame(width: 18, height: 10)
            .opacity(lowO2Pulse ? 0.6 : 1.0)
            .animation(
                lowO2Pulse
                    ? .easeInOut(duration: 1).repeatForever(autoreverses: true)
                    : .default,
                value: lowO2Pulse
            )
    }

    private var lowO2Pulse: Bool {
        state.fillFraction < 0.15 || state.isShieldArmed
    }
}

// MARK: - Dynamic Island expanded

private struct ExpandedBatteryRegion: View {
    let state: DiveActivityAttributes.ContentState

    var body: some View {
        HStack {
            OxygenTankGauge(fill: state.fillFraction)
                .frame(height: 32)
            Text("\(Int((state.fillFraction * 100).rounded()))%")
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(Color(red: 27/255, green: 168/255, blue: 154/255))
        }
        .padding(.leading, 8)
    }
}

private struct ExpandedCenterRegion: View {
    let state: DiveActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text("DIVE #\(state.diveNumber)")
                    .font(.caption.weight(.semibold))
                Text("of \(state.maxDives)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("·")
                    .foregroundStyle(.secondary)
                Text("\(Int(state.minutesRemaining)) min left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                Text(timerInterval: state.diveStartedAt...Date.distantFuture,
                     countsDown: false,
                     showsHours: false)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .leading)

                DiveDotsView(
                    completed: state.diveNumber,
                    total: state.maxDives
                )
            }
        }
    }
}

private struct ExpandedBottomRegion: View {
    var body: some View {
        HStack {
            Spacer()
            Text("Tap to open Sealo")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Image(systemName: "arrow.up.right.square")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.top, 2)
    }
}

// MARK: - Lock Screen card

private struct LockScreenDiveView: View {
    let state: DiveActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            OxygenTankGauge(fill: state.fillFraction)
                .frame(width: 72, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("Dive #\(state.diveNumber)")
                        .font(.subheadline.weight(.semibold))
                    Text("of \(state.maxDives)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Text(timerInterval: state.diveStartedAt...Date.distantFuture,
                         countsDown: false,
                         showsHours: false)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text("\(Int(state.minutesRemaining)) min left today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                DiveDotsView(
                    completed: state.diveNumber,
                    total: state.maxDives
                )
                .padding(.top, 2)
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Shared: dive-count dots (◎ ◎ ◎ ○ ○ ○)

private struct DiveDotsView: View {
    let completed: Int
    let total: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<max(total, 1), id: \.self) { index in
                Circle()
                    .fill(dotStyle(for: index))
                    .frame(width: 6, height: 6)
            }
        }
    }

    private func dotStyle(for index: Int) -> Color {
        if index < completed - 1 {
            // Past dives — filled teal.
            return Color(red: 27/255, green: 168/255, blue: 154/255)
        } else if index == completed - 1 {
            // Current dive — mid-teal (UI will pulse via opacity
            // modifier from the enclosing view if needed).
            return Color(red: 27/255, green: 168/255, blue: 154/255)
                .opacity(0.7)
        } else {
            // Budgeted but not yet used.
            return Color.secondary.opacity(0.3)
        }
    }
}
