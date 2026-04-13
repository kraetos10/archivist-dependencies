import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
import Foundation

extension VideoListReducer {
    public func handleViewAction(
        _ action: Action.View,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .viewDidAppear:
            return handleOnAppear(state: &state)
        case .pullToRefreshTriggered:
            return handleRefreshTriggered(state: &state)
        case .lastItemAppeared:
            return handleLoadNextPage(state: &state)
        case .videoTapped(let video):
            return handleVideoTapped(video, state: &state)
        case .downloadToDeviceTapped(let video):
            return handleDownloadToDeviceTapped(video, state: &state)
        case .deleteFromDeviceTapped(let video):
            return handleDeleteFromDeviceTapped(video, state: &state)
        case .deleteFromServerTapped(let video):
            return handleDeleteFromServerTapped(video, state: &state)
        case .watchFilterChanged(let filter):
            return handleWatchFilterChanged(filter, state: &state)
        case .addToPlaylistTapped(let video):
            return handleAddToPlaylistTapped(video, state: &state)
        case .markAsWatchedTapped(let video):
            return handleMarkAsWatchedTapped(video, state: &state)
        case .playNextTapped(let video):
            return handlePlayNextTapped(video, state: &state)
        case .addVideoTapped:
            state.addVideo = AddVideoReducer.State(serverConfig: state.serverConfig)
            return .none
        case .splitViewEnabled:
            state.useSplitView = true
            return .none
        case .sortOrderChanged(let sort):
            return handleSortOrderChanged(sort, state: &state)
        }
    }

    // MARK: - Private Handlers

    private func handleOnAppear(state: inout State) -> Effect<Action> {
        // downloadedVideoIDs is now reactive via @FetchAll — no manual refresh needed
        guard state.videos.isEmpty, !state.isLoading else { return .none }
        state.isLoading = true
        let config = state.serverConfig
        let sort = state.sortOrder.apiValue
        let videoService = self.videoService
        return .run { [videoService] send in
            let result = await Result {
                try await videoService.getVideos(
                    config: config,
                    page: 1,
                    sort: sort,
                    order: "desc",
                    type: nil,
                    watch: nil,
                    channel: nil,
                    playlist: nil
                )
            }
            await send(.videosResult(result))
        }
    }

    private func handleRefreshTriggered(state: inout State) -> Effect<Action> {
        state.isLoading = true
        state.isLoadingMore = false
        let config = state.serverConfig
        let sort = state.sortOrder.apiValue
        return .run { [videoService] send in
            let result = await Result {
                try await videoService.getVideos(
                    config: config,
                    page: 1,
                    sort: sort,
                    order: "desc",
                    type: nil,
                    watch: nil,
                    channel: nil,
                    playlist: nil
                )
            }
            await send(.videosResult(result))
        }
    }

    private func handleLoadNextPage(state: inout State) -> Effect<Action> {
        guard state.currentPage < state.lastPage, !state.isLoadingMore else { return .none }
        state.isLoadingMore = true
        let config = state.serverConfig
        let nextPage = state.currentPage + 1
        let sort = state.sortOrder.apiValue
        return .run { [videoService] send in
            let result = await Result {
                try await videoService.getVideos(
                    config: config,
                    page: nextPage,
                    sort: sort,
                    order: "desc",
                    type: nil,
                    watch: nil,
                    channel: nil,
                    playlist: nil
                )
            }
            await send(.videosResult(result))
        }
    }

    private func handleWatchFilterChanged(
        _ filter: WatchFilter,
        state: inout State
    ) -> Effect<Action> {
        if filter == .downloaded && state.watchFilter == .downloaded {
            state.watchFilter = .unwatched
            return .none
        }
        state.watchFilter = filter
        guard filter == .downloaded else { return .none }

        // downloadedVideoIDs is reactive via @FetchAll
        // Fetch video details for downloaded IDs not already in the loaded pages
        let loadedIDs = Set(state.videos.map(\.videoId))
        let missingIDs = state.downloadedVideoIDs.subtracting(loadedIDs)
        guard !missingIDs.isEmpty else { return .none }

        let config = state.serverConfig
        return .run { [videoService] send in
            var fetched: [VideoResponse] = []
            for id in missingIDs {
                if let video = try? await videoService.getVideo(config: config, id: id) {
                    fetched.append(video)
                }
            }
            await send(.downloadedVideosLoaded(fetched))
        }
    }

    private func handleVideoTapped(
        _ video: VideoResponse,
        state: inout State
    ) -> Effect<Action> {
        let displayed = state.displayedVideos
        let nextVideos: [VideoResponse]
        if let index = displayed.firstIndex(where: { $0.video.videoId == video.videoId }) {
            nextVideos = Array(
                displayed.suffix(
                    from: displayed.index(
                        after: index
                    )
                ).map(\.video).filter { !$0.isWatched })
        } else {
            nextVideos = []
        }
        @Shared(.appStorage("autoPlayEnabled")) var autoPlayEnabled = true
        let detailState = VideoDetailReducer.State(
            serverConfig: state.serverConfig,
            video: video,
            nextVideos: nextVideos,
            shouldAutoPlayNextVideo: autoPlayEnabled
        )
        #if os(tvOS)
        state.path.append(.videoDetail(detailState))
        #else
        state.videoDetail = detailState
        #endif
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
        return .run { [deviceDownloadDatabase, persistentDownloadManager] _ in
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
                url: mediaURL, videoId: videoId, title: title, expectedSize: expectedSize, authHeaders: authHeaders
            )
        }
    }

    private func handleDeleteFromDeviceTapped(
        _ video: VideoResponse,
        state: inout State
    ) -> Effect<Action> {
        let videoId = video.videoId
        return .run { [localVideoStorage, deviceDownloadDatabase] _ in
            try? localVideoStorage.deleteVideo(videoId: videoId)
            try? deviceDownloadDatabase.deleteDownload(videoId)
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
            await send(.contextDeleteResult(result.map { videoId }))
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

    private func handleMarkAsWatchedTapped(
        _ video: VideoResponse,
        state: inout State
    ) -> Effect<Action> {
        let config = state.serverConfig
        let videoId = video.videoId
        return .run { [videoService] send in
            let result = await Result {
                try await videoService.setWatched(config: config, videoId: videoId, isWatched: true)
            }
            await send(.markWatchedResult(result.map { videoId }))
        }
    }

    private func handleSortOrderChanged(
        _ sort: VideoSortOrder,
        state: inout State
    ) -> Effect<Action> {
        guard sort != state.sortOrder else { return .none }
        state.sortOrder = sort
        state.videos = []
        state.currentPage = 1
        state.lastPage = 1
        state.hasLoaded = false
        state.isLoading = true
        let config = state.serverConfig
        return .run { [videoService] send in
            let result = await Result {
                try await videoService.getVideos(
                    config: config,
                    page: 1,
                    sort: sort.apiValue,
                    order: "desc",
                    type: nil,
                    watch: nil,
                    channel: nil,
                    playlist: nil
                )
            }
            await send(.videosResult(result))
        }
    }
}
