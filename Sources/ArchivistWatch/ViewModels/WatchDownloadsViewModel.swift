#if os(watchOS)
import ArchivistNetworking
import Foundation

@MainActor
@Observable
public final class WatchDownloadsViewModel {
    public var isShowingCancelConfirmation = false
    public var isShowingRecordActions = false
    public private(set) var selectedRecord: WatchDownload?
    public private(set) var errorMessage: String?

    public let config: ServerConfig

    @ObservationIgnored private let playback: WatchPlaybackServices

    public init(
        config: ServerConfig,
        playback: WatchPlaybackServices
    ) {
        self.config = config
        self.playback = playback
    }

    public var records: [WatchDownload] {
        playback.catalog.records
    }

    public var hasActiveDownload: Bool {
        playback.downloadManager.isDownloading
    }

    public var activeDownloadTitle: String {
        playback.downloadManager.activeDownloadTitle ?? ""
    }

    public var activeDownloadChannel: String? {
        playback.downloadManager.activeDownloadChannel
    }

    public var activeDownloadProgress: Double {
        playback.downloadManager.progress
    }

    public var activeDownloadProgressText: String {
        let percent = Int((activeDownloadProgress * 100).rounded(.down))
        return String(localized: "download.progress \(percent)", bundle: .module)
    }

    public var isEmpty: Bool {
        records.isEmpty && !hasActiveDownload
    }

    /// Summed from the stored file sizes rather than walking the directory,
    /// so it's cheap enough to read on every render.
    public var formattedStorageUsed: String {
        Int64(records.compactMap(\.fileSize).reduce(0, +)).formatted(.byteCount(style: .file))
    }

    public var selectedRecordTitle: String {
        selectedRecord?.title ?? ""
    }

    public func rowModel(for record: WatchDownload) -> WatchVideoRowModel {
        WatchVideoRowModel(
            title: record.title,
            thumbnailURL: record.thumbPath.flatMap(config.fullURL(for:)),
            isWatched: false,
            isDownloaded: true,
            watchProgress: watchProgress(for: record),
            subtitle: WatchVideoRowModel.subtitle(
                watchProgress: watchProgress(for: record),
                remainingSeconds: remainingSeconds(for: record),
                durationStr: record.durationStr
            )
        )
    }

    /// Built when a row is pushed, never while the list is drawn: creating a
    /// player activates the audio session, decodes the file and takes over the
    /// system Now Playing card, which a row label must not do.
    public func player(for videoId: String) -> WatchAudioPlayerViewModel? {
        guard let record = playback.catalog.record(for: videoId) else { return nil }
        return playback.player(for: record, config: config)
    }

    public func activeDownloadTapped() {
        isShowingCancelConfirmation = true
    }

    public func cancelActiveDownloadConfirmed() {
        isShowingCancelConfirmation = false
        playback.downloadManager.cancelDownload()
    }

    public func recordActionsTapped(_ record: WatchDownload) {
        selectedRecord = record
        isShowingRecordActions = true
    }

    public func deleteSelectedRecordConfirmed() {
        guard let record = selectedRecord else { return }
        selectedRecord = nil
        isShowingRecordActions = false
        errorMessage = nil
        if let player = playback.nowPlaying.activePlayer, player.videoId == record.id {
            player.teardown()
        }
        do {
            try playback.downloadManager.deleteDownload(videoId: record.id)
        } catch {
            errorMessage = String(localized: "download.deleteFailed", bundle: .module)
        }
    }

    func watchProgress(for record: WatchDownload) -> Double {
        guard let duration = record.duration, duration > 0 else { return 0 }
        return min(record.lastPlayedPosition / Double(duration), 1.0)
    }

    func remainingSeconds(for record: WatchDownload) -> Int? {
        guard let duration = record.duration, duration > 0,
              record.lastPlayedPosition > 0 else { return nil }
        return max(duration - Int(record.lastPlayedPosition), 0)
    }
}
#endif
