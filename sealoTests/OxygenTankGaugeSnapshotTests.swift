import XCTest
import SwiftUI
@testable import sealo

/// Pixel-diff snapshot tests for `OxygenTankGauge`.
///
/// Covers the gauge at every fill level we care about (0, 25, 50,
/// 75, 100 %) across the size range where it's actually used —
/// Dynamic Island minimal (~18 pt), compact (~22 pt), widget small
/// (~120 pt), Lock Screen card (~72 pt), dashboard hero (~260 pt) —
/// in both light and dark color schemes.
///
/// First run per test records a baseline PNG in
/// `sealoTests/__Snapshots__/`. Subsequent runs pixel-diff against
/// it. Intentional visual changes require deleting the baseline and
/// re-running.
///
/// Replaces the M0 `OxygenTankGaugeRenderTests` — snapshot tests
/// subsume the "does it render without crashing" assertion while
/// also catching visual regressions.
@MainActor
final class OxygenTankGaugeSnapshotTests: XCTestCase {

    // MARK: - Fill levels at the canonical dashboard size

    func test_gauge_fill_0_light() {
        SnapshotTesting.assertSnapshot(
            of: OxygenTankGauge(fill: 0.0),
            as: "gauge-dashboard-fill000",
            size: CGSize(width: 260, height: 120),
            colorScheme: .light
        )
    }

    func test_gauge_fill_25_light() {
        SnapshotTesting.assertSnapshot(
            of: OxygenTankGauge(fill: 0.25),
            as: "gauge-dashboard-fill025",
            size: CGSize(width: 260, height: 120),
            colorScheme: .light
        )
    }

    func test_gauge_fill_50_light() {
        SnapshotTesting.assertSnapshot(
            of: OxygenTankGauge(fill: 0.5),
            as: "gauge-dashboard-fill050",
            size: CGSize(width: 260, height: 120),
            colorScheme: .light
        )
    }

    func test_gauge_fill_75_light() {
        SnapshotTesting.assertSnapshot(
            of: OxygenTankGauge(fill: 0.75),
            as: "gauge-dashboard-fill075",
            size: CGSize(width: 260, height: 120),
            colorScheme: .light
        )
    }

    func test_gauge_fill_100_light() {
        SnapshotTesting.assertSnapshot(
            of: OxygenTankGauge(fill: 1.0),
            as: "gauge-dashboard-fill100",
            size: CGSize(width: 260, height: 120),
            colorScheme: .light
        )
    }

    // MARK: - Dark-mode spot checks

    func test_gauge_fill_50_dark() {
        SnapshotTesting.assertSnapshot(
            of: OxygenTankGauge(fill: 0.5),
            as: "gauge-dashboard-fill050",
            size: CGSize(width: 260, height: 120),
            colorScheme: .dark
        )
    }

    func test_gauge_fill_0_dark() {
        SnapshotTesting.assertSnapshot(
            of: OxygenTankGauge(fill: 0.0),
            as: "gauge-dashboard-fill000",
            size: CGSize(width: 260, height: 120),
            colorScheme: .dark
        )
    }

    // MARK: - Size-scaling invariant

    func test_gauge_dynamicIslandMinimal() {
        SnapshotTesting.assertSnapshot(
            of: OxygenTankGauge(fill: 0.67),
            as: "gauge-dynamic-island-minimal",
            size: CGSize(width: 18, height: 10),
            colorScheme: .light
        )
    }

    func test_gauge_dynamicIslandCompactLeading() {
        SnapshotTesting.assertSnapshot(
            of: OxygenTankGauge(fill: 0.67),
            as: "gauge-dynamic-island-compact",
            size: CGSize(width: 22, height: 12),
            colorScheme: .light
        )
    }

    func test_gauge_widgetSmall() {
        SnapshotTesting.assertSnapshot(
            of: OxygenTankGauge(fill: 0.67),
            as: "gauge-widget-small",
            size: CGSize(width: 120, height: 28),
            colorScheme: .light
        )
    }

    func test_gauge_lockScreenCard() {
        SnapshotTesting.assertSnapshot(
            of: OxygenTankGauge(fill: 0.67),
            as: "gauge-lock-screen",
            size: CGSize(width: 72, height: 32),
            colorScheme: .light
        )
    }

    // MARK: - Out-of-range clamp sanity

    func test_gauge_clamp_negative() {
        SnapshotTesting.assertSnapshot(
            of: OxygenTankGauge(fill: -0.5),
            as: "gauge-clamp-negative",
            size: CGSize(width: 260, height: 120),
            colorScheme: .light
        )
    }

    func test_gauge_clamp_over_one() {
        SnapshotTesting.assertSnapshot(
            of: OxygenTankGauge(fill: 1.5),
            as: "gauge-clamp-over-one",
            size: CGSize(width: 260, height: 120),
            colorScheme: .light
        )
    }
}
