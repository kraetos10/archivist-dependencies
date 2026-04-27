#if os(watchOS)
import ArchivistNetworking
import Foundation
import SwiftUI

public enum WatchQueueSortOrder {
    case recentlyAdded
    case oldestAdded
}

@MainActor
@Observable
public final class WatchServerQueueViewModel {
    public var downloads: [DownloadResponse] = []
    public var isLoading = false
    public var sortOrder: WatchQueueSortOrder = .recentlyAdded
    public let config: ServerConfig
    private let service: any DownloadServiceType

    public init(
        config: ServerConfig,
        service: any DownloadServiceType = DownloadService()
    ) {
        self.config = config
        self.service = service
    }

    /// `downloads` is already in the order we want to display — the
    /// `recentlyAdded` path fetches the API's last page and reverses it,
    /// the `oldestAdded` path keeps page 1 as-is. No additional sort here.
    public var sortedDownloads: [DownloadResponse] {
        downloads
    }

    public func toggleSortOrder() {
        sortOrder = sortOrder == .recentlyAdded ? .oldestAdded : .recentlyAdded
        // Sort order maps to a different page on the server, so we have to
        // re-fetch rather than just re-sorting what we already have.
        Task { await loadQueue() }
    }

    public func viewDidAppear() async {
        await loadQueue()
    }

    public func deleteDownloads(at offsets: IndexSet) async {
        let ids = offsets.map { downloads[$0].youtubeId }
        withAnimation {
            downloads.remove(atOffsets: offsets)
        }

        for id in ids {
            try? await service.deleteDownload(
                config: config,
                id: id
            )
        }
    }

    public func deleteDownload(_ download: DownloadResponse) async {
        withAnimation {
            downloads.removeAll { $0.youtubeId == download.youtubeId }
        }
        try? await service.deleteDownload(
            config: config,
            id: download.youtubeId
        )
    }

    public func prioritizeDownload(_ download: DownloadResponse) async {
        try? await service.updateDownload(
            config: config,
            id: download.youtubeId,
            status: "priority"
        )
        await loadQueue()
    }

    public func refresh() async {
        await loadQueue()
    }

    // MARK: - Private

    private func loadQueue() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            // TubeArchivist returns pending downloads oldest-first across
            // pages, so the most recently queued items live on the API's
            // last page. Mirror the phone's `DownloadsReducer` behaviour:
            // discover `lastPage` from page 1, then fetch from the end and
            // reverse so newest is at the top.
            let firstPage = try await service.getDownloads(
                config: config,
                page: 1,
                filter: nil,
                channel: nil,
                query: nil,
                vidType: nil
            )
            let lastPage = firstPage.paginate.lastPage

            switch sortOrder {
            case .recentlyAdded:
                if lastPage > 1 {
                    let response = try await service.getDownloads(
                        config: config,
                        page: lastPage,
                        filter: nil,
                        channel: nil,
                        query: nil,
                        vidType: nil
                    )
                    downloads = Array(response.data.reversed())
                } else {
                    downloads = Array(firstPage.data.reversed())
                }
            case .oldestAdded:
                downloads = firstPage.data
            }
        } catch {}
    }
}
#endif
