#if os(watchOS)
import ArchivistNetworking
import Foundation

/// Everything a player needs, bundled so the list view models can hand it on
/// without each one reaching for singletons. Tests build it from their own
/// catalog, storage and stubbed `VideoService`.
public struct WatchPlaybackServices: Sendable {
    public let nowPlaying: WatchNowPlayingState
    public let downloadManager: WatchDownloadManager
    public let catalog: WatchDownloadCatalog
    public let storage: WatchAudioStorage
    public let videoService: VideoService

    public init(
        nowPlaying: WatchNowPlayingState,
        downloadManager: WatchDownloadManager,
        catalog: WatchDownloadCatalog,
        storage: WatchAudioStorage,
        videoService: VideoService = .liveValue
    ) {
        self.nowPlaying = nowPlaying
        self.downloadManager = downloadManager
        self.catalog = catalog
        self.storage = storage
        self.videoService = videoService
    }

    /// The shared streaming player for a server video.
    @MainActor
    public func player(
        forVideoId videoId: String,
        title: String,
        channelName: String,
        thumbPath: String?,
        video: VideoResponse?,
        config: ServerConfig
    ) -> WatchAudioPlayerViewModel {
        nowPlaying.player(for: videoId) {
            WatchAudioPlayerViewModel(
                videoId: videoId,
                title: title,
                channelName: channelName,
                thumbPath: thumbPath,
                video: video,
                serverConfig: config,
                services: self
            )
        }
    }

    /// The shared player for a downloaded file, resuming from its saved spot.
    @MainActor
    public func player(
        for record: WatchDownload,
        config: ServerConfig
    ) -> WatchAudioPlayerViewModel {
        nowPlaying.player(for: record.id) {
            WatchAudioPlayerViewModel(
                record: record,
                fileURL: storage.localFileURL(for: record.id),
                serverConfig: config,
                services: self
            )
        }
    }

    @MainActor
    public func player(
        for video: VideoResponse,
        config: ServerConfig
    ) -> WatchAudioPlayerViewModel {
        player(
            forVideoId: video.videoId,
            title: video.title,
            channelName: video.channelName,
            thumbPath: video.vidThumbUrl,
            video: video,
            config: config
        )
    }
}
#endif
