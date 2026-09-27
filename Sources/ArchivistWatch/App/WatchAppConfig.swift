#if os(watchOS)
import Foundation

/// Identifiers the watch module needs but must not hardcode: the app target
/// supplies them, so the SPM module carries no bundle-specific strings.
public struct WatchAppConfig: Sendable {
    public let appGroupSuite: String
    public let serverConfigKey: String
    /// Identifier for the background `URLSession` that downloads audio. It
    /// must stay stable across launches so the system can hand finished
    /// downloads back to a relaunched app.
    public let backgroundSessionIdentifier: String

    public init(
        appGroupSuite: String,
        backgroundSessionIdentifier: String,
        serverConfigKey: String = "serverConfig"
    ) {
        self.appGroupSuite = appGroupSuite
        self.backgroundSessionIdentifier = backgroundSessionIdentifier
        self.serverConfigKey = serverConfigKey
    }
}
#endif
