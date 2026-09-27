import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension AddChannelReducer {
    func handleInternalAction(
        _ action: Action,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .subscribeResult(.success):
            state.isSubscribing = false
            let dismiss = self.dismiss
            return .run { send in
                await send(.delegate(.didSubscribe))
                await dismiss()
            }
        case .subscribeResult(.failure):
            state.isSubscribing = false
            state.alert = AlertState {
                TextState(String.localised("generic.error", table: .generic))
            } message: {
                TextState(String.localised("channel.subscribeFailed", table: .login))
            }
            return .none
        default:
            return .none
        }
    }
}
