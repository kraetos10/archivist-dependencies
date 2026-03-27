import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension AddChannelReducer {
    public func handleInternalAction(_ action: Action, state: inout State) -> Effect<Action> {
        switch action {
        case .subscribeSucceeded:
            state.isSubscribing = false
            return .none
        case .subscribeFailed:
            state.isSubscribing = false
            return .none
        default:
            return .none
        }
    }
}
