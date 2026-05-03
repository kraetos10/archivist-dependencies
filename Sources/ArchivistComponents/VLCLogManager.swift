#if os(iOS) || os(tvOS)
import Foundation
import VLCKit

/// Routes libvlc log output to a rolling file the user can export from
/// Settings. Always-on so we never need to ask the user to "reproduce
/// while logging is enabled" — the last few MB of playback context is
/// already on disk by the time they hit a problem.
@MainActor
public final class VLCLogManager {
    public static let shared = VLCLogManager()

    /// Cap so the log doesn't grow unboundedly on heavy users. Truncated
    /// at process start when the existing file exceeds this — we keep
    /// the tail rather than the head because the most recent activity
    /// is what matters for diagnosing a fresh complaint.
    private static let maxLogBytes: UInt64 = 5 * 1_024 * 1_024

    private var fileLogger: VLCFileLogger?
    private var fileHandle: FileHandle?

    public var logFileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("vlc.log")
    }

    public var hasLogs: Bool {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: logFileURL.path),
              let size = attrs[.size] as? UInt64 else { return false }
        return size > 0
    }

    private init() {}

    /// Wires `VLCFileLogger` onto `VLCLibrary.sharedLibrary`. Call once
    /// at app launch — re-calls reset the file handle and reattach.
    public func start() {
        let url = logFileURL
        truncateIfOversized(url: url)

        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }

        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        // Append to existing content rather than overwriting.
        try? handle.seekToEnd()

        let logger = VLCFileLogger(fileHandle: handle)
        // Info-level: errors + warnings + the general module messages
        // that surface buffering/decoder problems. Debug is far too
        // noisy for a user-facing always-on log.
        logger.level = .info

        fileHandle = handle
        fileLogger = logger
        VLCLibrary.shared().loggers = [logger]
    }

    /// Clears the log on disk and rewires the logger so subsequent
    /// playback writes start fresh.
    public func clearLogs() {
        try? fileHandle?.close()
        fileHandle = nil
        fileLogger = nil
        VLCLibrary.shared().loggers = nil
        try? FileManager.default.removeItem(at: logFileURL)
        start()
    }

    private func truncateIfOversized(url: URL) {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? UInt64,
              size > Self.maxLogBytes else { return }
        // Drop everything but the last `maxLogBytes` so freshly-reported
        // problems aren't buried under months-old startup chatter.
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        defer { try? handle.close() }
        let offset = size - Self.maxLogBytes
        try? handle.seek(toOffset: offset)
        let tail = handle.availableData
        try? tail.write(to: url, options: .atomic)
    }
}
#endif
