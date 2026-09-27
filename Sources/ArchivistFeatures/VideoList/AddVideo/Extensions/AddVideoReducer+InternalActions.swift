import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension AddVideoReducer {
    public func handleInternalAction(
        _ action: Action,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .addResult(.success):
            // The parent closes the sheet on success.
            state.isAdding = false
            return .none
        case .addResult(.failure(let error)):
            state.isAdding = false
            state.alert = AlertState {
                TextState(String.localised("generic.error", table: .generic))
            } message: {
                TextState(error.localizedDescription)
            }
            return .none
        default:
            return .none
        }
    }
}
