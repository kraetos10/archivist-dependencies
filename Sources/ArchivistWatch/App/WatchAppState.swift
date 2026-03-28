#if os(watchOS)
import ArchivistNetworking
import Foundation

@Observable
public final class WatchAppState {
    public var serverConfig: ServerConfig?
    public var isLoading = true
    public let config: WatchAppConfig

    public init(config: WatchAppConfig) {
        self.config = config
        loadServerConfig()
    }

    public func loadServerConfig() {
        isLoading = true
        defer { isLoading = false }

        guard let defaults = UserDefaults(suiteName: config.appGroupSuite),
              let data = defaults.data(forKey: config.serverConfigKey),
              let decoded = try? JSONDecoder().decode(ServerConfig.self, from: data) else {
            serverConfig = nil
            return
        }

        serverConfig = decoded
    }
}
#endif
