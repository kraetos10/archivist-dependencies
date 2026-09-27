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
            return handleDeleteFromServer(video, state: &state)
        case .watchFilterChanged(let filter):
            return handleWatchFilterChanged(filter, state: &state)
        case .addToPlaylistTapped(let video):
            return handleAddToPlaylistTapped(video, state: &state)
        case .markAsWatchedTapped(let video):
            return handleMarkAsWatched(video, state: &state)
        case .playNextTapped(let video):
            return handlePlayNextTapped(video, state: &state)
        case .addVideoTapped:
            state.destination = .addVideo(AddVideoReducer.State(serverConfig: state.serverConfig))
            return .none
        case .viewAllTapped(let filter):
            state.path.append(
                .filteredList(FilteredVideoListReducer.State(
                    serverConfig: state.serverConfig,
                    filter: filter
                ))
            )
            return .none
        }
    }

    // MARK: - Handlers

    private func handleOnAppear(state: inout State) -> Effect<Action> {
        // downloadedVideoIDs is reactive via @FetchAll — no manual refresh needed
        guard state.videos.isEmpty, !state.isLoading else { return .none }
        return fetchPage(1, state: &state)
    }

    func handleRefreshTriggered(state: inout State) -> Effect<Action> {
        fetchPage(1, state: &state)
    }

    private func handleLoadNextPage(state: inout State) -> Effect<Action> {
        guard state.currentPage < state.lastPage,
              !state.isLoading,
              !state.isLoadingMore
        else { return .none }
        return fetchPage(state.currentPage + 1, state: &state)
    }

    /// Fetches one page. Page 1 is a full refresh: it replaces the list when
    /// it lands (see `handleVideosLoaded`). Every fetch shares one cancel ID
    /// with `cancelInFlight`, so a refresh cancels a page still loading and
    /// only the latest request's response can arrive.
    func fetchPage(
        _ page: Int,
        state: inout State
    ) -> Effect<Action> {
        if page == 1 {
            state.isLoading = true
            state.isLoadingMore = false
        } else {
            state.isLoadingMore = true
        }
        let config = state.serverConfig
        let sort = state.sortOrder.apiValue
        return .run { [videoService] send in
            let result = await Result {
                try await videoService.getVideos(
                    config: config,
                    page: page,
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
        .cancellable(id: CancelID.fetchVideos, cancelInFlight: true)
    }

    private func handleWatchFilterChanged(
        _ filter: WatchFilter,
        state: inout State
    ) -> Effect<Action> {
        if filter == .downloaded && state.watchFilter == .downloaded {
            state.$watchFilter.withLock { $0 = .unwatched }
            return .none
        }
        state.$watchFilter.withLock { $0 = filter }
        guard filter == .downloaded else { return .none }

        // downloadedVideoIDs is reactive via @FetchAll
        // Fetch video details for downloaded IDs not already in the loaded pages
        let loadedIDs = Set(state.videos.map(\.videoId))
        let missingIDs = state.downloadedVideoIDs.subtracting(loadedIDs)
        guard !missingIDs.isEmpty else { return .none }

        let config = state.serverConfig
        return .run { [videoService] send in
            let fetched = await withTaskGroup(of: VideoResponse?.self) { group in
                for id in missingIDs {
                    group.addTask {
                        try? await videoService.getVideo(config: config, id: id)
                    }
                }
                var videos: [VideoResponse] = []
                for await video in group {
                    if let video { videos.append(video) }
                }
                return videos
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
            nextVideos = displayed[displayed.index(after: index)...]
                .map(\.video)
                .filter { !$0.isWatched }
        } else {
            nextVideos = []
        }
        @Shared(.autoPlayEnabled) var autoPlayEnabled
        let detailState = VideoDetailReducer.State(
            serverConfig: state.serverConfig,
            video: video,
            nextVideos: nextVideos,
            shouldAutoPlayNextVideo: autoPlayEnabled
        )
        #if os(tvOS)
        state.path.append(.videoDetail(detailState))
        #else
        state.destination = .videoDetail(detailState)
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
        let download = DeviceDownload(
            id: videoId,
            title: title,
            channelName: video.channelName,
            thumbUrl: video.vidThumbUrl,
            status: .downloading,
            progress: 0,
            fileSize: video.mediaSize,
            createdAt: now.timeIntervalSince1970
        )
        let thumbnailURL = video.vidThumbUrl.flatMap { state.serverConfig.fullURL(for: $0) }
        let authHeaders = state.serverConfig.authHeaders
        let expectedSize = video.mediaSize.map { Int64($0) }
        return .run { [deviceDownloadDatabase, persistentDownloadManager] _ in
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
        return .run { [localVideoStorage, deviceDownloadDatabase] _ in
            try? localVideoStorage.deleteVideo(videoId: videoId)
            try? deviceDownloadDatabase.deleteDownload(videoId)
        }
    }

    private func handleAddToPlaylistTapped(
        _ video: VideoResponse,
        state: inout State
    ) -> Effect<Action> {
        state.destination = .playlistPicker(PlaylistPickerReducer.State(
            serverConfig: state.serverConfig,
            videoId: video.videoId
        ))
        return .none
    }

    /// Deletes the video on the server. Shared by the context menu, the
    /// "View All" lists and tvOS Search (through `.deleteFromServer`).
    func handleDeleteFromServer(
        _ video: VideoResponse,
        state: inout State
    ) -> Effect<Action> {
        let config = state.serverConfig
        let videoId = video.videoId
        return .run { [videoService] send in
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
        .run { [playNextDatabase] _ in
            try? await playNextDatabase.addToQueue(video)
        }
    }

    /// Flips the video's watched state on the server. Shared by the context
    /// menu, the "View All" lists and tvOS Search (through `.markAsWatched`).
    func handleMarkAsWatched(
        _ video: VideoResponse,
        state: inout State
    ) -> Effect<Action> {
        let config = state.serverConfig
        let videoId = video.videoId
        let newIsWatched = !video.isWatched
        return .run { [videoService] send in
            let result = await Result {
                try await videoService.setWatched(
                    config: config,
                    videoId: videoId,
                    isWatched: newIsWatched
                )
            }
            await send(.markWatchedResult(result.map { videoId }))
        }
    }
}
