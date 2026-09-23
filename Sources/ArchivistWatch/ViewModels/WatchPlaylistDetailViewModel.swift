#if os(watchOS)
import ArchivistNetworking
import Foundation

@MainActor
@Observable
public final class WatchPlaylistDetailViewModel {
    public var entries: [PlaylistEntry] = []
    public var isLoading = false
    public var loadedVideo: VideoResponse?
    public var isLoadingVideo = false
    public let config: ServerConfig
    private let playlistId: String
    private let service: PlaylistService
    private let videoService: VideoService

    public init(
        config: ServerConfig,
        playlistId: String,
        service: PlaylistService = .liveValue,
        videoService: VideoService = .liveValue
    ) {
        self.config = config
        self.playlistId = playlistId
        self.service = service
        self.videoService = videoService
    }

    public func viewDidAppear() async {
        await loadEntries()
    }

    public func refresh() async {
        entries = []
        await loadEntries()
    }

    public func playEntry(_ entry: PlaylistEntry) {
        guard let videoId = entry.youtubeId, !isLoadingVideo else { return }
        isLoadingVideo = true

        Task {
            do {
                loadedVideo = try await videoService.getVideo(
                    config: config,
                    id: videoId
                )
            } catch {}
            isLoadingVideo = false
        }
    }

    /// The same player for the same video: a navigation destination is rebuilt
    /// every time this screen re-renders, and a new player there would restart
    /// playback and take over the system Now Playing card.
    public func player(for video: VideoResponse) -> WatchAudioPlayerViewModel {
        WatchNowPlayingState.shared.player(for: video.videoId) {
            WatchAudioPlayerViewModel(video: video, serverConfig: config)
        }
    }

    // MARK: - Private

    private func loadEntries() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let playlist = try await service.getPlaylist(
                config: config,
                id: playlistId
            )
            entries = playlist.playlistEntries ?? []
        } catch {}
    }
}
#endif
