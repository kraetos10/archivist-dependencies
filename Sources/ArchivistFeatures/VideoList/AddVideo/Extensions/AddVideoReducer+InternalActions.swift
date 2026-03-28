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
            state.isAdding = false
            return .none
        case .addResult(.failure):
            state.isAdding = false
            return .none
        default:
            return .none
        }
    }
}
