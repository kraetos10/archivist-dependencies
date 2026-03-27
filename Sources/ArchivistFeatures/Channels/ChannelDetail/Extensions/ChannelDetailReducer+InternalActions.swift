import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension ChannelDetailReducer {
    public func handleInternalAction(_ action: Action, state: inout State) -> Effect<Action> {
        switch action {
        case .videosLoaded(let response):
            return handleVideosLoaded(response, state: &state)
        case .videosFailed:
            return handleVideosFailed(state: &state)
        case .downloadsLoaded(let response):
            return handleDownloadsLoaded(response, state: &state)
        case .downloadsFailed:
            state.isLoadingDownloads = false
            state.hasLoadedDownloads = true
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
        state.pendingDownloads = IdentifiedArrayOf(uniqueElements: response.data)
        state.pendingDownloads.sort { lhs, rhs in
            (lhs.published ?? "") > (rhs.published ?? "")
        }
        state.isLoadingDownloads = false
        state.hasLoadedDownloads = true
        return .none
    }

    public func handleUnsubscribeConfirmed(state: inout State) -> Effect<Action> {
        let config = state.serverConfig
        let channelId = state.channel.channelId
        return .run { send in
            do {
                try await channelService.deleteChannel(config: config, id: channelId)
                await send(.unsubscribeCompleted)
            } catch {
                await send(.unsubscribeFailed)
            }
        }
    }
}
