import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension PlaylistPickerReducer {
    func handleInternalAction(
        _ action: Action,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .loadResult(.success(let page)):
            if page.currentPage <= 1 {
                state.playlists = IdentifiedArrayOf(uniqueElements: page.playlists)
                state.alreadyInPlaylistIds = page.containingVideo
            } else {
                for playlist in page.playlists {
                    state.playlists.updateOrAppend(playlist)
                }
                state.alreadyInPlaylistIds.formUnion(page.containingVideo)
            }
            state.currentPage = page.currentPage
            state.lastPage = page.lastPage
            state.isLoading = false
            state.isLoadingMore = false
            return .none
        case .loadResult(.failure):
            state.isLoading = false
            state.isLoadingMore = false
            return .none
        case .addResult(.success):
            state.isAdding = false
            let dismiss = self.dismiss
            return .run { _ in
                await dismiss()
            }
        case .addResult(.failure):
            state.isAdding = false
            state.alert = AlertState {
                TextState(String.localised("generic.error", table: .generic))
            } message: {
                TextState(String.localised("playlist.addVideoFailed", table: .videos))
            }
            return .none
        default:
            return .none
        }
    }
}
