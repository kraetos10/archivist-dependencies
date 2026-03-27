import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension AddVideoReducer {
    public func handleInternalAction(_ action: Action, state: inout State) -> Effect<Action> {
        switch action {
        case .addSucceeded:
            state.isAdding = false
            return .none
        case .addFailed:
            state.isAdding = false
            return .none
        default:
            return .none
        }
    }
}
