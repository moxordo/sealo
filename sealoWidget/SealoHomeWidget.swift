import WidgetKit
import SwiftUI

/// Home-screen widget showing the current O₂ tank.
///
/// Unlike the Live Activity (which is push-updated by ActivityKit),
/// home widgets are read-only snapshots iOS refreshes on a timeline.
/// We give it entries at 15-minute intervals, well within Apple's
/// ~40-70 refreshes/day budget.
///
/// Timeline entries read from `SharedDefaults` — the same data the
/// monitor extension writes when thresholds fire.
public struct SealoHomeWidget: Widget {
    public let kind = "com.moxordo.sealo.homewidget"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            SealoHomeWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Sealo")
        .description("Your oxygen tank for the day")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Timeline provider

struct SealoHomeWidgetEntry: TimelineEntry {
    let date: Date
    let fillFraction: Double
    let consumedDives: Int
    let maxDives: Int
    let minutesRemaining: Double
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SealoHomeWidgetEntry {
        SealoHomeWidgetEntry(
            date: Date(),
            fillFraction: 1.0,
            consumedDives: 0,
            maxDives: 6,
            minutesRemaining: 60
        )
    }

    func getSnapshot(in context: Context,
                     completion: @escaping (SealoHomeWidgetEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context,
                     completion: @escaping (Timeline<SealoHomeWidgetEntry>) -> Void) {
        // Single entry at the current time; iOS will call us again
        // after .after(next refresh). 15-minute cadence keeps us well
        // under Apple's ~40-70 refreshes/day limit.
        let entry = currentEntry()
        let next = Date().addingTimeInterval(15 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func currentEntry() -> SealoHomeWidgetEntry {
        guard let budget = SharedDefaults.loadDailyBudget() else {
            return SealoHomeWidgetEntry(
                date: Date(),
                fillFraction: 1.0,
                consumedDives: 0,
                maxDives: 6,
                minutesRemaining: 60
            )
        }
        return SealoHomeWidgetEntry(
            date: Date(),
            fillFraction: budget.fillFraction,
            consumedDives: budget.consumedDives,
            maxDives: budget.maxDives,
            minutesRemaining: budget.remainingMinutes
        )
    }
}

// MARK: - View

struct SealoHomeWidgetView: View {
    let entry: SealoHomeWidgetEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallView(entry: entry)
        case .systemMedium:
            MediumView(entry: entry)
        default:
            SmallView(entry: entry)
        }
    }
}

private struct SmallView: View {
    let entry: SealoHomeWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sealo")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            OxygenTankGauge(fill: entry.fillFraction)
                .frame(height: 28)

            HStack(spacing: 4) {
                Text("\(Int((entry.fillFraction * 100).rounded()))%")
                    .font(.title2.weight(.semibold).monospacedDigit())
                Text("O₂")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Text("\(entry.consumedDives)/\(entry.maxDives) dives")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

private struct MediumView: View {
    let entry: SealoHomeWidgetEntry

    var body: some View {
        HStack(spacing: 16) {
            OxygenTankGauge(fill: entry.fillFraction)
                .frame(width: 120, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text("Sealo")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text("\(Int((entry.fillFraction * 100).rounded()))% O₂")
                    .font(.title2.weight(.semibold).monospacedDigit())

                Text("\(entry.consumedDives)/\(entry.maxDives) dives · \(Int(entry.minutesRemaining)) min left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
    }
}
