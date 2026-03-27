import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension VideoPickerReducer {
    public func handleInternalAction(_ action: Action, state: inout State) -> Effect<Action> {
        switch action {
        case .videosResult(.success(let response)):
            for video in response.data {
                state.videos.updateOrAppend(video)
            }
            state.currentPage = response.paginate.currentPage
            state.lastPage = response.paginate.lastPage
            state.isLoading = false
            state.isLoadingMore = false
            state.hasLoaded = true
            return .none
        case .videosResult(.failure):
            state.isLoading = false
            state.isLoadingMore = false
            state.hasLoaded = true
            return .none
        case .downloadsResult(.success(let response)):
            for download in response.data {
                state.pendingDownloads.updateOrAppend(download)
            }
            state.isLoadingDownloads = false
            return .none
        case .downloadsResult(.failure):
            state.isLoadingDownloads = false
            return .none
        case .searchResult(.success(let videos)):
            state.searchResults = IdentifiedArrayOf(uniqueElements: videos)
            state.isSearching = false
            return .none
        case .searchResult(.failure):
            state.isSearching = false
            return .none
        case .addResult(.success):
            state.isAdding = false
            let dismiss = self.dismiss
            return .run { _ in await dismiss() }
        case .addResult(.failure):
            state.isAdding = false
            return .none
        default:
            return .none
        }
    }
}
