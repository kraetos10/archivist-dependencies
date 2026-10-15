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
            return handleVideoFilterChanged(filter, state: &state)
        case .downloadToDeviceTapped, .deleteFromDeviceTapped, .markAsWatchedTapped,
             .deleteFromServerTapped, .playNextTapped, .addToPlaylistTapped:
            return handleVideoMenuAction(action, state: &state)
        case .downloadSortToggled:
            return handleDownloadSortToggled(state: &state)
        case .videoSortOrderChanged(let sort):
            return handleVideoSortOrderChanged(sort, state: &state)
        case .clearFilteredTapped:
            return handleClearFilteredTapped(state: &state)
        case .pendingDownloadsToggled:
            state.isPendingDownloadsExpanded.toggle()
            return .none
        case .selectTapped, .doneSelectingTapped, .selectAllTapped,
             .markSelectedWatchedTapped, .downloadSelectedToDeviceTapped,
             .deleteSelectedTapped:
            return handleSelectionAction(action, state: &state)
        }
    }

    /// A single video's context-menu actions.
    private func handleVideoMenuAction(
        _ action: Action.View,
        state: inout State
    ) -> Effect<Action> {
        switch action {
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
        default:
            return .none
        }
    }

    private func handleSelectionAction(
        _ action: Action.View,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .selectTapped:
            state.isSelecting = true
            state.selectedVideoIDs = []
            return .none
        case .doneSelectingTapped:
            endSelection(state: &state)
            return .none
        case .selectAllTapped:
            return handleSelectAllTapped(state: &state)
        case .markSelectedWatchedTapped:
            return handleMarkSelectedWatchedTapped(state: &state)
        case .downloadSelectedToDeviceTapped:
            return handleDownloadSelectedToDeviceTapped(state: &state)
        case .deleteSelectedTapped:
            return handleDeleteSelectedTapped(state: &state)
        default:
            return .none
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
        if state.isSelecting {
            if state.selectedVideoIDs.contains(video.videoId) {
                state.selectedVideoIDs.remove(video.videoId)
            } else {
                state.selectedVideoIDs.insert(video.videoId)
            }
            return .none
        }
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
            await persistentDownloadManager.cancelDownload(videoId: videoId)
            try? localVideoStorage.deleteVideo(videoId: videoId)
            try? deviceDownloadDatabase.deleteDownload(videoId)
        }
    }

    private func handleMarkAsWatchedTapped(
        _ video: VideoResponse,
        state: inout State
    ) -> Effect<Action> {
        setWatched(video.videoId, isWatched: !video.isWatched, state: &state)
    }

    /// Flips the card straight away; `setWatchedResult` rolls it back if
    /// the server refuses.
    private func setWatched(
        _ videoId: String,
        isWatched newIsWatched: Bool,
        state: inout State
    ) -> Effect<Action> {
        let config = state.serverConfig
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
        deleteFromServer([video.videoId], state: state)
    }

    /// Each deletion reports on its own, so one failure doesn't hold back
    /// the rest from leaving the list.
    private func deleteFromServer(
        _ videoIds: [String],
        state: State
    ) -> Effect<Action> {
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

    /// Deletes what the list currently shows — the pages loaded so far, not
    /// every match on the server, which is why the menu says "shown".
    private func handleClearFilteredTapped(state: inout State) -> Effect<Action> {
        let count = state.filteredVideos.count
        guard count > 0 else { return .none }
        state.alert = .confirmDelete(count: count, action: .confirmClearFiltered)
        return .none
    }

    func handleConfirmClearFiltered(state: inout State) -> Effect<Action> {
        deleteFromServer(state.filteredVideos.map(\.videoId), state: state)
    }

    // MARK: - Selection

    private func endSelection(state: inout State) {
        state.isSelecting = false
        state.selectedVideoIDs = []
    }

    private func handleSelectAllTapped(state: inout State) -> Effect<Action> {
        if state.areAllVideosSelected {
            state.selectedVideoIDs = []
        } else {
            state.selectedVideoIDs = Set(state.filteredVideos.map(\.videoId))
        }
        return .none
    }

    private func handleMarkSelectedWatchedTapped(state: inout State) -> Effect<Action> {
        let isWatched = state.selectionMarksWatched
        let videoIds = state.selectedVideos
            .filter { $0.isWatched != isWatched }
            .map(\.videoId)
        endSelection(state: &state)
        var effects: [Effect<Action>] = []
        for videoId in videoIds {
            effects.append(setWatched(videoId, isWatched: isWatched, state: &state))
        }
        return .merge(effects)
    }

    private func handleDownloadSelectedToDeviceTapped(state: inout State) -> Effect<Action> {
        let downloadedIDs = state.downloadedVideoIDs
        let videos = state.selectedVideos.filter { !downloadedIDs.contains($0.videoId) }
        endSelection(state: &state)
        var effects: [Effect<Action>] = []
        for video in videos {
            effects.append(handleDownloadToDeviceTapped(video, state: &state))
        }
        return .merge(effects)
    }

    private func handleDeleteSelectedTapped(state: inout State) -> Effect<Action> {
        let count = state.selectedVideos.count
        guard count > 0 else { return .none }
        state.alert = .confirmDelete(count: count, action: .confirmDeleteSelected)
        return .none
    }

    func handleConfirmDeleteSelected(state: inout State) -> Effect<Action> {
        let videoIds = state.selectedVideos.map(\.videoId)
        endSelection(state: &state)
        return deleteFromServer(videoIds, state: state)
    }

    // MARK: - Sort and filter

    private func handleVideoSortOrderChanged(
        _ sort: VideoSortOrder,
        state: inout State
    ) -> Effect<Action> {
        guard sort != state.videoSortOrder else { return .none }
        state.videoSortOrder = sort
        return reloadVideos(state: &state)
    }

    private func handleVideoFilterChanged(
        _ filter: ChannelVideoFilter,
        state: inout State
    ) -> Effect<Action> {
        guard filter != state.videoFilter else { return .none }
        state.videoFilter = filter
        return reloadVideos(state: &state)
    }

    /// Starts the list over from page 1 for a new sort or filter.
    private func reloadVideos(state: inout State) -> Effect<Action> {
        state.videos = []
        state.currentPage = 1
        state.lastPage = 1
        state.hasLoadedVideos = false
        state.isLoadingVideos = true
        state.isLoadingMoreVideos = false
        // Cancels any page still loading for the previous sort or filter.
        return fetchVideos(page: 1, state: state)
    }
}

extension AlertState where Action == ChannelDetailReducer.AlertAction {
    /// Confirms deleting `count` videos from the server.
    static func confirmDelete(
        count: Int,
        action: ChannelDetailReducer.AlertAction
    ) -> Self {
        AlertState {
            TextState(String.localised("video.clearFiltered.title", table: .videos))
        } actions: {
            ButtonState(role: .cancel) {
                TextState(String.localised("generic.cancel", table: .generic))
            }
            ButtonState(role: .destructive, action: action) {
                TextState(String.localised("generic.delete", table: .generic))
            }
        } message: {
            TextState(String.localised("video.clearFiltered.message \(count)", table: .videos))
        }
    }
}
