#if os(watchOS)
import ArchivistNetworking
import Foundation

@MainActor
@Observable
public final class WatchPlaylistsViewModel {
    public var playlists: [PlaylistResponse] = []
    public var isLoading = false
    public var isLoadingMore = false
    private var currentPage = 1
    private var lastPage = 1
    public let config: ServerConfig
    private let service: PlaylistService

    public init(
        config: ServerConfig,
        service: PlaylistService = .liveValue
    ) {
        self.config = config
        self.service = service
    }

    public func viewDidAppear() async {
        await loadPlaylists()
    }

    public func refresh() async {
        playlists = []
        currentPage = 1
        lastPage = 1
        await loadPlaylists()
    }

    public func loadNextPageIfNeeded(currentItem: PlaylistResponse) {
        guard currentItem.id == playlists.last?.id else { return }
        loadNextPage()
    }

    // MARK: - Private

    private func loadPlaylists() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await service.getPlaylists(
                config: config,
                page: 1,
                type: nil,
                channel: nil,
                subscribed: nil
            )
            playlists = response.data
            currentPage = response.paginate.currentPage
            lastPage = response.paginate.lastPage
        } catch {}
    }

    private func loadNextPage() {
        guard !isLoadingMore, currentPage < lastPage else { return }
        isLoadingMore = true
        let nextPage = currentPage + 1

        Task {
            defer { isLoadingMore = false }
            do {
                let response = try await service.getPlaylists(
                    config: config,
                    page: nextPage,
                    type: nil,
                    channel: nil,
                    subscribed: nil
                )
                playlists.append(contentsOf: response.data)
                currentPage = response.paginate.currentPage
                lastPage = response.paginate.lastPage
            } catch {}
        }
    }
}
#endif
