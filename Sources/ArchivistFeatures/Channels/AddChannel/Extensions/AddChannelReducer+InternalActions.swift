import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension AddChannelReducer {
    public func handleInternalAction(
        _ action: Action,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .subscribeResult(.success):
            state.isSubscribing = false
            return .none
        case .subscribeResult(.failure):
            state.isSubscribing = false
            return .none
        default:
            return .none
        }
    }
}
