#if os(watchOS)
import ArchivistNetworking
import Foundation

@MainActor
@Observable
public final class WatchDownloadsViewModel {
    public let catalog = WatchDownloadCatalog.shared
    public let storage = WatchAudioStorage()
    private let downloadManager = WatchDownloadManager.shared

    public init() {}

    public var records: [WatchDownload] {
        catalog.records.filter { storage.isDownloaded(videoId: $0.id) }
    }

    public var hasActiveDownload: Bool {
        downloadManager.isDownloading
    }

    public var activeDownloadTitle: String? {
        downloadManager.activeDownloadTitle
    }

    public var activeDownloadChannel: String? {
        downloadManager.activeDownloadChannel
    }

    public var activeDownloadProgress: Double {
        downloadManager.progress
    }

    public var isEmpty: Bool {
        records.isEmpty && !hasActiveDownload
    }

    public var formattedStorageUsed: String {
        storage.formattedStorageUsed()
    }

    public func isDownloaded(videoId: String) -> Bool {
        storage.isDownloaded(videoId: videoId)
    }

    public func fileURL(for videoId: String) -> URL {
        storage.localFileURL(for: videoId)
    }

    /// Built when a row is pushed, never while the list is drawn: creating a
    /// player activates the audio session, decodes the file and takes over the
    /// system Now Playing card, which a row label must not do.
    public func player(
        for videoId: String,
        config: ServerConfig
    ) -> WatchAudioPlayerViewModel? {
        guard let record = catalog.record(for: videoId) else { return nil }
        return WatchNowPlayingState.shared.player(for: videoId) {
            WatchAudioPlayerViewModel(
                videoId: record.id,
                title: record.title,
                channelName: record.channelName,
                thumbPath: record.thumbPath,
                fileURL: storage.localFileURL(for: record.id),
                serverConfig: config,
                startPosition: record.lastPlayedPosition
            )
        }
    }

    public func cancelActiveDownload() {
        downloadManager.cancelDownload()
    }

    public func watchProgress(for record: WatchDownload) -> Double {
        guard let duration = record.duration, duration > 0 else { return 0 }
        return min(record.lastPlayedPosition / Double(duration), 1.0)
    }

    private static let remainingFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute]
        formatter.zeroFormattingBehavior = .dropLeading
        return formatter
    }()

    public func remainingStr(for record: WatchDownload) -> String? {
        guard let duration = record.duration, duration > 0,
              record.lastPlayedPosition > 0 else { return nil }
        let remaining = max(duration - Int(record.lastPlayedPosition), 0)
        return Self.remainingFormatter.string(from: TimeInterval(remaining))
            .map { "\($0) remaining" }
    }

    public func deleteDownload(videoId: String) {
        try? downloadManager.deleteDownload(videoId: videoId)
    }

    public func deleteDownloads(at offsets: IndexSet) async {
        for index in offsets {
            let record = catalog.records[index]
            try? WatchDownloadManager.shared.deleteDownload(videoId: record.id)
        }
    }

}
#endif
