import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension PlaylistPickerReducer {
    public func handleInternalAction(
        _ action: Action,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .loadResult(.success(let (playlists, alreadyIn))):
            state.playlists = playlists
            state.alreadyInPlaylistIds = alreadyIn
            state.isLoading = false
            return .none
        case .loadResult(.failure):
            state.isLoading = false
            return .none
        case .addResult(.success):
            state.isAdding = false
            let dismiss = self.dismiss
            return .run { _ in
                await dismiss()
            }
        case .addResult(.failure):
            state.isAdding = false
            return .none
        default:
            return .none
        }
    }
}
