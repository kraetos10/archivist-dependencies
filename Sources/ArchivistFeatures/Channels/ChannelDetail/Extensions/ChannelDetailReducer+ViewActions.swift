import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension ChannelDetailReducer {
    func handleViewAction(
        _ action: Action.View,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .viewDidAppear:
            return handleViewDidAppear(state: &state)
        case .pullToRefreshTriggered:
            return handlePullToRefreshTriggered(state: &state)
        case .lastVideoAppeared:
            return handleLastVideoAppeared(state: &state)
        case .videoCardTapped(let video):
            return handleVideoCardTapped(video, state: &state)
        case .downloadCardTapped(let download):
            return handleDownloadCardTapped(download, state: &state)
        case .unsubscribeTapped:
            return handleUnsubscribeTapped(state: &state)
        case .descriptionToggleTapped:
            return handleDescriptionToggleTapped(state: &state)
        case .videoFilterChanged(let filter):
            state.videoFilter = filter
            return .none
        case .downloadToDeviceTapped(let video):
            return handleDownloadToDeviceTapped(video, state: &state)
        case .deleteFromDeviceTapped(let video):
            return handleDeleteFromDeviceTapped(video, state: &state)
        case .markAsWatchedTapped(let video):
            return handleMarkAsWatchedTapped(video, state: &state)
        case .deleteFromServerTapped(let video):
            return handleDeleteFromServerTapped(video, state: &state)
        case .playNextTapped(let video):
            return handlePlayNextTapped(video, state: &state)
        case .addToPlaylistTapped(let video):
            return handleAddToPlaylistTapped(video, state: &state)
        case .downloadSortToggled:
            return handleDownloadSortToggled(state: &state)
        case .videoSortOrderChanged(let sort):
            return handleVideoSortOrderChanged(sort, state: &state)
        case .clearFilteredTapped:
            return handleClearFilteredTapped(state: &state)
        }
    }

    // MARK: - Private Handlers

    private func handleViewDidAppear(state: inout State) -> Effect<Action> {
        var effects: [Effect<Action>] = []

        if state.videos.isEmpty, !state.isLoadingVideos {
            state.isLoadingVideos = true
            effects.append(fetchVideos(page: 1, state: state))
        }

        if state.pendingDownloads.isEmpty, !state.isLoadingDownloads {
            state.isLoadingDownloads = true
            effects.append(fetchPendingDownloads(page: 1, state: state))
        }

        return .merge(effects)
    }

    private func handlePullToRefreshTriggered(state: inout State) -> Effect<Action> {
        state.isLoadingVideos = true
        state.isLoadingMoreVideos = false
        state.isLoadingDownloads = true
        state.currentPage = 1
        return .merge(
            fetchVideos(page: 1, state: state),
            fetchPendingDownloads(page: 1, state: state)
        )
    }

    private func handleLastVideoAppeared(state: inout State) -> Effect<Action> {
        // A first-page load in flight owns the video request; paging now
        // would cancel it.
        guard state.currentPage < state.lastPage,
              !state.isLoadingMoreVideos,
              !state.isLoadingVideos else { return .none }
        state.isLoadingMoreVideos = true
        return fetchVideos(page: state.currentPage + 1, state: state)
    }

    private func handleVideoCardTapped(
        _ video: VideoResponse,
        state: inout State
    ) -> Effect<Action> {
        let nextVideos: [VideoResponse]
        if let index = state.videos.index(id: video.id) {
            nextVideos = state.videos.elements[(index + 1)...].filter { !$0.isWatched }
        } else {
            nextVideos = []
        }
        return .send(.delegate(.videoSelected(video, nextVideos: nextVideos)))
    }

    private func handleDownloadCardTapped(
        _ download: DownloadResponse,
        state: inout State
    ) -> Effect<Action> {
        #if os(tvOS)
        state.alert = AlertState {
            TextState(download.title ?? download.youtubeId)
        } actions: {
            ButtonState(action: .confirmDownload(download.youtubeId)) {
                TextState(String.localised("video.downloadNow", table: .videos))
            }
            ButtonState(role: .cancel) {
                TextState(String.localised("generic.cancel", table: .generic))
            }
        } message: {
            TextState(String.localised("video.confirmDownload", table: .videos))
        }
        #else
        state.downloadDetail = DownloadDetailReducer.State(
            serverConfig: state.serverConfig,
            download: download
        )
        #endif
        return .none
    }

    private func handleUnsubscribeTapped(state: inout State) -> Effect<Action> {
        let channelName = state.channel.channelName
        state.alert = AlertState {
            TextState(String.localised("generic.unsubscribe", table: .generic))
        } actions: {
            ButtonState(role: .cancel) {
                TextState(String.localised("generic.cancel", table: .generic))
            }
            ButtonState(role: .destructive, action: .confirmUnsubscribe) {
                TextState(String.localised("generic.unsubscribe", table: .generic))
            }
        } message: {
            TextState(
                String.localised(
                    "channel.unsubscribeConfirm \(channelName)",
                    table: .login
                )
            )
        }
        return .none
    }

    private func handleDescriptionToggleTapped(state: inout State) -> Effect<Action> {
        state.isDescriptionExpanded.toggle()
        return .none
    }

    private func handleDownloadToDeviceTapped(
        _ video: VideoResponse,
        state: inout State
    ) -> Effect<Action> {
        guard let mediaPath = video.mediaUrl,
              let mediaURL = state.serverConfig.fullURL(for: mediaPath) else {
            return .none
        }
        let videoId = video.videoId
        let title = video.title
        let channelName = video.channelName
        let thumbUrl = video.vidThumbUrl
        let thumbnailURL = thumbUrl.flatMap { state.serverConfig.fullURL(for: $0) }
        let authHeaders = state.serverConfig.authHeaders
        let expectedSize = video.mediaSize.map { Int64($0) }
        let expectedSizeInt = video.mediaSize
        let createdAt = now.timeIntervalSince1970
        return .run { _ in
            let download = DeviceDownload(
                id: videoId,
                title: title,
                channelName: channelName,
                thumbUrl: thumbUrl,
                status: .downloading,
                progress: 0,
                fileSize: expectedSizeInt,
                createdAt: createdAt
            )
            try? deviceDownloadDatabase.insertDownload(download)
            await persistentDownloadManager.startDownload(
                url: mediaURL,
                videoId: videoId,
                title: title,
                expectedSize: expectedSize,
                authHeaders: authHeaders,
                thumbnailURL: thumbnailURL
            )
        }
    }

    private func handleDeleteFromDeviceTapped(
        _ video: VideoResponse,
        state: inout State
    ) -> Effect<Action> {
        let videoId = video.videoId
        return .run { _ in
            try? localVideoStorage.deleteVideo(videoId: videoId)
            try? deviceDownloadDatabase.deleteDownload(videoId)
        }
    }

    /// Flips the card straight away; `setWatchedResult` rolls it back if
    /// the server refuses.
    private func handleMarkAsWatchedTapped(
        _ video: VideoResponse,
        state: inout State
    ) -> Effect<Action> {
        let config = state.serverConfig
        let videoId = video.videoId
        let newIsWatched = !video.isWatched
        if let current = state.videos[id: videoId] {
            state.videos[id: videoId] = current.settingWatched(newIsWatched)
        }
        let videoService = self.videoService
        return .run { send in
            let result = await Result {
                try await videoService.setWatched(
                    config: config,
                    videoId: videoId,
                    isWatched: newIsWatched
                )
            }
            await send(.setWatchedResult(videoId: videoId, isWatched: newIsWatched, result))
        }
    }

    private func handleDeleteFromServerTapped(
        _ video: VideoResponse,
        state: inout State
    ) -> Effect<Action> {
        let config = state.serverConfig
        let videoId = video.videoId
        let videoService = self.videoService
        return .run { send in
            let result = await Result {
                try await videoService.deleteVideo(config: config, id: videoId)
            }
            await send(.deleteVideoResult(result.map { videoId }), animation: .default)
        }
    }

    private func handlePlayNextTapped(
        _ video: VideoResponse,
        state: inout State
    ) -> Effect<Action> {
        .run { [playNextDatabase] _ in
            try? await playNextDatabase.addToQueue(video)
        }
    }

    private func handleAddToPlaylistTapped(
        _ video: VideoResponse,
        state: inout State
    ) -> Effect<Action> {
        state.playlistPicker = PlaylistPickerReducer.State(
            serverConfig: state.serverConfig,
            videoId: video.videoId
        )
        return .none
    }

    private func handleDownloadSortToggled(state: inout State) -> Effect<Action> {
        state.showNewestDownloadsFirst.toggle()
        state.pendingDownloads = []
        state.hasLoadedDownloads = false
        state.isLoadingDownloads = true
        return fetchPendingDownloads(page: 1, state: state)
    }

    private func handleClearFilteredTapped(state: inout State) -> Effect<Action> {
        let count = state.filteredVideos.count
        guard count > 0 else { return .none }
        let message = state.videoFilter == .unwatched
            ? String.localised("video.clearFiltered.unwatchedMessage \(count)", table: .videos)
            : String.localised("video.clearFiltered.allMessage \(count)", table: .videos)
        state.alert = AlertState {
            TextState(String.localised("video.clearFiltered.title", table: .videos))
        } actions: {
            ButtonState(role: .cancel) {
                TextState(String.localised("generic.cancel", table: .generic))
            }
            ButtonState(role: .destructive, action: .confirmClearFiltered) {
                TextState(String.localised("generic.delete", table: .generic))
            }
        } message: {
            TextState(message)
        }
        return .none
    }

    func handleConfirmClearFiltered(state: inout State) -> Effect<Action> {
        let videoIds = state.filteredVideos.map(\.videoId)
        let config = state.serverConfig
        return .run { [videoService] send in
            await withTaskGroup(of: Void.self) { group in
                for videoId in videoIds {
                    group.addTask {
                        let result = await Result {
                            try await videoService.deleteVideo(config: config, id: videoId)
                        }
                        await send(
                            .deleteVideoResult(result.map { videoId }),
                            animation: .default
                        )
                    }
                }
            }
        }
    }

    private func handleVideoSortOrderChanged(
        _ sort: VideoSortOrder,
        state: inout State
    ) -> Effect<Action> {
        guard sort != state.videoSortOrder else { return .none }
        state.videoSortOrder = sort
        state.videos = []
        state.currentPage = 1
        state.lastPage = 1
        state.hasLoadedVideos = false
        state.isLoadingVideos = true
        state.isLoadingMoreVideos = false
        // Cancels any page still loading for the previous sort.
        return fetchVideos(page: 1, state: state)
    }
}
