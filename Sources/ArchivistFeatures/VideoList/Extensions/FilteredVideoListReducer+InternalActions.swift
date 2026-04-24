import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension FilteredVideoListReducer {
    public func handleInternalAction(
        _ action: Action,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .videosResult(.success(let response)):
            return handleVideosLoaded(response, state: &state)
        case .videosResult(.failure):
            return handleVideosFailed(state: &state)
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
        state.isLoading = false
        state.isLoadingMore = false
        state.hasLoaded = true

        // Mirror the channel-detail trick: if client-side filtering thinned
        // the page below the server's page size, eagerly pull the next page
        // so the user isn't left with a sparse list.
        if state.displayedVideos.count < response.paginate.pageSize,
           state.currentPage < state.lastPage,
           !state.isLoadingMore {
            state.isLoadingMore = true
            return fetchPage(state.currentPage + 1, state: &state)
        }
        return .none
    }

    private func handleVideosFailed(state: inout State) -> Effect<Action> {
        state.isLoading = false
        state.isLoadingMore = false
        state.hasLoaded = true
        return .none
    }
}
