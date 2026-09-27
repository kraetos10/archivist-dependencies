#if os(watchOS)
import ArchivistNetworking
import Foundation
import IssueReporting

/// The watch app's long-lived objects, created once by the app delegate and
/// handed down. Replaces the old singletons, so every screen's dependencies
/// are passed in and can be swapped in tests.
@MainActor
public final class WatchEnvironment {
    public let config: WatchAppConfig
    public let appState: WatchAppState
    public let playback: WatchPlaybackServices
    public let sessionManager: WatchSessionManager

    public init(config: WatchAppConfig) {
        self.config = config
        let catalog = WatchDownloadCatalog()
        let storage = WatchAudioStorage()
        let playback = WatchPlaybackServices(
            nowPlaying: WatchNowPlayingState(),
            downloadManager: WatchDownloadManager(
                sessionIdentifier: config.backgroundSessionIdentifier,
                catalog: catalog,
                storage: storage
            ),
            catalog: catalog,
            storage: storage
        )
        self.playback = playback
        self.appState = WatchAppState(config: config, playback: playback)
        self.sessionManager = WatchSessionManager(config: config)
    }

    /// Opens the database, loads the stored configuration and starts
    /// listening to the phone. Synchronous, and called at launch before any
    /// background download events can be delivered, so a download the system
    /// finished while the app was away has a catalog to land in.
    public func launch() {
        withErrorReporting {
            let database = try WatchData.shared.appDatabase()
            playback.catalog.setup(database: database, storage: playback.storage)
        }
        appState.loadServerConfig()
        sessionManager.onConfigChanged = { [appState] config in
            appState.apply(config)
        }
        sessionManager.activate()
    }

    /// Reattaches to the background download session after `launch()`.
    public func reconnectDownloads() async {
        await playback.downloadManager.reconnectBackgroundSession()
    }

    public func handleBackgroundURLSessionEvents(completion: @escaping @MainActor () -> Void) {
        playback.downloadManager.handleBackgroundSessionCompletion(completion)
    }
}
#endif
