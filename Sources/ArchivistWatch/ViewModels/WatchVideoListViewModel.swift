#if os(watchOS)
import ArchivistNetworking
import Foundation

@MainActor
@Observable
public final class WatchVideoListViewModel {
    public private(set) var videos: [VideoResponse] = []
    public private(set) var isLoading = false
    public private(set) var isLoadingMore = false
    public private(set) var errorMessage: String?

    public let config: ServerConfig

    @ObservationIgnored private let channelId: String?
    @ObservationIgnored private let service: VideoService
    @ObservationIgnored private let playback: WatchPlaybackServices
    @ObservationIgnored private var paging = WatchPaging()

    /// `channelId` narrows the list to one channel (the channel detail screen).
    public init(
        config: ServerConfig,
        channelId: String? = nil,
        service: VideoService = .liveValue,
        playback: WatchPlaybackServices
    ) {
        self.config = config
        self.channelId = channelId
        self.service = service
        self.playback = playback
    }

    public var isEmpty: Bool {
        videos.isEmpty
    }

    public func viewDidAppear() async {
        guard !paging.hasLoaded else { return }
        await loadFirstPage()
    }

    public func refresh() async {
        await loadFirstPage()
    }

    public func rowAppeared(_ video: VideoResponse) async {
        guard video.id == videos.last?.id,
              !isLoading,
              !isLoadingMore,
              let request = paging.nextPageRequest() else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let response = try await fetch(page: request.page)
            guard paging.accept(response.paginate, for: request) else { return }
            videos.append(contentsOf: response.data.filter { new in !videos.contains { $0.id == new.id } })
        } catch {
            if !Task.isCancelled {
                errorMessage = String(localized: "generic.loadFailed", bundle: .module)
            }
        }
    }

    public func rowModel(for video: VideoResponse) -> WatchVideoRowModel {
        WatchVideoRowModel(
            video: video,
            config: config,
            isDownloaded: playback.catalog.contains(videoId: video.videoId)
        )
    }

    /// The same player for the same video: a navigation destination is rebuilt
    /// every time this screen re-renders, and a new player there would restart
    /// playback and take over the system Now Playing card.
    public func player(for video: VideoResponse) -> WatchAudioPlayerViewModel {
        playback.player(for: video, config: config)
    }

    private func loadFirstPage() async {
        let request = paging.firstPageRequest()
        isLoading = true
        errorMessage = nil
        defer {
            if paging.isCurrent(request) {
                isLoading = false
            }
        }
        do {
            let response = try await fetch(page: 1)
            guard paging.accept(response.paginate, for: request) else { return }
            videos = response.data
        } catch {
            if !Task.isCancelled, paging.isCurrent(request) {
                errorMessage = String(localized: "generic.loadFailed", bundle: .module)
            }
        }
    }

    private func fetch(page: Int) async throws -> PaginatedResponse<VideoResponse> {
        try await service.getVideos(
            config: config,
            page: page,
            sort: "published",
            order: "desc",
            type: nil,
            watch: nil,
            channel: channelId,
            playlist: nil
        )
    }
}
#endif
