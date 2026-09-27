import ArchivistComponents
import ComposableArchitecture
import Foundation

/// The libvlc playback log the user can export from Settings.
public struct DiagnosticsLogClient: Sendable {
    /// The log file, or `nil` when there's nothing in it to share.
    public var logFileURL: @MainActor @Sendable () -> URL?
    /// Empties the log and starts a fresh one.
    public var clear: @MainActor @Sendable () -> Void

    public init(
        logFileURL: @escaping @MainActor @Sendable () -> URL?,
        clear: @escaping @MainActor @Sendable () -> Void
    ) {
        self.logFileURL = logFileURL
        self.clear = clear
    }
}

extension DiagnosticsLogClient: DependencyKey {
    public static var liveValue: DiagnosticsLogClient {
        #if os(iOS) || os(tvOS)
        DiagnosticsLogClient(
            logFileURL: {
                let manager = VLCLogManager.shared
                return manager.hasLogs ? manager.logFileURL : nil
            },
            clear: { VLCLogManager.shared.clearLogs() }
        )
        #else
        .empty
        #endif
    }

    public static var testValue: DiagnosticsLogClient {
        DiagnosticsLogClient(
            logFileURL: {
                reportIssue("Unimplemented: 'DiagnosticsLogClient.logFileURL'")
                return nil
            },
            clear: { reportIssue("Unimplemented: 'DiagnosticsLogClient.clear'") }
        )
    }

    public static var previewValue: DiagnosticsLogClient { .empty }

    /// No logs, and clearing does nothing.
    public static var empty: DiagnosticsLogClient {
        DiagnosticsLogClient(logFileURL: { nil }, clear: {})
    }
}

extension DependencyValues {
    public var diagnosticsLog: DiagnosticsLogClient {
        get { self[DiagnosticsLogClient.self] }
        set { self[DiagnosticsLogClient.self] = newValue }
    }
}
