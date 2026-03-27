import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension HistoryReducer {
    public func handleInternalAction(_ action: Action, state: inout State) -> Effect<Action> {
        switch action {
        case .continueVideosLoaded(let response):
            state.continueVideos = IdentifiedArrayOf(uniqueElements: response.data)
            state.isLoading = false
            state.hasLoaded = true
            return .none
        case .watchedVideosLoaded(let response):
            state.currentPage = response.paginate.currentPage
            state.lastPage = response.paginate.lastPage
            for video in response.data {
                state.watchedVideos.updateOrAppend(video)
            }
            state.isLoading = false
            state.isLoadingMore = false
            state.hasLoaded = true
            return .none
        case .videosFailed:
            state.isLoading = false
            state.isLoadingMore = false
            state.hasLoaded = true
            return .none
        default:
            return .none
        }
    }
}
