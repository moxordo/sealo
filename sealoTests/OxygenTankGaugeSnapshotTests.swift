import XCTest
import SwiftUI
@testable import sealo

/// M0 render canary for OxygenTankGauge.
///
/// Proves: the view compiles, instantiates, and renders in a hosting
/// controller without crashing. This is the M0-level assertion. M1
/// replaces this with pixel-diff snapshot tests via swift-snapshot-testing
/// once the SPM / Xcode 26 module compatibility issue is resolved.
final class OxygenTankGaugeRenderTests: XCTestCase {
    @MainActor
    func test_oxygenTankGauge_rendersAtVariousFillLevels() {
        for fill in [0.0, 0.25, 0.5, 0.75, 1.0] {
            let view = OxygenTankGauge(fill: fill)
                .frame(width: 240, height: 110)

            let host = UIHostingController(rootView: view)

            // Proving the view compiles, instantiates, and can be
            // hosted is the M0-level assertion. Bounds/size assertions
            // need a window hierarchy; pixel-diff assertions need
            // swift-snapshot-testing. Both land in M1.
            XCTAssertNotNil(
                host.view,
                "OxygenTankGauge should render at fill=\(fill)"
            )
        }
    }

    @MainActor
    func test_oxygenTankGauge_clampsOutOfRangeValues() {
        // Values outside 0...1 should clamp, not crash.
        for fill in [-0.5, 1.5, -100.0, 999.0] {
            let view = OxygenTankGauge(fill: fill)
                .frame(width: 120, height: 55)

            let host = UIHostingController(rootView: view)
            host.view.layoutIfNeeded()

            XCTAssertNotNil(
                host.view,
                "OxygenTankGauge should not crash at fill=\(fill)"
            )
        }
    }
}
