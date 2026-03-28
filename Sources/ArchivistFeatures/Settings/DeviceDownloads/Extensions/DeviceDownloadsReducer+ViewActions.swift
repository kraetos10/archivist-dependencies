#if !os(tvOS)
import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension DeviceDownloadsReducer {
    public func handleViewAction(
        _ action: Action.View,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .viewDidAppear:
            return handleViewDidAppear(state: &state)
        case .deleteTapped(let videoId):
            return handleDeleteTapped(videoId, state: &state)
        case .downloadTapped(let download):
            return handleDownloadTapped(download, state: &state)
        case .addToPlaylistTapped(let download):
            state.playlistPicker = PlaylistPickerReducer.State(
                serverConfig: state.serverConfig,
                videoId: download.id
            )
            return .none
        }
    }

    // MARK: - Private Handlers

    private func handleViewDidAppear(state: inout State) -> Effect<Action> {
        .merge(
            refreshStorageInfo(),
            // Periodically refresh storage while the screen is visible
            // so it updates when downloads complete in the background
            .run { send in
                while !Task.isCancelled {
                    try await Task.sleep(nanoseconds: 3_000_000_000)
                    let downloadsSize = LocalVideoStorage.totalDownloadsSize()
                    let resourceValues = try? URL(
                        fileURLWithPath: NSHomeDirectory())
                        .resourceValues(
                            forKeys: [
                                .volumeAvailableCapacityForImportantUsageKey,
                                .volumeTotalCapacityKey
                            ]
                        )
                    let available = resourceValues?.volumeAvailableCapacityForImportantUsage ?? 0
                    let total = Int64(resourceValues?.volumeTotalCapacity ?? 0)
                    await send(.storageInfoLoaded(downloadsSize: downloadsSize, available: available, total: total))
                }
            }
            .cancellable(id: CancelID.storageRefresh, cancelInFlight: true)
        )
    }

    private func refreshStorageInfo() -> Effect<Action> {
        .run { send in
            let downloadsSize = LocalVideoStorage.totalDownloadsSize()
            let resourceValues = try? URL(fileURLWithPath: NSHomeDirectory())
                .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey])
            let available = resourceValues?.volumeAvailableCapacityForImportantUsage ?? 0
            let total = Int64(resourceValues?.volumeTotalCapacity ?? 0)
            await send(.storageInfoLoaded(downloadsSize: downloadsSize, available: available, total: total))
        }
    }

    private func handleDeleteTapped(
        _ videoId: String,
        state: inout State
    ) -> Effect<Action> {
        try? localVideoStorage.deleteVideo(videoId: videoId)
        try? deviceDownloadDatabase.deleteDownload(videoId)
        return refreshStorageInfo()
    }

    private func handleDownloadTapped(
        _ download: DeviceDownload,
        state: inout State
    ) -> Effect<Action> {
        switch download.status {
        case .completed:
            let video = videoResponse(from: download)
            let allCompleted = state.completedDownloads
            let nextVideos: [VideoResponse]
            if let index = allCompleted.firstIndex(where: { $0.id == download.id }) {
                nextVideos = allCompleted
                    .suffix(from: allCompleted.index(after: index))
                    .map { videoResponse(from: $0) }
            } else {
                nextVideos = []
            }
            return .send(.delegate(.playVideo(video, nextVideos: nextVideos)))
        case .failed:
            let videoId = download.id
            let config = state.serverConfig
            return .run { [videoService, deviceDownloadDatabase, persistentDownloadManager] _ in
                let video = try await videoService.getVideo(config: config, id: videoId)
                guard let mediaPath = video.mediaUrl,
                      let mediaURL = config.fullURL(for: mediaPath) else { return }

                let retryDownload = DeviceDownload(
                    id: videoId,
                    title: video.title,
                    channelName: video.channelName,
                    thumbUrl: video.vidThumbUrl,
                    status: .downloading,
                    progress: 0,
                    createdAt: Date().timeIntervalSince1970
                )
                try? deviceDownloadDatabase.insertDownload(retryDownload)

                await persistentDownloadManager.startDownload(
                    url: mediaURL,
                    videoId: videoId,
                    title: video.title,
                    expectedSize: video.mediaSize.map { Int64($0) },
                    authHeaders: config.authHeaders
                )
            }
        default:
            return .none
        }
    }

    private func videoResponse(from download: DeviceDownload) -> VideoResponse {
        VideoResponse(
            videoId: download.id,
            title: download.title,
            description: nil,
            category: nil,
            channel: VideoChannel(
                channelId: "",
                channelName: download.channelName,
                channelActive: nil,
                channelBannerUrl: nil,
                channelThumbUrl: nil,
                channelTvartUrl: nil,
                channelDescription: nil,
                channelLastRefresh: nil,
                channelSubs: nil,
                channelSubscribed: nil,
                channelTags: nil,
                channelTabs: nil
            ),
            published: nil,
            dateDownloaded: nil,
            vidLastRefresh: nil,
            vidThumbUrl: download.thumbUrl,
            vidType: nil,
            active: nil,
            mediaUrl: nil,
            mediaSize: nil,
            player: nil,
            stats: nil,
            subtitles: nil,
            streams: nil,
            tags: nil,
            commentCount: nil
        )
    }
}
#endif
