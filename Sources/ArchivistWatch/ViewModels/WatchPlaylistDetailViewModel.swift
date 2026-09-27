#if os(watchOS)
import ArchivistNetworking
import Foundation

@MainActor
@Observable
public final class WatchPlaylistDetailViewModel {
    public private(set) var entries: [PlaylistEntry] = []
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    public let config: ServerConfig

    @ObservationIgnored private let playlistId: String
    @ObservationIgnored private let service: PlaylistService
    @ObservationIgnored private let playback: WatchPlaybackServices
    @ObservationIgnored private var hasLoaded = false
    @ObservationIgnored private var generation = 0

    public init(
        config: ServerConfig,
        playlistId: String,
        service: PlaylistService = .liveValue,
        playback: WatchPlaybackServices
    ) {
        self.config = config
        self.playlistId = playlistId
        self.service = service
        self.playback = playback
    }

    /// Entries that can be played — an entry without a video id has nothing
    /// to open.
    public var playableEntries: [PlaylistEntry] {
        entries.filter { $0.youtubeId != nil }
    }

    public func viewDidAppear() async {
        guard !hasLoaded else { return }
        await load()
    }

    public func refresh() async {
        await load()
    }

    public func rowModel(for entry: PlaylistEntry) -> WatchVideoRowModel {
        WatchVideoRowModel(
            title: entry.title ?? String(localized: "generic.unknown", bundle: .module),
            thumbnailURL: entry.thumbURL(config: config),
            isWatched: false,
            isDownloaded: entry.youtubeId.map { playback.catalog.contains(videoId: $0) } ?? false,
            watchProgress: 0,
            subtitle: entry.uploader
        )
    }

    /// The entry carries no media URL; the player fetches the full video when
    /// it first loads.
    public func player(for entry: PlaylistEntry) -> WatchAudioPlayerViewModel? {
        guard let videoId = entry.youtubeId else { return nil }
        return playback.player(
            forVideoId: videoId,
            title: entry.title ?? String(localized: "generic.unknown", bundle: .module),
            channelName: entry.uploader ?? "",
            thumbPath: entry.vidThumbUrl,
            video: nil,
            config: config
        )
    }

    private func load() async {
        generation += 1
        let current = generation
        isLoading = true
        errorMessage = nil
        defer {
            if current == generation {
                isLoading = false
            }
        }
        do {
            let playlist = try await service.getPlaylist(
                config: config,
                id: playlistId
            )
            guard current == generation else { return }
            entries = playlist.playlistEntries ?? []
            hasLoaded = true
        } catch {
            if !Task.isCancelled, current == generation {
                errorMessage = String(localized: "generic.loadFailed", bundle: .module)
            }
        }
    }
}
#endif
