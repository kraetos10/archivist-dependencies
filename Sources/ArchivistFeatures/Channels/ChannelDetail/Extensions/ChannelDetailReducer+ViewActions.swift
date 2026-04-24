import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension ChannelDetailReducer {
    public func handleViewAction(
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
        let config = state.serverConfig
        let channelId = state.channel.channelId

        var effects: [Effect<Action>] = []

        if state.videos.isEmpty, !state.isLoadingVideos {
            state.isLoadingVideos = true
            let sort = state.videoSortOrder.apiValue
            effects.append(
                .run { send in
                    let result = await Result {
                        try await videoService.getVideos(
                            config: config,
                            page: 1,
                            sort: sort,
                            order: "desc",
                            type: nil,
                            watch: nil,
                            channel: channelId,
                            playlist: nil
                        )
                    }
                    await send(.videosResult(result))
                }
            )
        }

        if state.pendingDownloads.isEmpty, !state.isLoadingDownloads {
            state.isLoadingDownloads = true
            effects.append(
                .run { send in
                    let result = await Result {
                        try await downloadService.getDownloads(
                            config: config,
                            page: 1,
                            filter: "pending",
                            channel: channelId,
                            query: nil,
                            vidType: nil
                        )
                    }
                    await send(.downloadsResult(result))
                }
            )
        }

        return .merge(effects)
    }

    private func handlePullToRefreshTriggered(state: inout State) -> Effect<Action> {
        state.isLoadingVideos = true
        state.isLoadingDownloads = true
        state.currentPage = 1
        let config = state.serverConfig
        let channelId = state.channel.channelId
        let sort = state.videoSortOrder.apiValue
        return .merge(
            .run { send in
                let result = await Result {
                    try await videoService.getVideos(
                        config: config,
                        page: 1,
                        sort: sort,
                        order: "desc",
                        type: nil,
                        watch: nil,
                        channel: channelId,
                        playlist: nil
                    )
                }
                await send(.videosResult(result))
            },
            .run { send in
                let result = await Result {
                    try await downloadService.getDownloads(
                        config: config,
                        page: 1,
                        filter: "pending",
                        channel: channelId,
                        query: nil,
                        vidType: nil
                    )
                }
                await send(.downloadsResult(result))
            }
        )
    }

    private func handleLastVideoAppeared(state: inout State) -> Effect<Action> {
        guard state.currentPage < state.lastPage, !state.isLoadingMoreVideos else { return .none }
        state.isLoadingMoreVideos = true
        let config = state.serverConfig
        let channelId = state.channel.channelId
        let nextPage = state.currentPage + 1
        let sort = state.videoSortOrder.apiValue
        return .run { send in
            let result = await Result {
                try await videoService.getVideos(
                    config: config,
                    page: nextPage,
                    sort: sort,
                    order: "desc",
                    type: nil,
                    watch: nil,
                    channel: channelId,
                    playlist: nil
                )
            }
            await send(.videosResult(result))
        }
    }

    private func handleVideoCardTapped(
        _ video: VideoResponse,
        state: inout State
    ) -> Effect<Action> {
        let nextVideos: [VideoResponse]
        if let index = state.videos.firstIndex(where: { $0.id == video.id }) {
            nextVideos = Array(state.videos.suffix(from: state.videos.index(after: index)).filter { !$0.isWatched })
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
        state.alert = AlertState {
            TextState(String.localised("generic.unsubscribe", table: .generic))
        } actions: {
            ButtonState(role: .cancel) {
                TextState(String.localised("generic.cancel", table: .generic))
            }
            ButtonState(role: .destructive, action: .confirmUnsubscribe) {
                TextState(String.localised("generic.unsubscribe", table: .generic))
            }
        } message: { [state] in
            TextState(
                String.localised(
                    "Are you sure you want to unsubscribe from \(state.channel.channelName)?",
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
        let authHeaders = state.serverConfig.authHeaders
        let expectedSize = video.mediaSize.map { Int64($0) }
        let expectedSizeInt = video.mediaSize
        return .run { _ in
            let download = DeviceDownload(
                id: videoId,
                title: title,
                channelName: channelName,
                thumbUrl: thumbUrl,
                status: .downloading,
                progress: 0,
                fileSize: expectedSizeInt,
                createdAt: Date().timeIntervalSince1970
            )
            try? deviceDownloadDatabase.insertDownload(download)
            await persistentDownloadManager.startDownload(
                url: mediaURL,
                videoId: videoId,
                title: title,
                expectedSize: expectedSize,
                authHeaders: authHeaders
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

    private func handleMarkAsWatchedTapped(
        _ video: VideoResponse,
        state: inout State
    ) -> Effect<Action> {
        let config = state.serverConfig
        let videoId = video.videoId
        let newIsWatched = !video.isWatched
        return .run { _ in
            try? await videoService.setWatched(
                config: config,
                videoId: videoId,
                isWatched: newIsWatched
            )
        }
    }

    private func handleDeleteFromServerTapped(
        _ video: VideoResponse,
        state: inout State
    ) -> Effect<Action> {
        let config = state.serverConfig
        let videoId = video.videoId
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
        return .run { [playNextDatabase] _ in
            try? await playNextDatabase.addToQueue(video)
        }
    }

    private func handleDownloadSortToggled(state: inout State) -> Effect<Action> {
        state.showNewestDownloadsFirst.toggle()
        state.pendingDownloads = []
        state.hasLoadedDownloads = false
        state.isLoadingDownloads = true

        let config = state.serverConfig
        let channelId = state.channel.channelId
        return .run { send in
            let result = await Result {
                try await downloadService.getDownloads(
                    config: config,
                    page: 1,
                    filter: "pending",
                    channel: channelId,
                    query: nil,
                    vidType: nil
                )
            }
            await send(.downloadsResult(result))
        }
    }

    private func handleClearFilteredTapped(state: inout State) -> Effect<Action> {
        let count = state.filteredVideos.count
        guard count > 0 else { return .none }
        let message = state.videoFilter == .unwatched
            ? String(localized: "Delete all \(count) unwatched videos in this channel from the server? This cannot be undone.")
            : String(localized: "Delete all \(count) videos in this channel from the server? This cannot be undone.")
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
        let config = state.serverConfig
        let channelId = state.channel.channelId
        return .run { send in
            let result = await Result {
                try await videoService.getVideos(
                    config: config,
                    page: 1,
                    sort: sort.apiValue,
                    order: "desc",
                    type: nil,
                    watch: nil,
                    channel: channelId,
                    playlist: nil
                )
            }
            await send(.videosResult(result))
        }
    }
}
