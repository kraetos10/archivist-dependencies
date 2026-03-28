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

    public var sortedDownloads: [DownloadResponse] {
        switch sortOrder {
        case .recentlyAdded:
            return downloads
        case .oldestAdded:
            return downloads.reversed()
        }
    }

    public func toggleSortOrder() {
        sortOrder = sortOrder == .recentlyAdded ? .oldestAdded : .recentlyAdded
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
            let response = try await service.getDownloads(
                config: config,
                page: 1,
                filter: nil,
                channel: nil,
                query: nil,
                vidType: nil
            )
            downloads = response.data
        } catch {}
    }
}
#endif
