#if os(watchOS)
import ArchivistNetworking
import Foundation

public enum WatchQueueSortOrder: Sendable {
    case recentlyAdded
    case oldestAdded
}

@MainActor
@Observable
public final class WatchServerQueueViewModel {
    public private(set) var downloads: [DownloadResponse] = []
    public private(set) var isLoading = false
    public private(set) var sortOrder: WatchQueueSortOrder = .recentlyAdded
    public private(set) var errorMessage: String?
    public private(set) var selectedDownload: DownloadResponse?
    public var isShowingDownloadActions = false
    public var addDownload: WatchAddDownloadViewModel?

    public let config: ServerConfig

    @ObservationIgnored private let service: DownloadService
    @ObservationIgnored private var generation = 0

    public init(
        config: ServerConfig,
        service: DownloadService = .liveValue
    ) {
        self.config = config
        self.service = service
    }

    public var downloadIDs: [String] {
        downloads.map(\.id)
    }

    public var sortOrderLabel: String {
        switch sortOrder {
        case .recentlyAdded: String(localized: "queue.recentlyAdded", bundle: .module)
        case .oldestAdded: String(localized: "queue.oldestAdded", bundle: .module)
        }
    }

    public var selectedDownloadTitle: String {
        selectedDownload.map { $0.title ?? $0.youtubeId } ?? ""
    }

    public func title(for download: DownloadResponse) -> String {
        download.title ?? download.youtubeId
    }

    public func thumbnailURL(for download: DownloadResponse) -> URL? {
        download.vidThumbUrl.flatMap(config.fullURL(for:))
    }

    public func viewDidAppear() async {
        await loadQueue()
    }

    public func refresh() async {
        await loadQueue()
    }

    /// Sort order maps to a different page on the server, so this re-fetches
    /// rather than re-sorting — and supersedes a load already in flight, which
    /// would otherwise land with the old order.
    public func sortOrderButtonTapped() async {
        sortOrder = sortOrder == .recentlyAdded ? .oldestAdded : .recentlyAdded
        await loadQueue()
    }

    public func downloadTapped(_ download: DownloadResponse) {
        selectedDownload = download
        isShowingDownloadActions = true
    }

    public func addButtonTapped() {
        addDownload = WatchAddDownloadViewModel(
            config: config,
            service: service
        )
    }

    /// The add sheet finished adding; refresh so the new item shows.
    public func downloadAdded() async {
        addDownload = nil
        await loadQueue()
    }

    public func prioritizeSelectedTapped() async {
        guard let download = takeSelection() else { return }
        do {
            try await service.updateDownload(
                config: config,
                id: download.youtubeId,
                status: DownloadStatus.priority.rawValue
            )
        } catch {
            errorMessage = String(localized: "queue.actionFailed", bundle: .module)
        }
        await loadQueue()
    }

    /// Removed from the list straight away; a failed delete reloads the queue
    /// so the row comes back rather than silently disagreeing with the server.
    public func removeSelectedTapped() async {
        guard let download = takeSelection() else { return }
        downloads.removeAll { $0.youtubeId == download.youtubeId }
        do {
            try await service.deleteDownload(
                config: config,
                id: download.youtubeId
            )
        } catch {
            errorMessage = String(localized: "queue.actionFailed", bundle: .module)
            await loadQueue()
        }
    }

    private func takeSelection() -> DownloadResponse? {
        let download = selectedDownload
        selectedDownload = nil
        isShowingDownloadActions = false
        errorMessage = nil
        return download
    }

    private func loadQueue() async {
        generation += 1
        let current = generation
        let order = sortOrder
        isLoading = true
        defer {
            if current == generation {
                isLoading = false
            }
        }

        do {
            // TubeArchivist returns pending downloads oldest-first across
            // pages, so the most recently queued items live on the API's
            // last page. Mirror the phone's `DownloadsReducer` behaviour:
            // discover `lastPage` from page 1, then fetch from the end and
            // reverse so newest is at the top.
            let firstPage = try await fetch(page: 1)
            let result: [DownloadResponse]
            switch order {
            case .recentlyAdded:
                let lastPage = firstPage.paginate.lastPage
                let page = lastPage > 1 ? try await fetch(page: lastPage) : firstPage
                result = Array(page.data.reversed())
            case .oldestAdded:
                result = firstPage.data
            }
            guard current == generation else { return }
            downloads = result
        } catch {
            if !Task.isCancelled, current == generation {
                errorMessage = String(localized: "generic.loadFailed", bundle: .module)
            }
        }
    }

    private func fetch(page: Int) async throws -> PaginatedResponse<DownloadResponse> {
        try await service.getDownloads(
            config: config,
            page: page,
            filter: nil,
            channel: nil,
            query: nil,
            vidType: nil
        )
    }
}
#endif
