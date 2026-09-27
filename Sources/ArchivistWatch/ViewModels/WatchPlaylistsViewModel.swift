#if os(watchOS)
import ArchivistNetworking
import Foundation

@MainActor
@Observable
public final class WatchPlaylistsViewModel {
    public private(set) var playlists: [PlaylistResponse] = []
    public private(set) var isLoading = false
    public private(set) var isLoadingMore = false
    public private(set) var errorMessage: String?

    public let config: ServerConfig

    @ObservationIgnored private let service: PlaylistService
    @ObservationIgnored private let playback: WatchPlaybackServices
    @ObservationIgnored private var paging = WatchPaging()
    @ObservationIgnored private var detail: (playlistId: String, viewModel: WatchPlaylistDetailViewModel)?

    public init(
        config: ServerConfig,
        service: PlaylistService = .liveValue,
        playback: WatchPlaybackServices
    ) {
        self.config = config
        self.service = service
        self.playback = playback
    }

    public func viewDidAppear() async {
        guard !paging.hasLoaded else { return }
        await loadFirstPage()
    }

    public func refresh() async {
        await loadFirstPage()
    }

    public func rowAppeared(_ playlist: PlaylistResponse) async {
        guard playlist.id == playlists.last?.id,
              !isLoading,
              !isLoadingMore,
              let request = paging.nextPageRequest() else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let response = try await fetch(page: request.page)
            guard paging.accept(response.paginate, for: request) else { return }
            playlists.append(contentsOf: response.data.filter { new in !playlists.contains { $0.id == new.id } })
        } catch {
            if !Task.isCancelled {
                errorMessage = String(localized: "generic.loadFailed", bundle: .module)
            }
        }
    }

    public func thumbnailURL(for playlist: PlaylistResponse) -> URL? {
        playlist.playlistThumbnail.flatMap(config.fullURL(for:))
    }

    public func videoCountText(for playlist: PlaylistResponse) -> String {
        String(localized: "playlist.videoCount \(playlist.entryCount)", bundle: .module)
    }

    /// Reused for the same playlist, since the destination is rebuilt on every
    /// render and a fresh view model would reload.
    public func detailViewModel(for playlist: PlaylistResponse) -> WatchPlaylistDetailViewModel {
        if let detail, detail.playlistId == playlist.playlistId {
            return detail.viewModel
        }
        let viewModel = WatchPlaylistDetailViewModel(
            config: config,
            playlistId: playlist.playlistId,
            service: service,
            playback: playback
        )
        detail = (playlist.playlistId, viewModel)
        return viewModel
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
            playlists = response.data
        } catch {
            if !Task.isCancelled, paging.isCurrent(request) {
                errorMessage = String(localized: "generic.loadFailed", bundle: .module)
            }
        }
    }

    private func fetch(page: Int) async throws -> PaginatedResponse<PlaylistResponse> {
        try await service.getPlaylists(
            config: config,
            page: page,
            type: nil,
            channel: nil,
            subscribed: nil
        )
    }
}
#endif
