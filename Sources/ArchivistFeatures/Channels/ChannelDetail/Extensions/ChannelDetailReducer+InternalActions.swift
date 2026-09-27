import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension ChannelDetailReducer {
    func handleInternalAction(
        _ action: Action,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .videosResult(.success(let response)):
            return handleVideosLoaded(response, state: &state)
        case .videosResult(.failure):
            return handleVideosFailed(state: &state)
        case .downloadsResult(.success(let response)):
            return handleDownloadsLoaded(response, state: &state)
        case .downloadsResult(.failure):
            state.isLoadingDownloads = false
            state.hasLoadedDownloads = true
            return .none
        case .deleteVideoResult(.success(let videoId)):
            state.videos.remove(id: videoId)
            return .none
        case .deleteVideoResult(.failure):
            state.alert = .failure(String.localised("video.deleteFailed", table: .videos))
            return .none
        case .queueDownloadResult(.success(let videoId)):
            state.pendingDownloads.remove(id: videoId)
            return .none
        case .queueDownloadResult(.failure):
            state.alert = .failure(String.localised("video.queueDownloadFailed", table: .videos))
            return .none
        case .setWatchedResult(_, _, .success):
            return .none
        case .setWatchedResult(let videoId, let isWatched, .failure):
            // Roll back the optimistic flip.
            if let video = state.videos[id: videoId] {
                state.videos[id: videoId] = video.settingWatched(!isWatched)
            }
            state.alert = .failure(String.localised("video.setWatchedFailed", table: .videos))
            return .none
        case .unsubscribeResult(.success):
            return .send(.delegate(.didUnsubscribe(state.channel.channelId)))
        case .unsubscribeResult(.failure):
            state.alert = .failure(String.localised("channel.unsubscribeFailed", table: .login))
            return .none
        case .refreshPendingDownloads:
            // Quiet reload: keep the current rows up until the new page lands.
            return fetchPendingDownloads(page: 1, state: state)
        default:
            return .none
        }
    }

    // MARK: - Fetching

    /// Every video page goes through here. A new request cancels the one in
    /// flight, so a page fetched for the previous sort order (or before a
    /// refresh) can never land on top of the current list.
    func fetchVideos(
        page: Int,
        state: State
    ) -> Effect<Action> {
        let config = state.serverConfig
        let channelId = state.channel.channelId
        let sort = state.videoSortOrder.apiValue
        let videoService = self.videoService
        return .run { send in
            let result = await Result {
                try await videoService.getVideos(
                    config: config,
                    page: page,
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
        .cancellable(id: CancelID.videos, cancelInFlight: true)
    }

    func fetchPendingDownloads(
        page: Int,
        state: State
    ) -> Effect<Action> {
        let config = state.serverConfig
        let channelId = state.channel.channelId
        let downloadService = self.downloadService
        return .run { send in
            let result = await Result {
                try await downloadService.getDownloads(
                    config: config,
                    page: page,
                    filter: "pending",
                    channel: channelId,
                    query: nil,
                    vidType: nil
                )
            }
            await send(.downloadsResult(result))
        }
        .cancellable(id: CancelID.downloads, cancelInFlight: true)
    }

    // MARK: - Private Handlers

    private func handleVideosLoaded(
        _ response: PaginatedResponse<VideoResponse>,
        state: inout State
    ) -> Effect<Action> {
        if response.paginate.currentPage <= 1 {
            // First page (initial load, refresh, sort change): replace, so new
            // uploads sit at the top and server-side deletions disappear.
            state.videos = IdentifiedArrayOf(uniqueElements: response.data)
        } else {
            for video in response.data {
                state.videos.updateOrAppend(video)
            }
        }
        state.currentPage = response.paginate.currentPage
        state.lastPage = response.paginate.lastPage
        state.isLoadingVideos = false
        state.isLoadingMoreVideos = false
        state.hasLoadedVideos = true

        // Filtering (e.g. "Unwatched") can thin the rendered list far below
        // the server's page size. If there are more pages, eagerly pull the
        // next one so the user doesn't see a short list with content still
        // off-screen. Recursion is implicit — the next page's response
        // re-enters `handleVideosLoaded` and re-checks the threshold, so
        // we keep pulling until either we hit `lastPage` or the filtered
        // list is full enough.
        //
        // `paginate.pageSize` can come back as 0 from the server in some
        // edge cases; floor it so we still attempt to fill at least 10
        // items before giving up.
        let fillTarget = max(response.paginate.pageSize, 10)
        if state.filteredVideos.count < fillTarget,
           state.currentPage < state.lastPage {
            state.isLoadingMoreVideos = true
            return fetchVideos(page: state.currentPage + 1, state: state)
        }

        return .none
    }

    private func handleVideosFailed(state: inout State) -> Effect<Action> {
        state.isLoadingVideos = false
        state.isLoadingMoreVideos = false
        state.hasLoadedVideos = true
        return .none
    }

    private func handleDownloadsLoaded(
        _ response: PaginatedResponse<DownloadResponse>,
        state: inout State
    ) -> Effect<Action> {
        let lastPage = response.paginate.lastPage

        // When showing newest first, fetch the last page to get the most
        // recent additions. That page's response has `currentPage > 1`, so
        // this only ever runs once per load.
        if state.showNewestDownloadsFirst,
           lastPage > 1,
           response.paginate.currentPage == 1 {
            return fetchPendingDownloads(page: lastPage, state: state)
        }

        if state.showNewestDownloadsFirst {
            state.pendingDownloads = IdentifiedArrayOf(uniqueElements: response.data.reversed())
        } else {
            state.pendingDownloads = IdentifiedArrayOf(uniqueElements: response.data)
        }
        state.isLoadingDownloads = false
        state.hasLoadedDownloads = true
        return .none
    }

    func handleDownloadDetailFinished(
        _ youtubeId: String,
        state: inout State
    ) -> Effect<Action> {
        // The detail screen dismisses itself; only the row is ours to drop.
        state.pendingDownloads.remove(id: youtubeId)
        return .none
    }

    func handleUnsubscribeConfirmed(state: inout State) -> Effect<Action> {
        let config = state.serverConfig
        let channelId = state.channel.channelId
        let channelService = self.channelService
        return .run { send in
            let result = await Result {
                try await channelService.deleteChannel(config: config, id: channelId)
            }
            await send(.unsubscribeResult(result))
        }
    }

    func handleConfirmDownload(
        _ videoId: String,
        state: inout State
    ) -> Effect<Action> {
        let config = state.serverConfig
        let downloadService = self.downloadService
        return .run { send in
            let result = await Result {
                try await downloadService.updateDownload(
                    config: config,
                    id: videoId,
                    status: "priority"
                )
            }
            await send(.queueDownloadResult(result.map { videoId }), animation: .default)
        }
    }
}

extension AlertState where Action == ChannelDetailReducer.AlertAction {
    /// An error alert with just an OK button.
    static func failure(_ message: String) -> Self {
        AlertState {
            TextState(String.localised("generic.error", table: .generic))
        } message: {
            TextState(message)
        }
    }
}
