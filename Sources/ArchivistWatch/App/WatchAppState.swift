#if os(watchOS)
import ArchivistNetworking
import Foundation

/// Owns the current server configuration and the tab view models built for
/// it. Views receive the view models from here instead of creating them, so
/// a new configuration from the phone replaces every screen's model.
@MainActor
@Observable
public final class WatchAppState {
    public private(set) var tabs: WatchTabsModel?
    public private(set) var isLoading = true

    @ObservationIgnored private let config: WatchAppConfig
    @ObservationIgnored private let playback: WatchPlaybackServices

    public init(
        config: WatchAppConfig,
        playback: WatchPlaybackServices
    ) {
        self.config = config
        self.playback = playback
    }

    public var serverConfig: ServerConfig? {
        tabs?.config
    }

    /// Reads the configuration the phone last sent from the App Group.
    public func loadServerConfig() {
        let stored = UserDefaults(suiteName: config.appGroupSuite)?
            .data(forKey: config.serverConfigKey)
            .flatMap { try? JSONDecoder().decode(ServerConfig.self, from: $0) }
        apply(stored)
        isLoading = false
    }

    /// Adopts `serverConfig`, rebuilding the tabs only when it actually
    /// changed so an unrelated reload keeps every screen's state.
    public func apply(_ serverConfig: ServerConfig?) {
        guard serverConfig != tabs?.config else { return }
        tabs = serverConfig.map { WatchTabsModel(config: $0, playback: playback) }
    }
}
#endif
