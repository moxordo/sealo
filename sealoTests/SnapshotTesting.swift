import XCTest
import SwiftUI
import UIKit

/// Minimal zero-dependency snapshot testing built on Apple's
/// `ImageRenderer`. First run per-test records a baseline PNG into
/// `sealoTests/__Snapshots__/<TestClass>/` and fails with a
/// "recorded new baseline" message; subsequent runs pixel-compare
/// against that baseline.
///
/// **Pixel-exact comparison.** SwiftUI rendering via `ImageRenderer`
/// is deterministic for a given iOS version + size + color scheme,
/// so pixel-exact is the right default. If a failure is intentional
/// (you changed the view on purpose), delete the baseline file and
/// re-run to re-record.
///
/// Why not `swift-snapshot-testing`? SPM / Swift 6.3 / Xcode 26.4
/// module-incompatibility issues. `ImageRenderer` is built-in to
/// SwiftUI since iOS 16 — zero deps, no SPM resolution, no ABI
/// mismatches.

@MainActor
enum SnapshotTesting {

    /// Compare a SwiftUI view render against a committed baseline.
    /// On first run (no baseline exists), records and fails with
    /// "recorded new baseline" so CI catches unreviewed additions.
    static func assertSnapshot<V: View>(
        of view: V,
        as name: String,
        size: CGSize,
        colorScheme: ColorScheme = .light,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let rendered = render(view, size: size, colorScheme: colorScheme) else {
            XCTFail("ImageRenderer produced no UIImage", file: file, line: line)
            return
        }
        guard let renderedPNG = rendered.pngData() else {
            XCTFail("Rendered image has no PNG data", file: file, line: line)
            return
        }

        let baselineURL = baselinePath(
            for: name,
            scheme: colorScheme,
            testFile: file
        )

        // First-run record mode.
        if !FileManager.default.fileExists(atPath: baselineURL.path) {
            try? FileManager.default.createDirectory(
                at: baselineURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            do {
                try renderedPNG.write(to: baselineURL)
                XCTFail(
                    "recorded new baseline at \(baselineURL.path). " +
                    "Review the PNG, then re-run the test.",
                    file: file, line: line
                )
            } catch {
                XCTFail(
                    "failed to write baseline: \(error.localizedDescription)",
                    file: file, line: line
                )
            }
            return
        }

        // Compare against recorded baseline.
        guard let baselineData = try? Data(contentsOf: baselineURL) else {
            XCTFail(
                "could not read baseline at \(baselineURL.path)",
                file: file, line: line
            )
            return
        }

        if renderedPNG != baselineData {
            // Write the failing render alongside for inspection.
            let failedURL = baselineURL
                .deletingPathExtension()
                .appendingPathExtension("failed.png")
            try? renderedPNG.write(to: failedURL)
            XCTFail(
                "snapshot mismatch for '\(name)' [\(schemeTag(colorScheme))]. " +
                "Baseline: \(baselineURL.path). Failing render: \(failedURL.path). " +
                "If the change is intentional, delete the baseline and re-run.",
                file: file, line: line
            )
        }
    }

    // MARK: - Helpers

    private static func render<V: View>(
        _ view: V,
        size: CGSize,
        colorScheme: ColorScheme
    ) -> UIImage? {
        let wrapped = view
            .environment(\.colorScheme, colorScheme)
            .frame(width: size.width, height: size.height)
        let renderer = ImageRenderer(content: wrapped)
        renderer.scale = 2 // @2x — stable across simulator devices
        renderer.proposedSize = ProposedViewSize(size)
        return renderer.uiImage
    }

    private static func baselinePath(
        for name: String,
        scheme: ColorScheme,
        testFile: StaticString
    ) -> URL {
        let tag = schemeTag(scheme)
        let testFileURL = URL(fileURLWithPath: "\(testFile)")
        let testName = testFileURL.deletingPathExtension().lastPathComponent
        return testFileURL
            .deletingLastPathComponent()
            .appendingPathComponent("__Snapshots__")
            .appendingPathComponent(testName)
            .appendingPathComponent("\(name).\(tag).png")
    }

    private static func schemeTag(_ scheme: ColorScheme) -> String {
        scheme == .dark ? "dark" : "light"
    }
}
