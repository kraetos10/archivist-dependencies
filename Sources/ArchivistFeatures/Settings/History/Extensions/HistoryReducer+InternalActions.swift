import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension HistoryReducer {
    func handleContinueVideosResult(
        _ result: Result<PaginatedResponse<VideoResponse>, Error>,
        state: inout State
    ) -> Effect<Action> {
        state.isLoadingContinue = false
        state.hasLoaded = true
        if case .success(let response) = result {
            state.continueVideos = uniqued(response.data)
        }
        return .none
    }

    func handleWatchedVideosResult(
        page: Int,
        _ result: Result<PaginatedResponse<VideoResponse>, Error>,
        state: inout State
    ) -> Effect<Action> {
        state.isLoadingWatched = false
        state.isLoadingMore = false
        state.hasLoaded = true
        guard case .success(let response) = result else { return .none }
        state.currentPage = response.paginate.currentPage
        state.lastPage = response.paginate.lastPage
        if page == 1 {
            state.watchedVideos = uniqued(response.data)
        } else {
            for video in response.data {
                state.watchedVideos.updateOrAppend(video)
            }
        }
        return .none
    }

    // MARK: - Private Helpers

    /// The server can repeat a video; `uniqueElements:` would trap on it.
    private func uniqued(_ videos: [VideoResponse]) -> IdentifiedArrayOf<VideoResponse> {
        var result: IdentifiedArrayOf<VideoResponse> = []
        for video in videos {
            result.updateOrAppend(video)
        }
        return result
    }
}
