import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension VideoListReducer {
    public func handleViewAction(_ action: Action.View, state: inout State) -> Effect<Action> {
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
        case .deleteFromServerTapped(let video):
            return handleDeleteFromServerTapped(video, state: &state)
        case .watchFilterChanged(let filter):
            return handleWatchFilterChanged(filter, state: &state)
        case .downloadedFilterTapped:
            return handleDownloadedFilterTapped(state: &state)
        case .addToPlaylistTapped(let video):
            return handleAddToPlaylistTapped(video, state: &state)
        case .markAsWatchedTapped(let video):
            return handleMarkAsWatchedTapped(video, state: &state)
        case .playNextTapped(let video):
            return handlePlayNextTapped(video, state: &state)
        case .addVideoTapped:
            state.addVideo = AddVideoReducer.State(serverConfig: state.serverConfig)
            return .none
        }
    }

    // MARK: - Private Handlers

    private func handleOnAppear(state: inout State) -> Effect<Action> {
        guard state.videos.isEmpty, !state.isLoading else { return .none }
        state.isLoading = true
        let config = state.serverConfig
        let videoService = self.videoService
        return .run { send in
            do {
                let response = try await videoService.getVideos(
                    config: config,
                    page: 1,
                    sort: "published",
                    order: "desc",
                    type: nil,
                    watch: nil,
                    channel: nil,
                    playlist: nil
                )
                await send(.videosLoaded(response))
            } catch {
                await send(.videosFailed(error))
            }
        }
    }

    private func handleRefreshTriggered(state: inout State) -> Effect<Action> {
        guard !state.isLoading else { return .none }
        state.isLoading = true
        state.currentPage = 1
        let config = state.serverConfig
        let videoService = self.videoService
        return .run { send in
            do {
                let response = try await videoService.getVideos(
                    config: config,
                    page: 1,
                    sort: "published",
                    order: "desc",
                    type: nil,
                    watch: nil,
                    channel: nil,
                    playlist: nil
                )
                await send(.videosLoaded(response))
            } catch {
                await send(.videosFailed(error))
            }
        }
    }

    private func handleLoadNextPage(state: inout State) -> Effect<Action> {
        guard state.currentPage < state.lastPage, !state.isLoadingMore else { return .none }
        state.isLoadingMore = true
        let config = state.serverConfig
        let nextPage = state.currentPage + 1
        let videoService = self.videoService
        return .run { send in
            do {
                let response = try await videoService.getVideos(
                    config: config,
                    page: nextPage,
                    sort: "published",
                    order: "desc",
                    type: nil,
                    watch: nil,
                    channel: nil,
                    playlist: nil
                )
                await send(.videosLoaded(response))
            } catch {
                await send(.videosFailed(error))
            }
        }
    }

    private func handleWatchFilterChanged(_ filter: WatchFilter, state: inout State) -> Effect<Action> {
        state.watchFilter = filter
        state.showDownloadedOnly = false
        return .none
    }

    private func handleDownloadedFilterTapped(state: inout State) -> Effect<Action> {
        state.showDownloadedOnly.toggle()
        if state.showDownloadedOnly {
            state.downloadedVideoIDs = Set(
                state.videos.map(\.videoId).filter { localVideoStorage.isDownloaded(videoId: $0) }
            )
        }
        return .none
    }

    private func handleVideoTapped(_ video: VideoResponse, state: inout State) -> Effect<Action> {
        let displayed = state.displayedVideos
        let nextVideos: [VideoResponse]
        if let index = displayed.firstIndex(where: { $0.id == video.id }) {
            nextVideos = Array(displayed.suffix(from: displayed.index(after: index)).filter { !$0.isWatched })
        } else {
            nextVideos = []
        }
        let detailState = VideoDetailReducer.State(
            serverConfig: state.serverConfig,
            video: video,
            nextVideos: nextVideos
        )
        #if os(tvOS)
        state.path.append(.videoDetail(detailState))
        #else
        state.videoDetail = detailState
        #endif
        return .none
    }

    private func handleDownloadToDeviceTapped(_ video: VideoResponse, state: inout State) -> Effect<Action> {
        guard let mediaPath = video.mediaUrl,
              let mediaURL = state.serverConfig.fullURL(for: mediaPath) else {
            return .none
        }
        let videoId = video.videoId
        let title = video.title
        let channelName = video.channelName
        let thumbUrl = video.vidThumbUrl
        let authHeaders = state.serverConfig.authHeaders
        return .run { [persistentDownloadManager] _ in
            @Dependency(\.deviceDownloadDatabase) var deviceDownloadDatabase

            let download = DeviceDownload(
                id: videoId,
                title: title,
                channelName: channelName,
                thumbUrl: thumbUrl,
                status: .downloading,
                progress: 0,
                createdAt: Date().timeIntervalSince1970
            )
            try? deviceDownloadDatabase.insertDownload(download)

            await persistentDownloadManager.startDownload(
                url: mediaURL, videoId: videoId, title: title, authHeaders: authHeaders
            )
        }
    }

    private func handleAddToPlaylistTapped(_ video: VideoResponse, state: inout State) -> Effect<Action> {
        state.playlistPicker = PlaylistPickerReducer.State(
            serverConfig: state.serverConfig,
            videoId: video.videoId
        )
        return .none
    }

    private func handleDeleteFromServerTapped(_ video: VideoResponse, state: inout State) -> Effect<Action> {
        let config = state.serverConfig
        let videoId = video.videoId
        let videoService = self.videoService
        return .run { send in
            do {
                try await videoService.deleteVideo(config: config, id: videoId)
                await send(.contextDeleteCompleted(videoId))
            } catch {
                await send(.contextDeleteFailed(error))
            }
        }
    }

    private func handlePlayNextTapped(_ video: VideoResponse, state: inout State) -> Effect<Action> {
        return .run { [playNextDatabase] _ in
            try? await playNextDatabase.addToQueue(video)
        }
    }

    private func handleMarkAsWatchedTapped(_ video: VideoResponse, state: inout State) -> Effect<Action> {
        let config = state.serverConfig
        let videoId = video.videoId
        let videoService = self.videoService
        return .run { send in
            try await videoService.setWatched(config: config, videoId: videoId, isWatched: true)
            await send(.markWatchedCompleted(videoId))
        } catch: { _, send in
            await send(.markWatchedFailed)
        }
    }
}
