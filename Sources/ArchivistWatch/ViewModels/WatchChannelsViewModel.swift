#if os(watchOS)
import ArchivistNetworking
import Foundation

@MainActor
@Observable
public final class WatchChannelsViewModel {
    public var channels: [ChannelResponse] = []
    public var isLoading = false
    public var isLoadingMore = false
    private var currentPage = 1
    private var lastPage = 1
    public let config: ServerConfig
    private let service: ChannelService

    public init(
        config: ServerConfig,
        service: ChannelService = .liveValue
    ) {
        self.config = config
        self.service = service
    }

    public func viewDidAppear() async {
        await loadChannels()
    }

    public func refresh() async {
        channels = []
        currentPage = 1
        lastPage = 1
        await loadChannels()
    }

    public func loadNextPageIfNeeded(currentItem: ChannelResponse) {
        guard currentItem.id == channels.last?.id else { return }
        loadNextPage()
    }

    // MARK: - Private

    private func loadChannels() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await service.getChannels(
                config: config,
                page: 1,
                filter: nil,
                query: nil
            )
            channels = response.data
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
                let response = try await service.getChannels(
                    config: config,
                    page: nextPage,
                    filter: nil,
                    query: nil
                )
                channels.append(contentsOf: response.data)
                currentPage = response.paginate.currentPage
                lastPage = response.paginate.lastPage
            } catch {}
        }
    }
}
#endif
