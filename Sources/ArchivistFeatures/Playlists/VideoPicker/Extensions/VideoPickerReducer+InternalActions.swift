import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension VideoPickerReducer {
    public func handleInternalAction(_ action: Action, state: inout State) -> Effect<Action> {
        switch action {
        case .videosLoaded(let response):
            for video in response.data {
                state.videos.updateOrAppend(video)
            }
            state.currentPage = response.paginate.currentPage
            state.lastPage = response.paginate.lastPage
            state.isLoading = false
            state.isLoadingMore = false
            state.hasLoaded = true
            return .none
        case .videosFailed:
            state.isLoading = false
            state.isLoadingMore = false
            state.hasLoaded = true
            return .none
        case .downloadsLoaded(let response):
            for download in response.data {
                state.pendingDownloads.updateOrAppend(download)
            }
            state.isLoadingDownloads = false
            return .none
        case .downloadsFailed:
            state.isLoadingDownloads = false
            return .none
        case .searchResultsLoaded(let videos):
            state.searchResults = IdentifiedArrayOf(uniqueElements: videos)
            state.isSearching = false
            return .none
        case .searchFailed:
            state.isSearching = false
            return .none
        case .addSucceeded:
            state.isAdding = false
            let dismiss = self.dismiss
            return .run { _ in await dismiss() }
        case .addFailed:
            state.isAdding = false
            return .none
        default:
            return .none
        }
    }
}
