import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension AddPlaylistReducer {
    func handleInternalAction(
        _ action: Action,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .subscribeResult(.success):
            state.isSubscribing = false
            return finish()
        case .createCustomResult(.success):
            state.isSubscribing = false
            state.customName = ""
            return finish()
        case .subscribeResult(.failure):
            state.isSubscribing = false
            state.alert = .failure(String.localised("playlist.subscribeFailed", table: .login))
            return .none
        case .createCustomResult(.failure):
            state.isSubscribing = false
            state.alert = .failure(String.localised("playlist.createFailed", table: .login))
            return .none
        default:
            return .none
        }
    }

    /// Tell the list, then close.
    private func finish() -> Effect<Action> {
        let dismiss = self.dismiss
        return .run { send in
            await send(.delegate(.didAdd))
            await dismiss()
        }
    }
}

extension AlertState where Action == AddPlaylistReducer.AlertAction {
    static func failure(_ message: String) -> Self {
        AlertState {
            TextState(String.localised("generic.error", table: .generic))
        } message: {
            TextState(message)
        }
    }
}
