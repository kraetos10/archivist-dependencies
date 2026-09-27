import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension VideoPickerReducer {
    func handleInternalAction(
        _ action: Action,
        state: inout State
    ) -> Effect<Action> {
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
            state.updateDisplayedItems()
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
            state.updateDisplayedItems()
            return .none
        case .downloadsResult(.failure):
            state.isLoadingDownloads = false
            return .none
        case .searchResult(.success(let videos)):
            state.searchResults = IdentifiedArrayOf(uniqueElements: videos)
            state.isSearching = false
            state.updateDisplayedItems()
            return .none
        case .searchResult(.failure):
            state.isSearching = false
            return .none
        case .addFinished(let failedIds) where failedIds.isEmpty:
            state.isAdding = false
            let dismiss = self.dismiss
            return .run { send in
                await send(.delegate(.didAddVideos))
                await dismiss()
            }
        case .addFinished(let failedIds):
            state.isAdding = false
            let total = state.selectedVideoIds.count
            // Keep only what failed selected, so trying again doesn't add the
            // others a second time.
            state.selectedVideoIds.removeAll { !failedIds.contains($0) }
            state.alert = AlertState {
                TextState(String.localised("generic.error", table: .generic))
            } message: {
                TextState(
                    String.localised(
                        "playlist.addVideosFailed \(failedIds.count) \(total)",
                        table: .videos
                    )
                )
            }
            return .none
        default:
            return .none
        }
    }
}
