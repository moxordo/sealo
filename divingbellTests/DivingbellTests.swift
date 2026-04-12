import XCTest
@testable import divingbell

/// M0 canary. If this target compiles and the test runs, the app module
/// compiles and links. That is the entire promise of this file — real
/// domain tests land in M2 against the reducer.
final class DivingbellTests: XCTestCase {
    func test_appModuleCompilesAndLinks() {
        // Instantiating the App type is enough to prove the module is
        // wired up end-to-end. Kept intentionally trivial.
        _ = DivingbellApp.self
    }
}
