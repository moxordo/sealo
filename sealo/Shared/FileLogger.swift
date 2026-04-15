import Foundation

/// Append-only JSONL logger that writes to the App Group shared
/// container. Both the main app and the `sealoMonitor` extension
/// write to the same file — POSIX `O_APPEND` writes under
/// `PIPE_BUF` (512 bytes) are atomic, and JSON lines are typically
/// well under that, so concurrent appends from two processes
/// interleave cleanly without locking.
///
/// The log file lives at
/// `<AppGroup>/sealo-events.log` and is pulled off the device via
/// `scripts/pull-logs.sh` for inspection without touching Console.app.
public enum FileLogger {
    private static let appGroupID = SharedDefaults.suiteName
    private static let fileName = "sealo-events.log"

    /// Bytes beyond which we rotate the log (10 MB). Prevents
    /// unbounded growth on long test sessions.
    private static let maxBytes: Int = 10 * 1024 * 1024

    private static var logURL: URL? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else { return nil }
        return container.appendingPathComponent(fileName)
    }

    /// Append one structured log entry. `source` identifies the
    /// process ("app" or "monitor") so interleaved entries stay
    /// readable.
    public static func append(
        source: String,
        category: String,
        level: String,
        message: String,
        fields: [String: String] = [:]
    ) {
        guard let url = logURL else { return }

        var entry: [String: Any] = [
            "t": ISO8601DateFormatter().string(from: Date()),
            "src": source,
            "cat": category,
            "lvl": level,
            "msg": message,
        ]
        for (k, v) in fields { entry[k] = v }

        guard let data = try? JSONSerialization.data(
            withJSONObject: entry, options: []
        ) else { return }

        // Rotate if needed (truncate file once it gets too big).
        rotateIfNeeded(at: url)

        var line = data
        line.append(0x0A) // newline

        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: line)
            return
        }

        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            try? handle.seekToEnd()
            try? handle.write(contentsOf: line)
        }
    }

    private static func rotateIfNeeded(at url: URL) {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int,
              size > maxBytes
        else { return }
        // Simple rotate: move current to .prev and start fresh.
        let prev = url.deletingLastPathComponent()
            .appendingPathComponent(fileName + ".prev")
        try? FileManager.default.removeItem(at: prev)
        try? FileManager.default.moveItem(at: url, to: prev)
    }

    /// Best-effort wipe — called by the "Reset" debug action or
    /// from tests.
    public static func clear() {
        guard let url = logURL else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
