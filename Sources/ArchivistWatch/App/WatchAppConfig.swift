#if os(watchOS)
import Foundation

public struct WatchAppConfig: Sendable {
    public let appGroupSuite: String
    public let serverConfigKey: String

    public init(
        appGroupSuite: String,
        serverConfigKey: String = "serverConfig"
    ) {
        self.appGroupSuite = appGroupSuite
        self.serverConfigKey = serverConfigKey
    }
}
#endif
