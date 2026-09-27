#if os(watchOS)
import ArchivistNetworking
import Foundation

/// The tab screens' view models for one server configuration. Rebuilt as a
/// whole when the configuration changes, so no screen keeps talking to the
/// old server or token.
@MainActor
@Observable
public final class WatchTabsModel {
    public let config: ServerConfig
    public let nowPlaying: WatchNowPlayingState
    public let downloads: WatchDownloadsViewModel
    public let videos: WatchVideoListViewModel
    public let channels: WatchChannelsViewModel
    public let playlists: WatchPlaylistsViewModel
    public let queue: WatchServerQueueViewModel

    public init(
        config: ServerConfig,
        playback: WatchPlaybackServices
    ) {
        self.config = config
        self.nowPlaying = playback.nowPlaying
        self.downloads = WatchDownloadsViewModel(config: config, playback: playback)
        self.videos = WatchVideoListViewModel(config: config, playback: playback)
        self.channels = WatchChannelsViewModel(config: config, playback: playback)
        self.playlists = WatchPlaylistsViewModel(config: config, playback: playback)
        self.queue = WatchServerQueueViewModel(config: config)
    }
}
#endif
