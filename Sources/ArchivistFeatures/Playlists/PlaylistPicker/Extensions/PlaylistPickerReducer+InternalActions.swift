import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension PlaylistPickerReducer {
    public func handleInternalAction(_ action: Action, state: inout State) -> Effect<Action> {
        switch action {
        case .playlistsLoaded(let playlists, let alreadyIn):
            state.playlists = playlists
            state.alreadyInPlaylistIds = alreadyIn
            state.isLoading = false
            return .none
        case .loadFailed:
            state.isLoading = false
            return .none
        case .addSucceeded:
            state.isAdding = false
            let dismiss = self.dismiss
            return .run { _ in
                await dismiss()
            }
        case .addFailed:
            state.isAdding = false
            return .none
        default:
            return .none
        }
    }
}
