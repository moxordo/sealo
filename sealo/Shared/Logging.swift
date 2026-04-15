import Foundation
import os

/// Centralised logging. Every call goes to BOTH:
///   1. `os_log` / `Logger` — visible in Console.app for live tail
///   2. `FileLogger` — JSONL appended to the App Group shared file,
///      pulled off the device via `scripts/pull-logs.sh` for
///      post-hoc inspection without Console.app
///
/// The dual-write means developers can tail live logs when needed
/// and also scrape a full session's events into a file for the
/// agent to read. Prefer the categories defined here over
/// ad-hoc `Logger` instances so everything flows through both sinks.
public enum Log {
    private static let subsystem = "com.moxordo.sealo"

    public static let app     = Channel(category: "app")
    public static let service = Channel(category: "service")
    public static let monitor = Channel(category: "monitor")
    public static let shared  = Channel(category: "shared")

    public struct Channel: Sendable {
        public let category: String
        private let osLogger: Logger

        init(category: String) {
            self.category = category
            self.osLogger = Logger(subsystem: Log.subsystem, category: category)
        }

        /// Source identifier for the FileLogger. "app" for the main
        /// app, "monitor" for the extension. Derived from a
        /// process-env variable set at init; defaults to the binary
        /// name if not set.
        private var source: String {
            #if MONITOR_EXTENSION
            return "monitor"
            #else
            return "app"
            #endif
        }

        public func notice(_ message: String, fields: [String: String] = [:]) {
            osLogger.notice("\(message, privacy: .public)")
            FileLogger.append(
                source: source, category: category,
                level: "notice", message: message, fields: fields
            )
        }

        public func info(_ message: String, fields: [String: String] = [:]) {
            osLogger.info("\(message, privacy: .public)")
            FileLogger.append(
                source: source, category: category,
                level: "info", message: message, fields: fields
            )
        }

        public func error(_ message: String, fields: [String: String] = [:]) {
            osLogger.error("\(message, privacy: .public)")
            FileLogger.append(
                source: source, category: category,
                level: "error", message: message, fields: fields
            )
        }
    }
}
