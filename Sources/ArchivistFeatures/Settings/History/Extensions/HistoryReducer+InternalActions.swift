import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension HistoryReducer {
    public func handleInternalAction(
        _ action: Action,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .continueVideosResult(.success(let response)):
            state.continueVideos = IdentifiedArrayOf(uniqueElements: response.data)
            state.isLoading = false
            state.hasLoaded = true
            return .none
        case .continueVideosResult(.failure):
            state.isLoading = false
            state.hasLoaded = true
            return .none
        case .watchedVideosResult(.success(let response)):
            state.currentPage = response.paginate.currentPage
            state.lastPage = response.paginate.lastPage
            if state.isLoading {
                state.watchedVideos = IdentifiedArrayOf(uniqueElements: response.data)
            } else {
                for video in response.data {
                    state.watchedVideos.updateOrAppend(video)
                }
            }
            state.isLoading = false
            state.isLoadingMore = false
            state.hasLoaded = true
            return .none
        case .watchedVideosResult(.failure):
            state.isLoading = false
            state.isLoadingMore = false
            state.hasLoaded = true
            return .none
        default:
            return .none
        }
    }
}
