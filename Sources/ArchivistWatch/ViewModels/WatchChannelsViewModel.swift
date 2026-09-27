#if os(watchOS)
import ArchivistNetworking
import Foundation

@MainActor
@Observable
public final class WatchChannelsViewModel {
    public private(set) var channels: [ChannelResponse] = []
    public private(set) var isLoading = false
    public private(set) var isLoadingMore = false
    public private(set) var errorMessage: String?

    public let config: ServerConfig

    @ObservationIgnored private let service: ChannelService
    @ObservationIgnored private let videoService: VideoService
    @ObservationIgnored private let playback: WatchPlaybackServices
    @ObservationIgnored private var paging = WatchPaging()
    @ObservationIgnored private var detail: (channelId: String, viewModel: WatchChannelDetailViewModel)?

    public init(
        config: ServerConfig,
        service: ChannelService = .liveValue,
        videoService: VideoService = .liveValue,
        playback: WatchPlaybackServices
    ) {
        self.config = config
        self.service = service
        self.videoService = videoService
        self.playback = playback
    }

    public func viewDidAppear() async {
        guard !paging.hasLoaded else { return }
        await loadFirstPage()
    }

    public func refresh() async {
        await loadFirstPage()
    }

    public func rowAppeared(_ channel: ChannelResponse) async {
        guard channel.id == channels.last?.id,
              !isLoading,
              !isLoadingMore,
              let request = paging.nextPageRequest() else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let response = try await fetch(page: request.page)
            guard paging.accept(response.paginate, for: request) else { return }
            channels.append(contentsOf: response.data.filter { new in !channels.contains { $0.id == new.id } })
        } catch {
            if !Task.isCancelled {
                errorMessage = String(localized: "generic.loadFailed", bundle: .module)
            }
        }
    }

    public func thumbnailURL(for channel: ChannelResponse) -> URL? {
        channel.channelThumbUrl.flatMap(config.fullURL(for:))
    }

    public func subscribersText(for channel: ChannelResponse) -> String? {
        channel.formattedSubs.map { String(localized: "channel.subscribers \($0)", bundle: .module) }
    }

    /// Reused for the same channel, since the destination is rebuilt on every
    /// render and a fresh view model would reload and lose its paging.
    public func detailViewModel(for channel: ChannelResponse) -> WatchChannelDetailViewModel {
        if let detail, detail.channelId == channel.channelId {
            return detail.viewModel
        }
        let viewModel = WatchChannelDetailViewModel(
            config: config,
            channelId: channel.channelId,
            service: videoService,
            playback: playback
        )
        detail = (channel.channelId, viewModel)
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
            channels = response.data
        } catch {
            if !Task.isCancelled, paging.isCurrent(request) {
                errorMessage = String(localized: "generic.loadFailed", bundle: .module)
            }
        }
    }

    private func fetch(page: Int) async throws -> PaginatedResponse<ChannelResponse> {
        try await service.getChannels(
            config: config,
            page: page,
            filter: nil,
            query: nil
        )
    }
}
#endif
