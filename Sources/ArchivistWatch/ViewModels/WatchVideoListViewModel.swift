#if os(watchOS)
import ArchivistNetworking
import Foundation

@MainActor
@Observable
public final class WatchVideoListViewModel {
    public var videos: [VideoResponse] = []
    public var isLoading = false
    public var isLoadingMore = false
    private var currentPage = 1
    private var lastPage = 1
    public let config: ServerConfig
    private let service: VideoService

    public init(
        config: ServerConfig,
        service: VideoService = .liveValue
    ) {
        self.config = config
        self.service = service
    }

    public func viewDidAppear() async {
        await loadVideos()
    }

    public func refresh() async {
        videos = []
        currentPage = 1
        lastPage = 1
        await loadVideos()
    }

    public func loadNextPageIfNeeded(currentItem: VideoResponse) {
        guard currentItem.id == videos.last?.id else { return }
        loadNextPage()
    }

    // MARK: - Private

    private func loadVideos() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await service.getVideos(
                config: config,
                page: 1,
                sort: "published",
                order: "desc",
                type: nil,
                watch: nil,
                channel: nil,
                playlist: nil
            )
            videos = response.data
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
                let response = try await service.getVideos(
                    config: config,
                    page: nextPage,
                    sort: "published",
                    order: "desc",
                    type: nil,
                    watch: nil,
                    channel: nil,
                    playlist: nil
                )
                videos.append(contentsOf: response.data)
                currentPage = response.paginate.currentPage
                lastPage = response.paginate.lastPage
            } catch {}
        }
    }
}
#endif
