import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension ChannelDetailReducer {
    public func handleInternalAction(
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
            return .none
        default:
            return .none
        }
    }

    // MARK: - Private Handlers

    private func handleVideosLoaded(
        _ response: PaginatedResponse<VideoResponse>,
        state: inout State
    ) -> Effect<Action> {
        for video in response.data {
            state.videos.updateOrAppend(video)
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
           state.currentPage < state.lastPage,
           !state.isLoadingMoreVideos {
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

        // When showing newest first, fetch the last page to get the most recent additions
        if state.showNewestDownloadsFirst
            && state.isLoadingDownloads
            && lastPage > 1
            && response.paginate.currentPage == 1 {
            let config = state.serverConfig
            let channelId = state.channel.channelId
            return .run { send in
                let result = await Result {
                    try await downloadService.getDownloads(
                        config: config,
                        page: lastPage,
                        filter: "pending",
                        channel: channelId,
                        query: nil,
                        vidType: nil
                    )
                }
                await send(.downloadsResult(result))
            }
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

    public func handleUnsubscribeConfirmed(state: inout State) -> Effect<Action> {
        let config = state.serverConfig
        let channelId = state.channel.channelId
        return .run { send in
            let result = await Result {
                try await channelService.deleteChannel(config: config, id: channelId)
            }
            await send(.unsubscribeResult(result))
        }
    }
}
