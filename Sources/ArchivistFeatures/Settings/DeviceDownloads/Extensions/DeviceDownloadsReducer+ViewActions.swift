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
            return refreshStoragePeriodically()
        case .viewDidDisappear:
            // The reducer lives for the app's lifetime as a tab root, so
            // the storage poll has to stop when the tab isn't on screen.
            return .cancel(id: CancelID.storageRefresh)
        case .deleteTapped(let videoId):
            return handleDeleteTapped(videoId)
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

    /// Reads storage now, then every few seconds while the screen is up so
    /// the bar tracks downloads finishing in the background.
    private func refreshStoragePeriodically() -> Effect<Action> {
        .run { [clock, deviceStorage] send in
            while true {
                await send(.storageInfoLoaded(deviceStorage.usage()))
                try await clock.sleep(for: .seconds(3))
            }
        }
        .cancellable(id: CancelID.storageRefresh, cancelInFlight: true)
    }

    private func handleDeleteTapped(_ videoId: String) -> Effect<Action> {
        .run { [deviceDownloadDatabase, deviceStorage, localVideoStorage] send in
            do {
                try localVideoStorage.deleteVideo(videoId: videoId)
                try deviceDownloadDatabase.deleteDownload(videoId)
            } catch {
                await send(.operationFailed(error.localizedDescription))
            }
            await send(.storageInfoLoaded(deviceStorage.usage()))
        }
    }

    private func handleDownloadTapped(
        _ download: DeviceDownload,
        state: inout State
    ) -> Effect<Action> {
        switch download.status {
        case .completed:
            let completed = state.completedDownloads
            let nextVideos: [VideoResponse]
            if let index = completed.firstIndex(where: { $0.id == download.id }) {
                nextVideos = completed[completed.index(after: index)...].map(\.offlineVideo)
            } else {
                nextVideos = []
            }
            state.videoDetail = VideoDetailReducer.State(
                serverConfig: state.serverConfig,
                video: download.offlineVideo,
                nextVideos: nextVideos,
                shouldAutoPlayNextVideo: state.autoPlayEnabled
            )
            return .none
        case .failed:
            return retryDownload(videoId: download.id, config: state.serverConfig)
        case .downloading, .none:
            return .none
        }
    }

    private func retryDownload(
        videoId: String,
        config: ServerConfig
    ) -> Effect<Action> {
        .run { [now, videoService, deviceDownloadDatabase, persistentDownloadManager] send in
            do {
                let video = try await videoService.getVideo(config: config, id: videoId)
                guard let mediaPath = video.mediaUrl,
                      let mediaURL = config.fullURL(for: mediaPath) else {
                    await send(.operationFailed(String.localised("video.download.unavailable", table: .videos)))
                    return
                }
                try deviceDownloadDatabase.insertDownload(DeviceDownload(
                    id: videoId,
                    title: video.title,
                    channelName: video.channelName,
                    thumbUrl: video.vidThumbUrl,
                    status: .downloading,
                    progress: 0,
                    fileSize: video.mediaSize,
                    createdAt: now.timeIntervalSince1970
                ))
                await persistentDownloadManager.startDownload(
                    url: mediaURL,
                    videoId: videoId,
                    title: video.title,
                    expectedSize: video.mediaSize.map { Int64($0) },
                    authHeaders: config.authHeaders,
                    thumbnailURL: video.vidThumbUrl.flatMap { config.fullURL(for: $0) }
                )
            } catch {
                await send(.operationFailed(error.localizedDescription))
            }
        }
    }
}
#endif
